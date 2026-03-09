# Outputs for human consumption (visible after terraform apply).

output "ecr_repository_url" {
  description = "ECR repository URL for pushing images"
  value       = aws_ecr_repository.app.repository_url
}

output "route53_nameservers" {
  description = "Set these NS records in Cloudflare for streaver.tinouy.com"
  value       = aws_route53_zone.main.name_servers
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "acm_certificate_arn" {
  description = "Validated ACM certificate ARN"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

# --- SSM Parameters ---
# Store bootstrap outputs in SSM Parameter Store so the main module can
# read them automatically without requiring manual -var flags.
# Path convention: /<project_name>/bootstrap/<output_name>

resource "aws_ssm_parameter" "ecr_repository_url" {
  name  = "/${var.project_name}/bootstrap/ecr_repository_url"
  type  = "String"
  value = aws_ecr_repository.app.repository_url
}

resource "aws_ssm_parameter" "route53_zone_id" {
  name  = "/${var.project_name}/bootstrap/route53_zone_id"
  type  = "String"
  value = aws_route53_zone.main.zone_id
}

resource "aws_ssm_parameter" "acm_certificate_arn" {
  name  = "/${var.project_name}/bootstrap/acm_certificate_arn"
  type  = "String"
  value = aws_acm_certificate_validation.main.certificate_arn
}
