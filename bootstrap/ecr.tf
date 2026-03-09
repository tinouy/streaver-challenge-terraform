# ECR (Elastic Container Registry) — stores Docker images for the application.
# Created in bootstrap because an image must be pushed before ECS can start tasks.

resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE" # Allows overwriting tags like "latest"
  force_delete         = true      # Allow deletion even if images exist (for clean teardown)

  # Scan images for known CVEs every time they are pushed.
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt images at rest using AWS-managed keys (no extra cost).
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${var.project_name}-ecr" }
}

# Automatically delete old images to prevent storage cost accumulation.
# Keeps the 10 most recent images regardless of tag status.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
