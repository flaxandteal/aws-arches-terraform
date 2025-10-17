locals {
  tags = {}
}

resource "aws_secretsmanager_secret" "app_secrets" {
  name       = "${var.name}/app-secrets"
  kms_key_id = var.kms_key_arn
  tags       = merge(var.common_tags, local.tags)
}

resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id = var.rds_secret
  rotation_lambda_arn = aws_lambda_function.rotate.arn
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_lambda_function" "rotate" {
  function_name = "${var.name}-rds-rotation"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda.arn
  filename      = "${path.module}/rotation.zip"  # Placeholder; create rotation Lambda code
  timeout       = 30
  tags          = merge(var.common_tags, local.tags)
}

resource "aws_iam_role" "lambda" {
  name = "${var.name}-rds-rotation-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
  tags = merge(var.common_tags, local.tags)
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.name}-rds-rotation-policy"
  role   = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:RotateSecret", "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue"]
        Resource = var.rds_secret
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["rds:ModifyDBInstance"]
        Resource = "*"
      }
    ]
  })
}