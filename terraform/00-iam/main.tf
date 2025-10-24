# ==============================================================================
# PROVIDER CONFIGURATION
# ==============================================================================

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "aws-landing-zone"
      Team        = "platform"
      Environment = "shared"
    }
  }
}

# ==============================================================================
# LOCAL VARIABLES
# ==============================================================================

locals {
  environments = toset(["dev", "stg", "prd", "sdx"])
  
  common_tags = {
    Phase      = "iam"
    Repository = "aws-landing-zone"
  }
}
