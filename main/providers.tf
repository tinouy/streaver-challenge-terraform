# Terraform and provider configuration for the main module.
# This module creates the runtime infrastructure (VPC, ALB, ECS, etc.)
# and depends on the bootstrap module having been applied first.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in a separate S3 bucket from bootstrap,
  # so each module's state is isolated and independently manageable.
  backend "s3" {
    bucket         = "streaver-challenge-terraform-main"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# Default tags are applied to every resource created by this module.
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
