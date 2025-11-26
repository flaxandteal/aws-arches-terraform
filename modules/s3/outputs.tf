# modules/s3/outputs.tf

output "bucket_name" { value = aws_s3_bucket.this.bucket }
output "bucket_arn" { value = aws_s3_bucket.this.arn }
output "bucket_regional_domain_name" {
  value = aws_s3_bucket.this.bucket_regional_domain_name
}
output "bucket_region" {
  description = "The AWS region of the bucket"
  value       = aws_s3_bucket.this.region
}

output "bucket_domain_name" {
  value = aws_s3_bucket.this.bucket_domain_name
}
output "bucket_id" {
  description = "Same as bucket_name (kept for backward compatibility)"
  value       = aws_s3_bucket.this.id
}