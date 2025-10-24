# ==============================================================================
# IAM ROLE OUTPUTS
# ==============================================================================

# EKS Cluster Roles
output "eks_cluster_role_arns" {
  description = "ARNs of EKS cluster IAM roles"
  value = {
    for env, role in aws_iam_role.eks_cluster : env => role.arn
  }
}

output "eks_cluster_role_names" {
  description = "Names of EKS cluster IAM roles"
  value = {
    for env, role in aws_iam_role.eks_cluster : env => role.name
  }
}

# EKS Node Group Roles
output "eks_node_group_role_arns" {
  description = "ARNs of EKS node group IAM roles"
  value = {
    for env, role in aws_iam_role.eks_node_group : env => role.arn
  }
}

output "eks_node_group_role_names" {
  description = "Names of EKS node group IAM roles"
  value = {
    for env, role in aws_iam_role.eks_node_group : env => role.name
  }
}

# AWS Load Balancer Controller Policy
output "aws_load_balancer_controller_policy_arn" {
  description = "ARN of AWS Load Balancer Controller IAM policy"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}

# EBS CSI Driver Policy
output "ebs_csi_driver_policy_arn" {
  description = "ARN of EBS CSI Driver IAM policy"
  value       = aws_iam_policy.ebs_csi_driver.arn
}
