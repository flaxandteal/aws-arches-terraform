output "cluster_name" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = var.vpc_id
}

output "s3_media_bucket_name" {
  value = module.s3_media.bucket_name
}

output "s3_gateway_role_arn" {
  value = aws_iam_role.s3_gateway.arn
}