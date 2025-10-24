# ==============================================================================
# DEV CLUSTER OUTPUTS
# ==============================================================================

output "eks_dev_cluster_id" {
  description = "EKS Dev cluster ID"
  value       = module.eks_dev.cluster_id
}

output "eks_dev_cluster_endpoint" {
  description = "EKS Dev cluster endpoint"
  value       = module.eks_dev.cluster_endpoint
}

output "eks_dev_cluster_name" {
  description = "EKS Dev cluster name"
  value       = module.eks_dev.cluster_name
}

output "eks_dev_oidc_provider_arn" {
  description = "ARN of OIDC provider for Dev cluster"
  value       = module.eks_dev.oidc_provider_arn
}

# ==============================================================================
# STG CLUSTER OUTPUTS
# ==============================================================================

output "eks_stg_cluster_id" {
  description = "EKS Stg cluster ID"
  value       = module.eks_stg.cluster_id
}

output "eks_stg_cluster_endpoint" {
  description = "EKS Stg cluster endpoint"
  value       = module.eks_stg.cluster_endpoint
}

output "eks_stg_cluster_name" {
  description = "EKS Stg cluster name"
  value       = module.eks_stg.cluster_name
}

output "eks_stg_oidc_provider_arn" {
  description = "ARN of OIDC provider for Stg cluster"
  value       = module.eks_stg.oidc_provider_arn
}

# ==============================================================================
# PRD CLUSTER OUTPUTS
# ==============================================================================

output "eks_prd_cluster_id" {
  description = "EKS Prd cluster ID"
  value       = module.eks_prd.cluster_id
}

output "eks_prd_cluster_endpoint" {
  description = "EKS Prd cluster endpoint"
  value       = module.eks_prd.cluster_endpoint
}

output "eks_prd_cluster_name" {
  description = "EKS Prd cluster name"
  value       = module.eks_prd.cluster_name
}

output "eks_prd_oidc_provider_arn" {
  description = "ARN of OIDC provider for Prd cluster"
  value       = module.eks_prd.oidc_provider_arn
}

# ==============================================================================
# SDX CLUSTER OUTPUTS
# ==============================================================================

output "eks_sdx_cluster_id" {
  description = "EKS Sdx cluster ID"
  value       = module.eks_sdx.cluster_id
}

output "eks_sdx_cluster_endpoint" {
  description = "EKS Sdx cluster endpoint"
  value       = module.eks_sdx.cluster_endpoint
}

output "eks_sdx_cluster_name" {
  description = "EKS Sdx cluster name"
  value       = module.eks_sdx.cluster_name
}

output "eks_sdx_oidc_provider_arn" {
  description = "ARN of OIDC provider for Sdx cluster"
  value       = module.eks_sdx.oidc_provider_arn
}
