# ==============================================================================
# EKS CLUSTER SECURITY GROUPS
# ==============================================================================

resource "aws_security_group" "eks_cluster" {
  for_each = var.environments

  name_prefix = "eks-${each.key}-cluster-"
  description = "Security group for EKS cluster ${each.key}"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "eks-${each.key}-cluster-sg"
      Environment = each.key
      Cluster     = "eks-${each.key}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Cluster security group rules
resource "aws_security_group_rule" "eks_cluster_ingress_workstation_https" {
  for_each = aws_security_group.eks_cluster

  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = each.value.id
}

resource "aws_security_group_rule" "eks_cluster_egress_all" {
  for_each = aws_security_group.eks_cluster

  description       = "Allow cluster egress access to the Internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = each.value.id
}

# ==============================================================================
# EKS NODE GROUP SECURITY GROUPS
# ==============================================================================

resource "aws_security_group" "eks_nodes" {
  for_each = var.environments

  name_prefix = "eks-${each.key}-nodes-"
  description = "Security group for all nodes in the EKS cluster ${each.key}"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name                                    = "eks-${each.key}-nodes-sg"
      Environment                             = each.key
      Cluster                                 = "eks-${each.key}"
      "kubernetes.io/cluster/eks-${each.key}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Node to node communication
resource "aws_security_group_rule" "eks_nodes_internal" {
  for_each = aws_security_group.eks_nodes

  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = each.value.id
  security_group_id        = each.value.id
}

# Cluster to node communication
resource "aws_security_group_rule" "eks_nodes_cluster_inbound" {
  for_each = var.environments

  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster[each.key].id
  security_group_id        = aws_security_group.eks_nodes[each.key].id
}

# Node to cluster communication
resource "aws_security_group_rule" "eks_cluster_inbound_node_https" {
  for_each = var.environments

  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes[each.key].id
  security_group_id        = aws_security_group.eks_cluster[each.key].id
}

# Node egress
resource "aws_security_group_rule" "eks_nodes_egress_all" {
  for_each = aws_security_group.eks_nodes

  description       = "Allow nodes all egress"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = each.value.id
}
