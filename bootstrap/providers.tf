# Terraform and provider configuration for the bootstrap module.
# This module creates foundational resources (ECR, Route53, ACM) that must
# exist before the main infrastructure can be deployed.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in S3 with DynamoDB locking to prevent concurrent runs.
  # The S3 bucket and DynamoDB table must be created manually before first init.
  backend "s3" {
    bucket         = "streaver-challenge-terraform-bootstrap"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Default tags are applied to every resource created by this module,
# making it easy to identify and filter resources in the AWS console.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
