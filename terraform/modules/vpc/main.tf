# Module: vpc
# All-public subnet design (ADR-0001): no NAT Gateway, no private subnets,
# no VPC endpoints. Security groups (security_groups.tf) are the perimeter.
# Spec: docs/technical-spec.md#vpc-network-design
#
# Required tags (Project, Environment, ManagedBy) come from provider
# default_tags in the calling environment; var.tags adds extras.

locals {
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = "${var.project}-${var.environment}" # EKS cluster name per spec (E-3)

  tags = merge({ Component = "networking" }, var.tags)
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11:VPC Flow Logs deferred for cost (learning project); revisit in E-13 Security & Compliance.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${local.name_prefix}-vpc" })
}

# Lock down the VPC's default security group: no ingress, no egress.
# Nothing should use it; all resources get an explicit SG.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-default-sg-unused" })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-igw" })
}

# -----------------------------------------------------------------------------
# Public subnets (one per AZ)
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # checkov:skip=CKV_AWS_130:Intentional — all-public subnet design (ADR-0001); SGs enforce access control.
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                                          = "${local.name_prefix}-public-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier                                          = "public"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  })

  lifecycle {
    # Subnet must sit inside the VPC CIDR: its prefix is at least as long as the
    # VPC's, and masking its base address to the VPC prefix yields the VPC base.
    precondition {
      condition = (
        tonumber(split("/", var.public_subnet_cidrs[count.index])[1]) >= tonumber(split("/", var.vpc_cidr)[1]) &&
        cidrhost("${cidrhost(var.public_subnet_cidrs[count.index], 0)}/${split("/", var.vpc_cidr)[1]}", 0) == cidrhost(var.vpc_cidr, 0)
      )
      error_message = "Public subnet ${var.public_subnet_cidrs[count.index]} is not inside VPC CIDR ${var.vpc_cidr}."
    }
  }
}

# -----------------------------------------------------------------------------
# Routing: single public route table, 0.0.0.0/0 -> IGW
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
