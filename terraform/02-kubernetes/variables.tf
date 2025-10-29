# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS region"
  type        = string
}

# ==============================================================================
# CLUSTER SELECTION
# ==============================================================================

variable "deploy_clusters" {
  description = "Comma-separated list of clusters to deploy (dev,stg,prd,sdx) or 'all' for all clusters"
  type        = string
  default     = "all"
}

locals {
  # Parse deploy_clusters string into a set
  clusters_to_deploy = var.deploy_clusters == "all" ? toset(["dev", "stg", "prd", "sdx"]) : toset(split(",", var.deploy_clusters))
  
  # Create boolean map for each cluster
  deploy_cluster_map = {
    dev = contains(local.clusters_to_deploy, "dev")
    stg = contains(local.clusters_to_deploy, "stg")
    prd = contains(local.clusters_to_deploy, "prd")
    sdx = contains(local.clusters_to_deploy, "sdx")
  }
}

# ==============================================================================
# EKS CONFIGURATION
# ==============================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for all clusters"
  type        = string
  default     = "1.29"
}

variable "clusters" {
  description = "EKS clusters configuration"
  type = map(object({
    name                       = string
    node_group_name            = string
    node_group_desired_size    = number
    node_group_min_size        = number
    node_group_max_size        = number
    node_group_instance_types  = list(string)
    node_group_capacity_type   = string
    node_group_disk_size       = number
  }))
  default = {
    dev = {
      name                      = "eks-dev"
      node_group_name           = "ng-general-01"
      node_group_desired_size   = 2
      node_group_min_size       = 1
      node_group_max_size       = 4
      node_group_instance_types = ["t3.medium"]
      node_group_capacity_type  = "ON_DEMAND"
      node_group_disk_size      = 50
    }
    stg = {
      name                      = "eks-stg"
      node_group_name           = "ng-general-01"
      node_group_desired_size   = 2
      node_group_min_size       = 1
      node_group_max_size       = 4
      node_group_instance_types = ["t3.medium"]
      node_group_capacity_type  = "ON_DEMAND"
      node_group_disk_size      = 50
    }
    prd = {
      name                      = "eks-prd"
      node_group_name           = "ng-general-01"
      node_group_desired_size   = 3
      node_group_min_size       = 2
      node_group_max_size       = 6
      node_group_instance_types = ["t3.large"]
      node_group_capacity_type  = "ON_DEMAND"
      node_group_disk_size      = 100
    }
    sdx = {
      name                      = "eks-sdx"
      node_group_name           = "ng-general-01"
      node_group_desired_size   = 1
      node_group_min_size       = 1
      node_group_max_size       = 3
      node_group_instance_types = ["t3.small"]
      node_group_capacity_type  = "SPOT"
      node_group_disk_size      = 30
    }
  }
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy  = "Terraform"
    Project    = "aws-landing-zone"
    Team       = "platform"
    Repository = "aws-landing-zone"
  }
}
