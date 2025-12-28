
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources into."
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

module "terraform_state_bucket" {
  source = "../modules/secure_s3_bucket"

  bucket_name = "admin-terraform-state-${data.aws_caller_identity.current.account_id}"
}




