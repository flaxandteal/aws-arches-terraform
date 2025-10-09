resource "aws_kms_key" "data" {
  description         = "KMS key for ${var.name}-data-${terraform.workspace}"
  enable_key_rotation = true
  tags                = merge(var.tags, var.extra_tags, { Name = "${var.name}-data-kms-${terraform.workspace}" })
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name}-data-kms-${terraform.workspace}"
  target_key_id = aws_kms_key.data.id
}

resource "aws_s3_bucket" "data" {
  bucket = "${var.name}-data-${terraform.workspace}"
  tags   = merge(var.tags, var.extra_tags, { Name = "${var.name}-data-${terraform.workspace}" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "data" {
  bucket = aws_s3_bucket.data.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "data-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "archive"
    status = terraform.workspace == "prod" ? "Enabled" : "Disabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.lifecycle_transition_days
      storage_class = var.lifecycle_storage_class
    }
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.name}-logs-${terraform.workspace}"
  tags   = merge(var.tags, var.extra_tags, { Name = "${var.name}-logs-${terraform.workspace}" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.name}-tfstate-${terraform.workspace}"
  tags   = merge(var.tags, var.extra_tags, { Name = "${var.name}-tfstate-${terraform.workspace}" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${var.name}-tfstate-lock-${terraform.workspace}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.tags, var.extra_tags, { Name = "${var.name}-tfstate-lock-${terraform.workspace}" })
}
