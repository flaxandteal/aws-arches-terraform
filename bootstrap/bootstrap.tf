# =================
# Variables
# =================
variable "region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "replica_region" {
  description = "Replica region for S3"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

# =================
# Providers
# =================
provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "replica"
  region = var.replica_region
}

data "aws_caller_identity" "current" {}

# =================
# Locals
# =================
locals {
  account_id = data.aws_caller_identity.current.account_id

  # control protect_from_destroy depending on environment
  protect_from_destroy = contains(["prod", "uat"], var.environment)
  enable_replication   = contains(["prod", "uat"], var.environment)

  bucket_name         = "tfstate-${var.environment}-${local.account_id}"
  bucket_name_replica = "tfstate-${var.environment}-${local.account_id}-replica"
  log_bucket          = "tfstate-${var.environment}-${local.account_id}-logs"
  lock_table_name     = "tflocks-${var.environment}-${local.account_id}"
}

# ========================
# KMS Key – Primary
# ========================
data "aws_iam_policy_document" "kms_tfstate" {
  statement {
    sid    = "EnableRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = local.enable_replication ? [1] : []
    content {
      sid    = "AllowReplication"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = [aws_iam_role.replication[0].arn]
      }
      actions   = ["kms:GenerateDataKey", "kms:Encrypt"]
      resources = ["*"]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["s3.${var.replica_region}.amazonaws.com"]
      }
    }
  }
}

resource "aws_kms_key" "tfstate" {
  description             = "KMS key for Terraform state"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_tfstate.json

  tags = {
    Name        = "tfstate-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

# ========================
# KMS Key – Replica
# ========================
resource "aws_kms_key" "tfstate_replica" {
  count    = local.enable_replication ? 1 : 0
  provider = aws.replica

  description             = "KMS key for replicated state"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRoot"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowReplication"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.replication[0].arn }
        Action    = ["kms:GenerateDataKey", "kms:Encrypt"]
        Resource  = "*"
      }
    ]
  })

  tags = {
    Name        = "tfstate-kms-replica"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "tfstate_replica" {
  count         = local.enable_replication ? 1 : 0
  provider      = aws.replica
  name          = "alias/tfstate-replica"
  target_key_id = aws_kms_key.tfstate_replica[0].key_id
}

# ========================
# S3 Bucket – State
# ========================
resource "aws_s3_bucket" "state_protected" {
  count  = local.protect_from_destroy ? 1 : 0
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Purpose     = "terraform-state"
  }
}

resource "aws_s3_bucket" "state_destroyable" {
  count  = local.protect_from_destroy ? 0 : 1
  bucket = local.bucket_name

  tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Purpose     = "terraform-state"
  }
}

# ========================
# S3 Bucket – Logging
# ========================
resource "aws_s3_bucket" "logs_protected" {
  count  = local.protect_from_destroy ? 1 : 0
  bucket = local.log_bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = local.log_bucket
    Environment = var.environment
    Purpose     = "terraform-state-logs"
  }
}

resource "aws_s3_bucket" "logs_destroyable" {
  count  = local.protect_from_destroy ? 0 : 1
  bucket = local.log_bucket

  tags = {
    Name        = local.log_bucket
    Environment = var.environment
    Purpose     = "terraform-state-logs"
  }
}

# ========================
# S3 Bucket – Replica
# ========================
resource "aws_s3_bucket" "replica_protected" {
  count    = local.enable_replication && local.protect_from_destroy ? 1 : 0
  provider = aws.replica
  bucket   = local.bucket_name_replica

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = local.bucket_name_replica
    Environment = var.environment
    Purpose     = "terraform-state-replica"
  }
}

resource "aws_s3_bucket" "replica_destroyable" {
  count    = local.enable_replication && !local.protect_from_destroy ? 1 : 0
  provider = aws.replica
  bucket   = local.bucket_name_replica

  tags = {
    Name        = local.bucket_name_replica
    Environment = var.environment
    Purpose     = "terraform-state-replica"
  }
}

# ========================
# S3 Configuration (uses locals defined later)
# ========================
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = local.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = local.state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tfstate.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state_block" {
  bucket                  = local.state_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "state_logging" {
  bucket        = local.state_bucket.id
  target_bucket = local.logs_bucket.id
  target_prefix = "access-logs/"
}

# ========================
# S3 Bucket Policy
# ========================
data "aws_iam_policy_document" "s3_tfstate" {
  statement {
    sid       = "DenyUnencrypted"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${local.state_bucket.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid       = "DenyInsecure"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [local.state_bucket.arn, "${local.state_bucket.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state_policy" {
  bucket = local.state_bucket.id
  policy = data.aws_iam_policy_document.s3_tfstate.json
}

resource "aws_s3_bucket_lifecycle_configuration" "state_lifecycle" {
  bucket = local.state_bucket.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ========================
# Replication (optional)
# ========================
resource "aws_s3_bucket_versioning" "replica_versioning" {
  count    = local.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = local.replica_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "replication" {
  count = local.enable_replication ? 1 : 0
  name  = "s3-replication-role-${local.account_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  count = local.enable_replication ? 1 : 0
  name  = "replication-policy"
  role  = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = ["${local.state_bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = ["${local.replica_bucket.arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "state_replication" {
  count  = local.enable_replication ? 1 : 0
  role   = aws_iam_role.replication[0].arn
  bucket = local.state_bucket.id

  rule {
    id       = "StateReplication"
    status   = "Enabled"
    priority = 0

    destination {
      bucket        = local.replica_bucket.arn
      storage_class = "STANDARD"
      account       = local.account_id
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.tfstate_replica[0].arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    filter {}
  }

  depends_on = [aws_s3_bucket_versioning.state_versioning]
}

# ========================
# DynamoDB – Lock Table
# ========================
resource "aws_dynamodb_table" "locks_protected" {
  count        = local.protect_from_destroy ? 1 : 0
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = local.lock_table_name
    Environment = var.environment
    Purpose     = "terraform-locks"
  }
}

resource "aws_dynamodb_table" "locks_destroyable" {
  count        = local.protect_from_destroy ? 0 : 1
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = local.lock_table_name
    Environment = var.environment
    Purpose     = "terraform-locks"
  }
}

# ========================
# Unified locals 
# ========================
locals {
  state_bucket = local.protect_from_destroy ? aws_s3_bucket.state_protected[0] : aws_s3_bucket.state_destroyable[0]
  logs_bucket  = local.protect_from_destroy ? aws_s3_bucket.logs_protected[0] : aws_s3_bucket.logs_destroyable[0]
  replica_bucket = local.enable_replication ? (
    local.protect_from_destroy ? aws_s3_bucket.replica_protected[0] : aws_s3_bucket.replica_destroyable[0]
  ) : null
  lock_table = local.protect_from_destroy ? aws_dynamodb_table.locks_protected[0] : aws_dynamodb_table.locks_destroyable[0]
}

# ========================
# Outputs
# ========================
output "state_bucket_name" {
  value       = local.state_bucket.bucket
  description = "Terraform state bucket name"
}

output "state_bucket_arn" {
  value       = local.state_bucket.arn
  description = "Terraform state bucket ARN"
}

output "replica_bucket_name" {
  value       = local.enable_replication ? local.replica_bucket.bucket : null
  description = "Replica bucket name"
}

output "lock_table_name" {
  value       = local.lock_table.name
  description = "DynamoDB lock table name"
}

output "kms_key_id" {
  value     = aws_kms_key.tfstate.key_id
  sensitive = true
}

output "kms_key_arn" {
  value     = aws_kms_key.tfstate.arn
  sensitive = true
}

output "backend_config" {
  value       = <<EOT
terraform {
  backend "s3" {
    bucket         = "${local.state_bucket.bucket}"
    key            = "global/terraform.tfstate"
    region         = "${var.region}"
    encrypt        = true
    kms_key_id     = "${aws_kms_key.tfstate.arn}"
    dynamodb_table = "${local.lock_table.name}"
  }
}
EOT
  description = "Copy into your root modules"
}