# Input variables for the main module.
# Most have sensible defaults; bootstrap values are read from SSM automatically.

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "streaver-challenge"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "Production"
}

# Must match the port the application listens on (see Dockerfile CMD).
variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Domain name for the application (e.g. app.example.com)"
  type        = string
  default     = "challenge.streaver.tinouy.com"
}

# Set to a valid email to receive CloudWatch alarm notifications via SNS.
# Leave empty to skip the subscription.
variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

# --- Values from bootstrap (read from SSM Parameter Store) ---
# The bootstrap module writes these values to SSM so the main module
# can read them without requiring manual -var flags during apply.

data "aws_ssm_parameter" "ecr_repository_url" {
  name = "/${var.project_name}/bootstrap/ecr_repository_url"
}

data "aws_ssm_parameter" "route53_zone_id" {
  name = "/${var.project_name}/bootstrap/route53_zone_id"
}

data "aws_ssm_parameter" "acm_certificate_arn" {
  name = "/${var.project_name}/bootstrap/acm_certificate_arn"
}

# Expose SSM values as locals for cleaner references throughout the module.
locals {
  ecr_repository_url  = data.aws_ssm_parameter.ecr_repository_url.value
  acm_certificate_arn = data.aws_ssm_parameter.acm_certificate_arn.value
  route53_zone_id     = data.aws_ssm_parameter.route53_zone_id.value
}
