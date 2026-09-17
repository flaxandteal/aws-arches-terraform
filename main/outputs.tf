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

output "s3_prebuild_bucket_name" {
  value = module.s3_prebuild.bucket_name
}

output "starches_ci_role_arn" {
  value = aws_iam_role.starches_ci.arn
}

output "catalina_build_ecr_push_role_arn" {
  value = aws_iam_role.catalina_build_ecr_push.arn
}

output "ecr_catalina_arches_repository_url" {
  value = module.ecr_catalina_arches.repository_url
}

output "ecr_catalina_arches_static_repository_url" {
  value = module.ecr_catalina_arches_static.repository_url
}

output "ecr_catalina_arches_static_py_repository_url" {
  value = module.ecr_catalina_arches_static_py.repository_url
}

output "ecr_catalina_starches_repository_url" {
  value = module.ecr_catalina_starches.repository_url
}

output "ecr_catalina_starches_private_repository_url" {
  value = module.ecr_catalina_starches_private.repository_url
}

output "flux_image_reflector_role_arn" {
  value = aws_iam_role.flux_image_reflector.arn
}