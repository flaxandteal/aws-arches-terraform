locals {
  tags = {}
}

resource "aws_s3_bucket" "blobs" {
  bucket = "${var.name}-app-blobs-${var.account_id}"
  tags   = merge(var.common_tags, local.tags)
}

resource "aws_s3_bucket_versioning" "blobs" {
  bucket = aws_s3_bucket.blobs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "blobs" {
  bucket = aws_s3_bucket.blobs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "blobs" {
  bucket = aws_s3_bucket.blobs.id
  rule {
    id     = "transition-to-${var.lifecycle_storage_class}"
    status = "Enabled"
    transition {
      days          = var.lifecycle_transition_days
      storage_class = var.lifecycle_storage_class
    }
  }
}