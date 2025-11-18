output "ebs_kms_key_arn" { value = aws_kms_key.storage.arn }
output "rds_kms_key_arn" { value = aws_kms_key.storage.arn } # same key
output "s3_kms_key_arn" { value = aws_kms_key.s3.arn }