output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_oidc_issuer_url" { value = module.eks.oidc_provider }
output "cluster_oidc_arn" { value = module.eks.oidc_provider_arn }

output "node_iam_role_name" { value = module.eks.eks_managed_node_groups.main.iam_role_name }
output "node_iam_role_arn" { value = module.eks.eks_managed_node_groups.main.iam_role_arn }
output "node_security_group_id" { value = module.eks.node_security_group_id }
output "cluster_security_group_id" { value = module.eks.cluster_security_group_id }