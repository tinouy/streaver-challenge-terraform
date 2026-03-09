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

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of ECS tasks for autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 6
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

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = "cmartinpf@gmail.com"
}

# --- Values from bootstrap (read from SSM Parameter Store) ---

data "aws_ssm_parameter" "ecr_repository_url" {
  name = "/${var.project_name}/bootstrap/ecr_repository_url"
}

data "aws_ssm_parameter" "route53_zone_id" {
  name = "/${var.project_name}/bootstrap/route53_zone_id"
}

data "aws_ssm_parameter" "acm_certificate_arn" {
  name = "/${var.project_name}/bootstrap/acm_certificate_arn"
}

locals {
  ecr_repository_url  = data.aws_ssm_parameter.ecr_repository_url.value
  acm_certificate_arn = data.aws_ssm_parameter.acm_certificate_arn.value
  route53_zone_id     = data.aws_ssm_parameter.route53_zone_id.value
}
