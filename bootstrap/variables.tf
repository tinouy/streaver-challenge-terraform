# Input variables for the bootstrap module.
# These control naming, region, and domain configuration.

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

# The full domain name for the application (e.g. challenge.streaver.tinouy.com).
# An ACM certificate will be issued for this domain.
variable "domain_name" {
  description = "Domain name for the application (e.g. app.example.com)"
  type        = string
  default     = "challenge.streaver.tinouy.com"
}

# The parent hosted zone name. Route53 will be authoritative for this zone.
# NS records must be set in the upstream DNS provider (e.g. Cloudflare) after first apply.
variable "hosted_zone_name" {
  description = "Route53 hosted zone name (e.g. example.com)"
  type        = string
  default     = "streaver.tinouy.com"
}
