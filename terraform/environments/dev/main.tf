locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Module calls (vpc, eks, ecr, rds, dns, secrets, observability, karpenter)
# are added by their respective epics (E-2 onwards).
