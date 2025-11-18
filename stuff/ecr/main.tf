locals {
  tags = {}
}

# --------------------------------------------------------------------------
# ECR Repository
# --------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "${var.name}/app"
  image_tag_mutability = "MUTABLE"
  # encryption_configuration {
  #   encryption_type = "KMS"
  #   kms_key         = var.kms_key_arn
  # }
  image_scanning_configuration { #sji check
    scan_on_push = true
  }
  tags = merge(var.common_tags, local.tags)
}

# --------------------------------------------------------------------------
# Lifecycle Policy
# --------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}