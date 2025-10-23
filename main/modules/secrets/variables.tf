variable "name" { type = string }
variable "rds_secret" { type = string }
variable "kms_key_arn" { type = string }
variable "common_tags" { type = map(string) }
# variable "rotation_lambda_arn" {
#   description = "ARN of the Lambda function to use for secret rotation"
#   type        = string
# }
