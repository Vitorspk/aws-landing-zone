# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "shared-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "192.168.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones (will be constructed from region)"
  type        = list(string)
  default     = []
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
      cidr_block = "192.168.0.0/20"
    }
    stg = {
      cidr_block = "192.168.16.0/20"
    }
    prd = {
      cidr_block = "192.168.32.0/20"
    }
    sdx = {
      cidr_block = "192.168.48.0/20"
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

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Auto-detect availability zones from region if not provided
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : [
    "${var.region}a",
    "${var.region}b"
  ]
}
