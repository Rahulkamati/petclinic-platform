# Outputs for the vpc module (consumed by eks, rds, dns modules).
# Spec: docs/technical-spec.md#module-vpc

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ, same order as availability_zones)."
  value       = aws_subnet.public[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "eks_cluster_sg_id" {
  description = "ID of the EKS cluster (control plane) security group."
  value       = aws_security_group.eks_cluster.id
}

output "eks_node_sg_id" {
  description = "ID of the EKS worker node security group."
  value       = aws_security_group.eks_node.id
}

output "rds_sg_id" {
  description = "ID of the RDS MySQL security group."
  value       = aws_security_group.rds.id
}

output "alb_sg_id" {
  description = "ID of the public ALB security group."
  value       = aws_security_group.alb.id
}
