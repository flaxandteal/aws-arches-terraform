output "endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "security_group_id" {
  description = "Security group ID attached to RDS"
  value       = aws_security_group.rds.id
}

output "instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}