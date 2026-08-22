output "cluster_name" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "s3_bucket_name" {
  value       = module.s3.bucket_name
  description = "S3 data bucket name (for django-storages AWS_STORAGE_BUCKET_NAME)"
}

output "arches_s3_role_arn" {
  value       = aws_iam_role.arches_s3.arn
  description = "IRSA role ARN to annotate on Arches ServiceAccounts"
}