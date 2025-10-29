# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = ""
}
