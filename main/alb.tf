# Application Load Balancer — receives all incoming traffic from the internet
# and forwards it to ECS tasks in private subnets.

# --- ALB Security Group ---
# Controls what traffic can reach the ALB and where it can send traffic.

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-alb-sg" }

  # Create replacement SG before destroying the old one to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }
}

# Allow HTTP from anywhere — all HTTP traffic gets 301-redirected to HTTPS.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet (redirects to HTTPS)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow HTTPS from anywhere — this is the main entry point for all traffic.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# ALB can only send traffic to ECS tasks on the container port.
# References the ECS security group so only registered targets receive traffic.
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To ECS tasks"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

# --- ALB ---

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false           # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id # Deployed across both public subnets

  drop_invalid_header_fields = true  # Security: reject malformed HTTP headers
  enable_deletion_protection = false # Allow terraform destroy without manual steps

  tags = { Name = "${var.project_name}-alb" }
}

# Target group — ALB health-checks and routes traffic to registered ECS task IPs.
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"          # Traffic between ALB and ECS is HTTP (TLS terminates at ALB)
  vpc_id      = aws_vpc.main.id
  target_type = "ip"            # Required for Fargate (awsvpc network mode)

  # ALB checks /health every 15s to decide if a task is healthy.
  # Tasks that fail 3 consecutive checks are removed from rotation.
  health_check {
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  # Wait 30s for in-flight requests to complete before deregistering a task.
  deregistration_delay = 30

  tags = { Name = "${var.project_name}-tg" }
}

# HTTPS listener — terminates TLS using the ACM certificate from bootstrap.
# All HTTPS traffic is forwarded to the target group.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # TLS 1.2+ only
  certificate_arn   = local.acm_certificate_arn              # From bootstrap via SSM

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP listener — redirects all HTTP traffic to HTTPS with a 301 permanent redirect.
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
