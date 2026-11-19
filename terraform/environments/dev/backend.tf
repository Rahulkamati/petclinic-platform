# Remote state — bucket and lock table are created by scripts/bootstrap-state.sh.
# Backend blocks cannot use variables, so values are literal.
#
# Note: Terraform >= 1.10 marks dynamodb_table as deprecated in favour of
# use_lockfile. DynamoDB locking is kept here because docs/technical-spec.md
# (Terraform State Backend) requires it.
terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-297586729588"
    key            = "petclinic/dev/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
