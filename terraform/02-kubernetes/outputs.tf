# ==============================================================================
# DEV CLUSTER OUTPUTS
# ==============================================================================

output "eks_dev_cluster_id" {
  description = "EKS Dev cluster ID"
  value       = local.deploy_cluster_map["dev"] ? module.eks_dev[0].cluster_id : null
}

output "eks_dev_cluster_endpoint" {
  description = "EKS Dev cluster endpoint"
  value       = local.deploy_cluster_map["dev"] ? module.eks_dev[0].cluster_endpoint : null
}

output "eks_dev_cluster_name" {
  description = "EKS Dev cluster name"
  value       = local.deploy_cluster_map["dev"] ? module.eks_dev[0].cluster_name : null
}

output "eks_dev_oidc_provider_arn" {
  description = "ARN of OIDC provider for Dev cluster"
  value       = local.deploy_cluster_map["dev"] ? module.eks_dev[0].oidc_provider_arn : null
}

# ==============================================================================
# STG CLUSTER OUTPUTS
# ==============================================================================

output "eks_stg_cluster_id" {
  description = "EKS Stg cluster ID"
  value       = local.deploy_cluster_map["stg"] ? module.eks_stg[0].cluster_id : null
}

output "eks_stg_cluster_endpoint" {
  description = "EKS Stg cluster endpoint"
  value       = local.deploy_cluster_map["stg"] ? module.eks_stg[0].cluster_endpoint : null
}

output "eks_stg_cluster_name" {
  description = "EKS Stg cluster name"
  value       = local.deploy_cluster_map["stg"] ? module.eks_stg[0].cluster_name : null
}

output "eks_stg_oidc_provider_arn" {
  description = "ARN of OIDC provider for Stg cluster"
  value       = local.deploy_cluster_map["stg"] ? module.eks_stg[0].oidc_provider_arn : null
}

# ==============================================================================
# PRD CLUSTER OUTPUTS
# ==============================================================================

output "eks_prd_cluster_id" {
  description = "EKS Prd cluster ID"
  value       = local.deploy_cluster_map["prd"] ? module.eks_prd[0].cluster_id : null
}

output "eks_prd_cluster_endpoint" {
  description = "EKS Prd cluster endpoint"
  value       = local.deploy_cluster_map["prd"] ? module.eks_prd[0].cluster_endpoint : null
}

output "eks_prd_cluster_name" {
  description = "EKS Prd cluster name"
  value       = local.deploy_cluster_map["prd"] ? module.eks_prd[0].cluster_name : null
}

output "eks_prd_oidc_provider_arn" {
  description = "ARN of OIDC provider for Prd cluster"
  value       = local.deploy_cluster_map["prd"] ? module.eks_prd[0].oidc_provider_arn : null
}

# ==============================================================================
# SDX CLUSTER OUTPUTS
# ==============================================================================

output "eks_sdx_cluster_id" {
  description = "EKS Sdx cluster ID"
  value       = local.deploy_cluster_map["sdx"] ? module.eks_sdx[0].cluster_id : null
}

output "eks_sdx_cluster_endpoint" {
  description = "EKS Sdx cluster endpoint"
  value       = local.deploy_cluster_map["sdx"] ? module.eks_sdx[0].cluster_endpoint : null
}

output "eks_sdx_cluster_name" {
  description = "EKS Sdx cluster name"
  value       = local.deploy_cluster_map["sdx"] ? module.eks_sdx[0].cluster_name : null
}

output "eks_sdx_oidc_provider_arn" {
  description = "ARN of OIDC provider for Sdx cluster"
  value       = local.deploy_cluster_map["sdx"] ? module.eks_sdx[0].oidc_provider_arn : null
}
