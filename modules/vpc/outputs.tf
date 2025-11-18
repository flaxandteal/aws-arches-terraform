# ./modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs – use this everywhere (EKS, RDS, VPC endpoints)"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_route_table_ids" {
  description = "List of private route table IDs (for S3/DynamoDB endpoints, etc.)"
  value       = module.vpc.private_route_table_ids
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}