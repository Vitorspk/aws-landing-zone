# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "sa-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = ""
}
