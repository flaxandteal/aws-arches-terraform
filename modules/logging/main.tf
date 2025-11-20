# modules/s3-logging-bucket/main.tf

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name}-${var.account_id}"
  force_destroy = false

  tags = merge(var.tags, {
    Name = "${var.name}-${var.account_id}"
  })
}

# resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
#   bucket = aws_s3_bucket.this.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_logging.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 3650 # 10 years, or whatever your compliance requires
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# ──────────────────────────────────────────────────────────────────────
# Customer-managed KMS key for S3 access-logging bucket (AVD-AWS-0133)
# ──────────────────────────────────────────────────────────────────────
resource "aws_kms_key" "s3_logging" {
  description             = "Customer-managed key for S3 server-access-logging bucket"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = data.aws_iam_policy_document.s3_logging_key.json

  tags = merge(var.tags, {
    Purpose = "S3AccessLoggingEncryption"
  })
}

resource "aws_kms_alias" "s3_logging" {
  name          = "alias/s3-access-logs-${var.account_id}"
  target_key_id = aws_kms_key.s3_logging.key_id
}

data "aws_iam_policy_document" "s3_logging_key" {
  statement {
    sid    = "EnableRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3LoggingService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Encrypt*"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.*.amazonaws.com"]
    }
  }
}

data "aws_partition" "current" {}

# # ──────────────────────────────────────────────────────────────────────
# # Encryption block – uses CMK instead of AES256
# # ──────────────────────────────────────────────────────────────────────
# resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
#   bucket = aws_s3_bucket.this.id

#   rule {
#     apply_server_side_encryption_by_default {
#       kms_master_key_id = aws_kms_key.s3_logging.arn
#       sse_algorithm     = "aws:kms"
#     }
#     bucket_key_enabled = true
#   }
# }