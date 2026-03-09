# --- Route53 Hosted Zone ---
# Creates a public hosted zone so AWS can serve DNS for our domain.
# After first apply, the output nameservers must be configured as NS records
# in the upstream DNS provider (Cloudflare) to delegate the zone to Route53.

resource "aws_route53_zone" "main" {
  name = var.hosted_zone_name
  tags = { Name = "${var.project_name}-zone" }
}

# --- ACM Certificate ---
# Request a public TLS certificate for the application domain.
# Uses DNS validation (automated via Route53 records below).

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = { Name = "${var.project_name}-cert" }

  # Create the new cert before destroying the old one during replacement,
  # so the ALB listener is never left without a valid certificate.
  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records — ACM provides CNAME records that must exist in Route53
# to prove domain ownership. Terraform creates them automatically.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# Waits until ACM has validated the certificate via the DNS records above.
# This resource blocks until the cert status is "ISSUED".
# NOTE: This will hang if the NS records haven't been configured in Cloudflare yet.
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
