# modules/logging/outputs.tf

output "bucket_id" {
  description = "Name of the logging bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the logging bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Full bucket name (same as id)"
  value       = aws_s3_bucket.this.bucket
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used for the logging bucket"
  value       = aws_kms_key.s3_logging.arn
}