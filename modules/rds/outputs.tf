# modules/rds/outputs.tf
output "endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = module.rds.db_instance_endpoint
}

output "address" {
  description = "RDS instance hostname only"
  value       = module.rds.db_instance_address
}

output "port" {
  description = "Database port"
  value       = module.rds.db_instance_port
}

output "arn" {
  description = "ARN of the RDS instance"
  value       = module.rds.db_instance_arn
}

output "identifier" {
  description = "The RDS instance identifier (same as name)"
  value       = module.rds.db_instance_identifier # ← this is the correct attribute
}

output "resource_id" {
  description = "RDS Resource ID (for CloudWatch metrics)"
  value       = module.rds.db_instance_resource_id
}

# output "security_group_id" {
#   description = "Security group attached to RDS"
#   value       = aws_security_group.rds.id
# }