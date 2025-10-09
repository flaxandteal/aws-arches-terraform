output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "iam_user_name" {
  description = "Name of the IAM user"
  value       = module.access.iam_user_name
}

output "data_bucket" {
  description = "Name of the data bucket"
  value       = module.storage.data_bucket
}

output "logs_bucket" {
  description = "Name of the logs bucket"
  value       = module.storage.logs_bucket
}

output "tfstate_bucket" {
  description = "Name of the Terraform state bucket"
  value       = module.storage.tfstate_bucket
}

output "s3_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = module.network.s3_endpoint_id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "data_kms_key_arn" {
  description = "ARN of the KMS key for the data bucket"
  value       = module.storage.data_kms_key_arn
}