#######################################
# Terraform backend configuration
#######################################
# Account number for backend: 530258393729
terraform {
  ### Required Terraform version
  required_version = "~> 1.12.2"
  backend "s3" {
    bucket         = "cri-terraform-state-backend"
    dynamodb_table = "cri-terraform-state-backend"
    region         = "us-east-1"
    key            = "cri-ct-rv-dev/alb/terraform.tfstate"
  }
  ### Set provider settings
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.72.0"
    }
  }
}
