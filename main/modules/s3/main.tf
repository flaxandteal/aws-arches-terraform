# modules/s3/main.tf

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# --------------------------------------------------------------------------
# S3 Bucket
# --------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  bucket = "${var.name}-data-${random_id.bucket_suffix.hex}"

  tags = merge(var.common_tags, {
    Name = "${var.name}-data-${random_id.bucket_suffix.hex}"
  })
}

# --------------------------------------------------------------------------
# Versioning
# --------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --------------------------------------------------------------------------
# Server-Side Encryption
# --------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.s3_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# --------------------------------------------------------------------------
# Lifecycle 
# --------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.enable_lifecycle ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = var.lifecycle_transition_days
      storage_class = var.lifecycle_storage_class
    }
  }
}

# --------------------------------------------------------------------------
# Block Public Access
# --------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

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

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_bucket
  target_prefix = "s3/${var.name}-data/"
}

# --------------------------------------------------------------------------
# Deletion protection (pentest finding: no protection from bucket deletion)
# --------------------------------------------------------------------------
# Explicit deny on s3:DeleteBucket for every principal, including admins, so a
# compromised or careless credential cannot delete the bucket in one call.
# Deleting objects is unaffected. To destroy an environment on purpose, set
# deletion_protection = false, apply (removes this policy), then destroy.
resource "aws_s3_bucket_policy" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PreventAccidentalDeletionOfBucket"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:DeleteBucket"
      Resource  = aws_s3_bucket.this.arn
    }]
  })

  # The public access block must exist first, or the policy put can race it.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
