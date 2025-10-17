output "data_key_arn" { value = aws_kms_key.data.arn }
output "secrets_key_arn" { value = aws_kms_key.secrets.arn }
output "ecr_key_arn" { value = aws_kms_key.ecr.arn }