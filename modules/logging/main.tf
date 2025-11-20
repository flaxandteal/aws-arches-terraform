# modules/s3-logging-bucket/main.tf

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name}-${var.account_id}"
  force_destroy = false

  tags = merge(var.tags, {
    Name = "${var.name}-${var.account_id}"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
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