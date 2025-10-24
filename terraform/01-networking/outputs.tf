# ==============================================================================
# VPC OUTPUTS
# ==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "vpc_name" {
  description = "VPC name"
  value       = var.vpc_name
}

# ==============================================================================
# SUBNET OUTPUTS
# ==============================================================================

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs by environment and AZ"
  value = {
    for key, subnet in aws_subnet.private : key => subnet.id
  }
}

output "private_subnet_ids_by_env" {
  description = "Private subnet IDs grouped by environment"
  value = {
    for env in keys(var.environments) : env => [
      for key, subnet in aws_subnet.private :
      subnet.id if startswith(key, "${env}-")
    ]
  }
}

# ==============================================================================
# NAT GATEWAY OUTPUTS
# ==============================================================================

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT Gateways"
  value = {
    for az, eip in aws_eip.nat : az => eip.public_ip
  }
}

# ==============================================================================
# SECURITY GROUP OUTPUTS
# ==============================================================================

output "eks_cluster_security_group_ids" {
  description = "Security group IDs for EKS clusters"
  value = {
    for env, sg in aws_security_group.eks_cluster : env => sg.id
  }
}

output "eks_nodes_security_group_ids" {
  description = "Security group IDs for EKS node groups"
  value = {
    for env, sg in aws_security_group.eks_nodes : env => sg.id
  }
}

# ==============================================================================
# VPC ENDPOINTS OUTPUTS
# ==============================================================================

output "vpc_endpoint_s3_id" {
  description = "S3 VPC endpoint ID"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.s3[0].id : null
}

output "vpc_endpoint_ecr_api_id" {
  description = "ECR API VPC endpoint ID"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_api[0].id : null
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ECR DKR VPC endpoint ID"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_dkr[0].id : null
}
