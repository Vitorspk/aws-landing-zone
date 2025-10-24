# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "shared-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/8"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b"]
}

# ==============================================================================
# ENVIRONMENTS CONFIGURATION
# ==============================================================================

variable "environments" {
  description = "Environment configurations"
  type = map(object({
    cidr_block = string
  }))
  default = {
    dev = {
      cidr_block = "10.10.0.0/16"
    }
    stg = {
      cidr_block = "10.13.0.0/16"
    }
    prd = {
      cidr_block = "10.16.0.0/16"
    }
    sdx = {
      cidr_block = "10.19.0.0/16"
    }
  }
}

# ==============================================================================
# VPC FLOW LOGS
# ==============================================================================

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log group retention in days for VPC Flow Logs"
  type        = number
  default     = 7
}

# ==============================================================================
# VPC ENDPOINTS
# ==============================================================================

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints"
  type        = bool
  default     = true
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy  = "Terraform"
    Project    = "aws-landing-zone"
    Team       = "platform"
    Repository = "aws-landing-zone"
  }
}
