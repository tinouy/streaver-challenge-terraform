# --- Route53 Hosted Zone ---
# Cloudflare delegates streaver.tinouy.com to these NS records.
# After first apply, set the NS records in Cloudflare from the output.

resource "aws_route53_zone" "main" {
  name = var.hosted_zone_name
  tags = { Name = "${var.project_name}-zone" }
}

# --- ACM Certificate ---

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = { Name = "${var.project_name}-cert" }

  lifecycle {
    create_before_destroy = true
  }
}

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

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
