# ECS (Elastic Container Service) — runs the containerized application on Fargate.
# Tasks run in private subnets and are only reachable via the ALB.

# --- ECS Security Group ---
# Only allows inbound traffic from the ALB on the container port.

resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-"
  description = "ECS tasks security group"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-ecs-sg" }

  lifecycle {
    create_before_destroy = true
  }
  provider = aws
}

# Inbound: only accept traffic from the ALB security group.
# No other source can reach the ECS tasks directly.
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "From ALB only"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# Outbound: allow all traffic so tasks can pull images from ECR
# and reach any external services they may need.
resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  description       = "Outbound to internet (for ECR image pull)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- ECS Cluster ---
# Logical grouping for ECS services. Container Insights provides
# detailed CPU, memory, network, and storage metrics per task.

resource "aws_ecs_cluster" "main" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# --- CloudWatch Log Group ---
# Application logs from the container are streamed here via the awslogs driver.
# 14-day retention balances cost with debugging needs.

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
}

# --- Task Definition ---
# Defines what container to run, resource limits, and logging configuration.

resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Required for Fargate — each task gets its own ENI
  cpu                      = 256      # 0.25 vCPU
  memory                   = 512      # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution.arn # For pulling images and writing logs
  task_role_arn            = aws_iam_role.ecs_task.arn       # For app runtime AWS API calls (none currently)

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${local.ecr_repository_url}:latest" # ECR URL from bootstrap via SSM
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    # Pass the port as an environment variable so the app can read it.
    environment = [
      { name = "PORT", value = tostring(var.container_port) },
    ]

    # Stream container stdout/stderr to CloudWatch Logs.
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "app"
      }
    }

    # Container-level health check (in addition to ALB health checks).
    # Uses Python's urllib since the image is based on python:3.12-slim.
    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:${var.container_port}/health')\" || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])
}

# --- ECS Service ---
# Maintains the desired number of running tasks and integrates with the ALB.

resource "aws_ecs_service" "app" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  # Tasks run in private subnets with no public IPs.
  # Outbound traffic goes through NAT Gateways.
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  # Register tasks with the ALB target group.
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  # Rolling deployment: start new tasks before stopping old ones (zero downtime).
  deployment_minimum_healthy_percent = 100 # Never go below current task count
  deployment_maximum_percent         = 200 # Allow double the tasks during deploy
  health_check_grace_period_seconds  = 30  # Wait before checking new task health

  # Automatically roll back if new tasks fail to stabilize.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Ignore task_definition changes in Terraform so CI/CD can update the image tag
  # without causing drift. Infrastructure changes go through Terraform, but
  # application deploys (new image tags) happen via ECS service update.
  lifecycle {
    ignore_changes = [task_definition]
  }

  # Ensure the HTTPS listener exists before creating the service,
  # otherwise tasks would register to a target group with no listener.
  depends_on = [aws_lb_listener.https]
}
