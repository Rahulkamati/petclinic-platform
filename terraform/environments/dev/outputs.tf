output "environment" {
  description = "Environment name."
  value       = var.environment
}

output "aws_region" {
  description = "AWS region this environment is deployed to."
  value       = var.aws_region
}

output "name_prefix" {
  description = "Resource name prefix (petclinic-{env})."
  value       = local.name_prefix
}

output "common_tags" {
  description = "Tags applied to every resource via provider default_tags."
  value       = local.common_tags
}

# -----------------------------------------------------------------------------
# Networking (E-2)
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_sg_id" {
  description = "EKS cluster security group ID."
  value       = module.vpc.eks_cluster_sg_id
}

output "eks_node_sg_id" {
  description = "EKS node security group ID."
  value       = module.vpc.eks_node_sg_id
}

output "rds_sg_id" {
  description = "RDS security group ID."
  value       = module.vpc.rds_sg_id
}

output "alb_sg_id" {
  description = "ALB security group ID."
  value       = module.vpc.alb_sg_id
}
