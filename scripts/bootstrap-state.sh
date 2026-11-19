#!/usr/bin/env bash
# =============================================================================
# bootstrap-state.sh — one-time setup of the Terraform remote state backend
#
# Creates (if missing) and configures:
#   - S3 bucket   petclinic-terraform-state-{account-id}
#       versioning on, SSE-S3 (AES256), all 4 public access blocks, TLS-only policy
#   - DynamoDB    petclinic-terraform-locks  (partition key LockID: String)
#
# Idempotent: every step checks current state or re-applies the same config,
# so it is safe to run repeatedly.
#
# Spec: docs/technical-spec.md#terraform-state-backend   Jira: PETPLAT-2
#
# Usage:
#   scripts/bootstrap-state.sh [--region ap-southeast-2]
# =============================================================================
set -euo pipefail

REGION="ap-southeast-2"
PROJECT="petclinic"
LOCK_TABLE="${PROJECT}-terraform-locks"

usage() {
  echo "Usage: $0 [--region <aws-region>]   (default region: ${REGION})"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) REGION="${2:?--region requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found" >&2; exit 1; }

# Pin every AWS CLI call to the target region, overriding the user's profile
# default. Required because the account's SCP denies all non-home regions.
export AWS_REGION="${REGION}" AWS_DEFAULT_REGION="${REGION}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${PROJECT}-terraform-state-${ACCOUNT_ID}"
TAGS_S3="TagSet=[{Key=Project,Value=${PROJECT}},{Key=Environment,Value=shared},{Key=ManagedBy,Value=bootstrap-script}]"
TAGS_DDB="Key=Project,Value=${PROJECT} Key=Environment,Value=shared Key=ManagedBy,Value=bootstrap-script"

echo "Account: ${ACCOUNT_ID}"
echo "Region:  ${REGION}"
echo "Bucket:  ${BUCKET}"
echo "Table:   ${LOCK_TABLE}"
echo

# --- S3 bucket ----------------------------------------------------------------
if aws s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1; then
  echo "[s3] bucket exists — reapplying configuration"
else
  echo "[s3] creating bucket"
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" >/dev/null
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
  aws s3api wait bucket-exists --bucket "${BUCKET}"
fi

echo "[s3] blocking all public access"
aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "[s3] enabling versioning"
aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "[s3] enabling default encryption (AES256)"
aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

echo "[s3] denying non-TLS requests"
aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"DenyInsecureTransport\",
    \"Effect\": \"Deny\",
    \"Principal\": \"*\",
    \"Action\": \"s3:*\",
    \"Resource\": [\"arn:aws:s3:::${BUCKET}\", \"arn:aws:s3:::${BUCKET}/*\"],
    \"Condition\": {\"Bool\": {\"aws:SecureTransport\": \"false\"}}
  }]
}"

echo "[s3] tagging"
aws s3api put-bucket-tagging --bucket "${BUCKET}" --tagging "${TAGS_S3}"

# --- DynamoDB lock table ------------------------------------------------------
if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "[ddb] table exists — skipping create"
else
  echo "[ddb] creating table (on-demand billing)"
  # shellcheck disable=SC2086
  aws dynamodb create-table --region "${REGION}" \
    --table-name "${LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --sse-specification Enabled=true \
    --tags ${TAGS_DDB} >/dev/null
  echo "[ddb] waiting for table to become ACTIVE"
  aws dynamodb wait table-exists --table-name "${LOCK_TABLE}" --region "${REGION}"
fi

# --- Verify -------------------------------------------------------------------
echo
echo "Verification:"
echo "  versioning:    $(aws s3api get-bucket-versioning --bucket "${BUCKET}" --query Status --output text)"
echo "  encryption:    $(aws s3api get-bucket-encryption --bucket "${BUCKET}" \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text)"
echo "  public access: $(aws s3api get-public-access-block --bucket "${BUCKET}" \
  --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' --output text)"
echo "  lock table:    $(aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" \
  --query '[Table.TableStatus,Table.KeySchema[0].AttributeName]' --output text)"
echo
echo "Done. Next: cd terraform/environments/{dev,prod} && terraform init"
