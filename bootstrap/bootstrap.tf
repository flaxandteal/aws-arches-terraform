provider "aws" {
  region = "ap-southeast-6" # AWS Asia Pacific (New Zealand)
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "catalina-terraform-state-510664426317"
  tags = {
    Name = "terraform-state"
  }
}

# Retrieve the AWS account ID
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_block" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Pentest finding: no protection from bucket deletion. The state bucket has no
# teardown toggle on purpose; remove this policy by hand if it must go.
resource "aws_s3_bucket_policy" "terraform_state_deletion_protection" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PreventAccidentalDeletionOfBucket"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:DeleteBucket"
      Resource  = aws_s3_bucket.terraform_state.arn
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.terraform_state_block]
}

resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}