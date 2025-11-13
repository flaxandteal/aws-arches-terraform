output "db_endpoint" {
  value = local.is_serverless ? (
    try(module.rds_aurora[0].cluster_endpoint, "")
    ) : (
    try(module.rds_standard[0].db_instance_endpoint, "")
  )
  description = "RDS endpoint (host:port)"
}

output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db_credentials.arn
  description = "Secrets Manager secret ARN"
}

output "db_security_group_id" {
  value       = aws_security_group.rds.id
  description = "Security group ID for RDS"
}