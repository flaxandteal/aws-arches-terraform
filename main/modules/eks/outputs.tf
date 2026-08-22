output "cluster_endpoint" { value = module.eks.cluster_endpoint }

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "ARN of the EKS OIDC provider (for IRSA trust policies)"
}

output "oidc_provider" {
  value       = module.eks.oidc_provider
  description = "EKS OIDC provider URL without https:// prefix"
}