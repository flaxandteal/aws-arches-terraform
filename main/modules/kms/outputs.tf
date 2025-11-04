output "ebs_kms_key_arn" {
  value       = aws_kms_key.ebs.arn
  description = "ARN of the KMS key used for EBS encryption"
}

output "s3_kms_key_arn" {
  value       = aws_kms_key.s3.arn
  description = "ARN of the KMS key used for S3 encryption"
}