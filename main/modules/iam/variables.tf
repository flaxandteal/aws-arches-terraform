variable "name" { type = string }
variable "github_repo" { type = string }
variable "eks_oidc_arn" { type = string }
variable "account_id" { type = string }
variable "s3_bucket" { type = string }
variable "ecr_repository" { type = string }
variable "common_tags" { type = map(string) }