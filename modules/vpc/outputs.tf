output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "control_plane_subnet_ids" {
  value = module.vpc.private_subnets # same as private for EKS
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}