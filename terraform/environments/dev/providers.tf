provider "aws" {
  region = var.aws_region

  # Required tags (Project, Environment, ManagedBy) are applied to every
  # resource created through this provider. Modules merge extra tags via var.tags.
  default_tags {
    tags = local.common_tags
  }
}
