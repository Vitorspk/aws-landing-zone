terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "vschiavo-home-terraform-state"
    key            = "aws-landing-zone/iam/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    # Region will be set via:
    # - AWS_DEFAULT_REGION environment variable
    # - terraform init -backend-config="region=$AWS_DEFAULT_REGION"
    # - AWS CLI default region
  }
}
