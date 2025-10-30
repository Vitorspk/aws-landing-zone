# ==============================================================================
# PROVIDER CONFIGURATION
# ==============================================================================

provider "aws" {
  region = var.region
}

# ==============================================================================
# DATA SOURCES - NETWORKING (from Phase 1)
# ==============================================================================

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "vschiavo-home-terraform-state"
    key    = "aws-landing-zone/networking/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "vschiavo-home-terraform-state"
    key    = "aws-landing-zone/iam/terraform.tfstate"
    region = var.region
  }
}

# ==============================================================================
# LOCAL VARIABLES
# ==============================================================================

locals {
  private_subnet_ids_by_env      = data.terraform_remote_state.networking.outputs.private_subnet_ids_by_env
  eks_cluster_security_group_ids = data.terraform_remote_state.networking.outputs.eks_cluster_security_group_ids

  eks_cluster_role_arns     = data.terraform_remote_state.iam.outputs.eks_cluster_role_arns
  eks_node_group_role_arns  = data.terraform_remote_state.iam.outputs.eks_node_group_role_arns
  ebs_csi_driver_policy_arn = data.terraform_remote_state.iam.outputs.ebs_csi_driver_policy_arn
}

# ==============================================================================
# EKS CLUSTERS
# ==============================================================================

# DEV Cluster
module "eks_dev" {
  count  = local.deploy_cluster_map["dev"] ? 1 : 0
  source = "./modules/eks-cluster"

  cluster_name              = var.clusters.dev.name
  cluster_role_arn          = local.eks_cluster_role_arns["dev"]
  kubernetes_version        = var.kubernetes_version
  environment               = "dev"
  subnet_ids                = local.private_subnet_ids_by_env["dev"]
  cluster_security_group_id = local.eks_cluster_security_group_ids["dev"]

  node_group_name           = var.clusters.dev.node_group_name
  node_group_role_arn       = local.eks_node_group_role_arns["dev"]
  node_group_desired_size   = var.clusters.dev.node_group_desired_size
  node_group_min_size       = var.clusters.dev.node_group_min_size
  node_group_max_size       = var.clusters.dev.node_group_max_size
  node_group_instance_types = var.clusters.dev.node_group_instance_types
  node_group_capacity_type  = var.clusters.dev.node_group_capacity_type
  node_group_disk_size      = var.clusters.dev.node_group_disk_size

  enable_ebs_csi_driver     = true
  ebs_csi_driver_policy_arn = local.ebs_csi_driver_policy_arn

  tags = merge(
    var.tags,
    {
      Environment = "dev"
      Tier        = "development"
    }
  )
}

# STG Cluster
module "eks_stg" {
  count  = local.deploy_cluster_map["stg"] ? 1 : 0
  source = "./modules/eks-cluster"

  cluster_name              = var.clusters.stg.name
  cluster_role_arn          = local.eks_cluster_role_arns["stg"]
  kubernetes_version        = var.kubernetes_version
  environment               = "stg"
  subnet_ids                = local.private_subnet_ids_by_env["stg"]
  cluster_security_group_id = local.eks_cluster_security_group_ids["stg"]

  node_group_name           = var.clusters.stg.node_group_name
  node_group_role_arn       = local.eks_node_group_role_arns["stg"]
  node_group_desired_size   = var.clusters.stg.node_group_desired_size
  node_group_min_size       = var.clusters.stg.node_group_min_size
  node_group_max_size       = var.clusters.stg.node_group_max_size
  node_group_instance_types = var.clusters.stg.node_group_instance_types
  node_group_capacity_type  = var.clusters.stg.node_group_capacity_type
  node_group_disk_size      = var.clusters.stg.node_group_disk_size

  enable_ebs_csi_driver     = true
  ebs_csi_driver_policy_arn = local.ebs_csi_driver_policy_arn

  tags = merge(
    var.tags,
    {
      Environment = "stg"
      Tier        = "staging"
    }
  )
}

# PRD Cluster
module "eks_prd" {
  count  = local.deploy_cluster_map["prd"] ? 1 : 0
  source = "./modules/eks-cluster"

  cluster_name              = var.clusters.prd.name
  cluster_role_arn          = local.eks_cluster_role_arns["prd"]
  kubernetes_version        = var.kubernetes_version
  environment               = "prd"
  subnet_ids                = local.private_subnet_ids_by_env["prd"]
  cluster_security_group_id = local.eks_cluster_security_group_ids["prd"]

  node_group_name           = var.clusters.prd.node_group_name
  node_group_role_arn       = local.eks_node_group_role_arns["prd"]
  node_group_desired_size   = var.clusters.prd.node_group_desired_size
  node_group_min_size       = var.clusters.prd.node_group_min_size
  node_group_max_size       = var.clusters.prd.node_group_max_size
  node_group_instance_types = var.clusters.prd.node_group_instance_types
  node_group_capacity_type  = var.clusters.prd.node_group_capacity_type
  node_group_disk_size      = var.clusters.prd.node_group_disk_size

  enable_ebs_csi_driver     = true
  ebs_csi_driver_policy_arn = local.ebs_csi_driver_policy_arn

  tags = merge(
    var.tags,
    {
      Environment = "prd"
      Tier        = "production"
    }
  )
}

# SDX Cluster
module "eks_sdx" {
  count  = local.deploy_cluster_map["sdx"] ? 1 : 0
  source = "./modules/eks-cluster"

  cluster_name              = var.clusters.sdx.name
  cluster_role_arn          = local.eks_cluster_role_arns["sdx"]
  kubernetes_version        = var.kubernetes_version
  environment               = "sdx"
  subnet_ids                = local.private_subnet_ids_by_env["sdx"]
  cluster_security_group_id = local.eks_cluster_security_group_ids["sdx"]

  node_group_name           = var.clusters.sdx.node_group_name
  node_group_role_arn       = local.eks_node_group_role_arns["sdx"]
  node_group_desired_size   = var.clusters.sdx.node_group_desired_size
  node_group_min_size       = var.clusters.sdx.node_group_min_size
  node_group_max_size       = var.clusters.sdx.node_group_max_size
  node_group_instance_types = var.clusters.sdx.node_group_instance_types
  node_group_capacity_type  = var.clusters.sdx.node_group_capacity_type
  node_group_disk_size      = var.clusters.sdx.node_group_disk_size

  enable_ebs_csi_driver     = true
  ebs_csi_driver_policy_arn = local.ebs_csi_driver_policy_arn

  tags = merge(
    var.tags,
    {
      Environment = "sdx"
      Tier        = "sandbox"
    }
  )
}

# ==============================================================================
# DEPLOY NGINX INGRESS CONTROLLERS (NON-BLOCKING)
# ==============================================================================
# Note: NGINX deployment continues in background. The script does not block
# Terraform from completing. You can verify deployment status manually after.

resource "null_resource" "deploy_ingress_dev" {
  count      = local.deploy_cluster_map["dev"] ? 1 : 0
  depends_on = [module.eks_dev]

  triggers = {
    cluster_id = module.eks_dev[0].cluster_id
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.root}/../../scripts/deploy-ingress-controllers.sh ${var.clusters.dev.name} ${var.region} || echo 'NGINX deployment initiated. Check status with: kubectl get pods -n ingress-nginx'"
  }
}

resource "null_resource" "deploy_ingress_stg" {
  count      = local.deploy_cluster_map["stg"] ? 1 : 0
  depends_on = [module.eks_stg]

  triggers = {
    cluster_id = module.eks_stg[0].cluster_id
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.root}/../../scripts/deploy-ingress-controllers.sh ${var.clusters.stg.name} ${var.region} || echo 'NGINX deployment initiated. Check status with: kubectl get pods -n ingress-nginx'"
  }
}

resource "null_resource" "deploy_ingress_prd" {
  count      = local.deploy_cluster_map["prd"] ? 1 : 0
  depends_on = [module.eks_prd]

  triggers = {
    cluster_id = module.eks_prd[0].cluster_id
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.root}/../../scripts/deploy-ingress-controllers.sh ${var.clusters.prd.name} ${var.region} || echo 'NGINX deployment initiated. Check status with: kubectl get pods -n ingress-nginx'"
  }
}

resource "null_resource" "deploy_ingress_sdx" {
  count      = local.deploy_cluster_map["sdx"] ? 1 : 0
  depends_on = [module.eks_sdx]

  triggers = {
    cluster_id = module.eks_sdx[0].cluster_id
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.root}/../../scripts/deploy-ingress-controllers.sh ${var.clusters.sdx.name} ${var.region} || echo 'NGINX deployment initiated. Check status with: kubectl get pods -n ingress-nginx'"
  }
}
