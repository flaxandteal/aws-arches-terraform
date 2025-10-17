output "db_instance_endpoint" {
  value = local.is_serverless ? module.rds_aurora[0].cluster_endpoint : module.rds_standard[0].db_instance_endpoint
}

output "db_instance_id" {
  value = local.is_serverless ? module.rds_aurora[0].cluster_id : module.rds_standard[0].db_instance_identifier
}

output "db_credentials_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}