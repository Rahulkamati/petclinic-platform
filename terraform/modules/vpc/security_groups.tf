# Baseline security groups (PETPLAT-8).
# Spec: docs/technical-spec.md#security-groups
#
# In the all-public design these SGs ARE the perimeter. Rules are declared as
# standalone aws_vpc_security_group_{ingress,egress}_rule resources so the
# cross-references (cluster <-> node <-> ALB) don't create dependency cycles.
# Declaring no inline rules also removes AWS's default allow-all egress, so
# each SG only has the egress listed here.

# -----------------------------------------------------------------------------
# Security groups
# -----------------------------------------------------------------------------

resource "aws_security_group" "eks_cluster" {
  # checkov:skip=CKV2_AWS_5:Attached to the EKS cluster in E-3 (vpc_config.security_group_ids).
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "EKS control plane: API server access from worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-cluster-sg" })
}

resource "aws_security_group" "eks_node" {
  # checkov:skip=CKV2_AWS_5:Attached to EKS nodes in E-3 via node group launch template.
  name        = "${local.name_prefix}-eks-node-sg"
  description = "EKS worker nodes: control plane, inter-node and ALB traffic"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-node-sg" })
}

resource "aws_security_group" "rds" {
  # checkov:skip=CKV2_AWS_5:Attached to the RDS instance in E-5.
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS MySQL: port 3306 from EKS nodes only"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-rds-sg" })
}

resource "aws_security_group" "alb" {
  # checkov:skip=CKV2_AWS_5:Attached to the ALB by the AWS Load Balancer Controller (E-6 DNS & Ingress).
  name        = "${local.name_prefix}-alb-sg"
  description = "Public ALB: HTTP/HTTPS from internet, forwards to EKS nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-alb-sg" })
}

# -----------------------------------------------------------------------------
# EKS cluster SG rules
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "eks_cluster_https_from_nodes" {
  security_group_id            = aws_security_group.eks_cluster.id
  description                  = "API server access from worker nodes"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.eks_node.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-cluster-in-443-nodes" })
}

resource "aws_vpc_security_group_egress_rule" "eks_cluster_all_out" {
  security_group_id = aws_security_group.eks_cluster.id
  description       = "Control plane outbound (to nodes and AWS APIs)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-cluster-out-all" })
}

# -----------------------------------------------------------------------------
# EKS node SG rules
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "eks_node_all_from_cluster" {
  security_group_id            = aws_security_group.eks_node.id
  description                  = "All traffic from EKS control plane"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.eks_cluster.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-node-in-all-cluster" })
}

resource "aws_vpc_security_group_ingress_rule" "eks_node_all_from_self" {
  security_group_id            = aws_security_group.eks_node.id
  description                  = "Inter-node communication (pod-to-pod, CoreDNS)"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.eks_node.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-node-in-all-self" })
}

# Subset of eks_node_all_from_cluster; kept explicit to match the spec and to
# survive any future tightening of the all-traffic rule.
resource "aws_vpc_security_group_ingress_rule" "eks_node_kubelet_from_cluster" {
  security_group_id            = aws_security_group.eks_node.id
  description                  = "Kubelet API from EKS control plane"
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  referenced_security_group_id = aws_security_group.eks_cluster.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-node-in-10250-cluster" })
}

resource "aws_vpc_security_group_ingress_rule" "eks_node_nodeport_from_alb" {
  security_group_id            = aws_security_group.eks_node.id
  description                  = "NodePort services from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-node-in-nodeport-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "eks_node_http_from_alb" {
  security_group_id            = aws_security_group.eks_node.id
  description                  = "api-gateway pod port (ALB IP-target mode) and health checks from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-node-in-8080-alb" })
}

resource "aws_vpc_security_group_egress_rule" "eks_node_all_out" {
  security_group_id = aws_security_group.eks_node.id
  description       = "All outbound (ECR, S3, Secrets Manager, RDS via IGW/VPC; no NAT)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.tags, { Name = "${local.name_prefix}-eks-node-out-all" })
}

# -----------------------------------------------------------------------------
# RDS SG rules — 3306 from EKS nodes ONLY. Never 0.0.0.0/0. No egress.
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from EKS worker nodes only"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.eks_node.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-rds-in-3306-nodes" })
}

# -----------------------------------------------------------------------------
# ALB SG rules — the ONLY 0.0.0.0/0 ingress allowed (80/443)
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  # checkov:skip=CKV_AWS_260:Public ALB must accept HTTP on 80 (redirected to HTTPS); allowed by CLAUDE.md security rule 3.
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet (redirect to HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.tags, { Name = "${local.name_prefix}-alb-in-80-internet" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_from_internet" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.tags, { Name = "${local.name_prefix}-alb-in-443-internet" })
}

resource "aws_vpc_security_group_egress_rule" "alb_nodeport_to_nodes" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to NodePort targets on EKS nodes"
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  referenced_security_group_id = aws_security_group.eks_node.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-alb-out-nodeport-nodes" })
}

resource "aws_vpc_security_group_egress_rule" "alb_http_to_nodes" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward/health checks to api-gateway on 8080"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.eks_node.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-alb-out-8080-nodes" })
}
