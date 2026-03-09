# IAM roles for ECS tasks — follows the principle of least privilege.
# Two separate roles:
#   - Execution role: used by ECS agent to pull images and write logs
#   - Task role: used by the running application for AWS API calls

# --- ECR repository lookup ---
# Extract the repo name from the URL so we can look up its ARN
# for the execution role policy (scoped to this specific repo only).

locals {
  # URL format: <account_id>.dkr.ecr.<region>.amazonaws.com/<repo_name>
  ecr_repo_name = split("/", local.ecr_repository_url)[1]
}

data "aws_ecr_repository" "app" {
  name = local.ecr_repo_name
}

# --- ECS Task Execution Role ---
# Used by the ECS agent (not the app) to pull container images from ECR
# and push logs to CloudWatch. This role is NOT available to application code.

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_execution" {
  name = "ecs-execution"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Pull images — scoped to this specific ECR repository only.
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = data.aws_ecr_repository.app.arn
      },
      {
        # Auth token — required to authenticate with ECR. Must be "*" per AWS docs.
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # Write logs — scoped to this specific log group only.
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      },
    ]
  })
}

# --- ECS Task Role ---
# Available to the running application for AWS API calls.
# Currently has no policies attached because the app makes no AWS SDK calls.
# Add policies here if the app needs access to S3, DynamoDB, SQS, etc.

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
