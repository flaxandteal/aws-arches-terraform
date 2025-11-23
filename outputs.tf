# Outputs.tf
# =============================================================================
# Root Outputs – Need these for Flux, CI/CD etc
# =============================================================================
output "s3_bucket_name" { value = module.s3.bucket_name }
output "github_actions_role_arn" { value = module.iam.github_actions_role_arn }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "oidc_issuer_url" { value = module.eks.cluster_oidc_issuer_url }
output "rds_endpoint" { value = module.rds.endpoint }


# output "DEBUG_RDS_INPUTS" {
#   value = {
#     vpc_id_passed_to_rds        = module.vpc.vpc_id
#     db_subnet_ids_passed_to_rds = module.vpc.private_subnet_ids
#     all_inputs_to_rds_module    = module.rds
#   }
#   sensitive = true
# }

# output "debug_vpc_consistency" {
#   value = {
#     vpc_id_from_vpc_module    = module.vpc.vpc_id  # Should be vpc-0660a41447bbca334
#     vpc_id_from_subnet        = data.aws_subnet.first_private.vpc_id  # Must match above
#     rds_security_group_vpc_id = aws_security_group.rds.vpc_id  # Must match above (from module.rds.aws_security_group.rds.vpc_id)
#     rds_subnet_ids            = var.subnet_ids  # Should be subnets starting with subnet- in the same VPC
#   }
# }

# output "debug_vpc_and_subnets" {
#   description = "Confirm EKS and RDS are in the same VPC/subnets"
#   value = {
#     vpc_id                     = module.vpc.vpc_id
#     private_subnet_ids         = module.vpc.private_subnet_ids
#     eks_cluster_name           = module.eks.cluster_name
#     eks_node_security_group_id = module.eks.node_security_group_id
#     rds_security_group_id      = module.rds.aws_security_group.rds.id
#     rds_subnet_group_name      = module.rds.module.rds.db_subnet_group_name
#     rds_instance_endpoint      = module.rds.module.rds.db_instance_endpoint
#   }
# }