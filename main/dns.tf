# DNS A record — points the application domain to the ALB.
# Uses an alias record (AWS-native) instead of a CNAME, which allows
# the record to be at the zone apex and doesn't incur Route53 query charges.
# The zone_id comes from bootstrap via SSM Parameter Store.

resource "aws_route53_record" "app" {
  zone_id = local.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true # Route53 will health-check the ALB
  }
}
