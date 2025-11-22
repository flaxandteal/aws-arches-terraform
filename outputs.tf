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
#   value = {
#     eks_vpc_id          = module.vpc.vpc_id
#     eks_private_subnets = module.vpc.private_subnet_ids
#     rds_vpc_id          = module.vpc.vpc_id
#     rds_subnet_ids      = module.vpc.private_subnet_ids
#     rds_security_group  = module.rds.aws_security_group.rds.id
#     eks_node_sg         = module.eks.node_security_group_id
#   }
# }