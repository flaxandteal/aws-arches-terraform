output "private_subnet_ids" {
  description = "IDs of the private subnets (the first 3 private blocks created)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

output "vpc_id" {
  value = module.vpc.vpc_id
}