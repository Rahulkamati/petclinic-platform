locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Network layout — docs/technical-spec.md#cidr-allocation
  # Not secrets; kept here (not tfvars) so they are version-controlled.
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones  = ["ap-southeast-2a", "ap-southeast-2b"]
}

# -----------------------------------------------------------------------------
# E-2 Networking (PETPLAT-9)
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  project             = var.project
  environment         = var.environment
  vpc_cidr            = local.vpc_cidr
  public_subnet_cidrs = local.public_subnet_cidrs
  availability_zones  = local.availability_zones
}

# Remaining module calls (eks, ecr, rds, dns, secrets, observability, karpenter)
# are added by their respective epics (E-3 onwards).
