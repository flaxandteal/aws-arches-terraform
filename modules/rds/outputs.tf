# modules/rds/outputs.tf
output "endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = module.rds.db_instance_endpoint
}

output "address" {
  description = "The hostname of the RDS instance"
  value       = module.rds.db_instance_address
}

output "port" {
  description = "The database port"
  value       = module.rds.db_instance_port
}

output "arn" {
  description = "ARN of the RDS instance"
  value       = module.rds.db_instance_arn
}

output "id" {
  description = "The RDS instance ID (identifier)"
  value       = module.rds.db_instance_id
}

output "security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.rds.id
}

output "resource_id" {
  description = "The RDS Resource ID (useful for CloudWatch)"
  value       = module.rds.db_instance_resource_id
}