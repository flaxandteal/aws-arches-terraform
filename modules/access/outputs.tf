output "iam_user_name" {
  description = "Name of the IAM user"
  value       = aws_iam_user.network_access.name
}