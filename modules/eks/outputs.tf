output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_log_group_name" {
  description = "Name of the CloudWatch log group for EKS logs"
  value       = aws_cloudwatch_log_group.eks_logs.name
}