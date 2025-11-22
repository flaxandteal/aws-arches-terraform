# output "vpc_id" {
#   value = module.vpc.vpc_id
# }
# =============================================================================
# Outputs – Need these for Flux, operators, and CI/CD
# =============================================================================
output "s3_bucket_name" { value = module.s3.bucket_name }
output "github_actions_role_arn" { value = module.iam.github_actions_role_arn }
#output "cluster_name" { value = module.eks.cluster_name }
#output "cluster_endpoint" { value = module.eks.cluster_endpoint }
#output "oidc_issuer_url" { value = module.eks.cluster_oidc_issuer_url }
output "rds_endpoint" { value = module.rds.endpoint }


# root/outputs.tf

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