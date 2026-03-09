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

variable "domain_name" {
  description = "Domain name for the application (e.g. app.example.com)"
  type        = string
  default     = "challenge.streaver.tinouy.com"
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name (e.g. example.com)"
  type        = string
  default     = "streaver.tinouy.com"
}
