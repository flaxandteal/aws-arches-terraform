locals {
  tags = {}
}

# Secret for application
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.name}/app-secrets-${terraform.workspace}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 0 # Immediate deletion for testing
  tags                    = merge(var.common_tags, local.tags)
}

# Secret for RDS credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name       = "${var.name}/rds-credentials-${terraform.workspace}"
  kms_key_id = var.kms_key_arn
  tags       = merge(var.common_tags, local.tags)
}

resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!@#$%&*()-_=+"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db.result
  })
}

# Lambda role for secret rotation
resource "aws_iam_role" "lambda" {
  name = "${var.name}-rds-rotation-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
  tags = merge(var.common_tags, local.tags)
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.name}-rds-rotation-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# Lambda function for rotation
resource "aws_lambda_function" "rotate" {
  filename      = "${path.module}/rotation.zip"
  function_name = "${var.name}-rds-rotation"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  tags          = merge(var.common_tags, local.tags)
}

# Allow Secrets Manager to invoke Lambda
resource "aws_lambda_permission" "allow_secrets_manager_invoke" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotate.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# Secret rotation for RDS
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotate.arn
  rotation_rules {
    automatically_after_days = 30
  }
}

