output "tags" {
  description = "Tags to apply to all resources"
  value       = local.tags
}

output "cidr_blocks" {
  description = "Map of environment to CIDR blocks"
  value       = local.cidr_blocks
}