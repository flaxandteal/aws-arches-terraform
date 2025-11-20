# modules/s3/main.tf

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.name}-data-${random_id.suffix.hex}"
}

# --------------------------------------------------------------------------
# S3 Bucket
# --------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  force_destroy = var.force_destroy # false in prod, true in dev/stage/uat
  
  tags = merge(var.tags, {
    Name        = local.bucket_name
    Environment = var.environment
  })
}

# --------------------------------------------------------------------------
# Versioning
# --------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  #   depends_on = [aws_s3_bucket.this]  

  versioning_configuration {
    status = "Enabled"
  }
}

# --------------------------------------------------------------------------
# Server-Side Encryption
# --------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  #depends_on = [aws_s3_bucket.this]

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.s3_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# --------------------------------------------------------------------------
# Lifecycle Configuration
# --------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "transition-to-${lower(var.lifecycle_storage_class)}"
    status = "Enabled"

    filter {
      prefix = "" # applies to all
    }

    transition {
      days          = var.lifecycle_transition_days
      storage_class = var.lifecycle_storage_class
    }

    # cleanups
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
# --------------------------------------------------------------------------
# Block Public Access
# --------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id
  #depends_on = [aws_s3_bucket.this]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------------------------------
# Logging
# --------------------------------------------------------------------------
resource "aws_s3_bucket_logging" "this" {
  count = var.enable_logging ? 1 : 0

  bucket = aws_s3_bucket.this.id
  #depends_on    = [aws_s3_bucket.this]
  target_bucket = var.logging_bucket
  target_prefix = "logs/s3/${local.bucket_name}/"
}