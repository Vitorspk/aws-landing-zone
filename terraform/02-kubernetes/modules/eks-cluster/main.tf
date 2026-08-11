# ==============================================================================
# EKS CLUSTER MODULE
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ==============================================================================
# CLOUDWATCH LOG GROUP (must be created BEFORE EKS cluster)
# ==============================================================================

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-logs"
      Environment = var.environment
      Cluster     = var.cluster_name
    }
  )
}

# ==============================================================================
# EKS CLUSTER
# ==============================================================================

resource "aws_eks_cluster" "main" {
  #checkov:skip=CKV_AWS_39:Public endpoint intentionally enabled - deploy-ingress-nginx.yml runs kubectl from GitHub-hosted runners outside the VPC. See docs/superpowers/specs/2026-08-11-terraform-best-practices-hardening-design.md.
  #checkov:skip=CKV_AWS_38:public_access_cidrs is intentionally 0.0.0.0/0 by default (now configurable via var.public_access_cidrs) for the same CI reason as above.
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [var.cluster_security_group_id]
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  # Only add encryption_config if KMS key is provided
  dynamic "encryption_config" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      provider {
        key_arn = var.kms_key_arn
      }
      resources = ["secrets"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = var.cluster_name
      Environment = var.environment
      Cluster     = var.cluster_name
    }
  )

  depends_on = [
    var.cluster_role_arn,
    aws_cloudwatch_log_group.cluster # Ensure log group exists first
  ]
}

# ==============================================================================
# OIDC PROVIDER FOR IRSA
# ==============================================================================

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-oidc"
      Environment = var.environment
      Cluster     = var.cluster_name
    }
  )
}

# ==============================================================================
# EKS ADDONS
# ==============================================================================

# VPC CNI Addon
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-vpc-cni"
      Environment = var.environment
    }
  )
}

# CoreDNS Addon
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-coredns"
      Environment = var.environment
    }
  )

  depends_on = [aws_eks_node_group.main]
}

# Kube-proxy Addon
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-kube-proxy"
      Environment = var.environment
    }
  )
}

# EBS CSI Driver Addon
resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver[0].arn

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-ebs-csi-driver"
      Environment = var.environment
    }
  )

  depends_on = [aws_eks_node_group.main]
}

# ==============================================================================
# EBS CSI DRIVER IRSA ROLE
# ==============================================================================

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-ebs-csi-driver-role"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  policy_arn = var.ebs_csi_driver_policy_arn
  role       = aws_iam_role.ebs_csi_driver[0].name
}

# ==============================================================================
# EKS NODE GROUP
# ==============================================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.node_group_instance_types
  capacity_type  = var.node_group_capacity_type
  disk_size      = var.node_group_disk_size

  labels = {
    agentpool = "ng-agent-01"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-${var.node_group_name}"
      Environment = var.environment
      Cluster     = var.cluster_name
      NodeGroup   = var.node_group_name
    }
  )

  depends_on = [
    aws_eks_cluster.main,
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}
