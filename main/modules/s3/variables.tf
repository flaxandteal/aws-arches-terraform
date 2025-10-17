variable "name" { type = string }
variable "account_id" { type = string }
variable "kms_key_arn" { type = string }
variable "lifecycle_transition_days" { type = number }
variable "lifecycle_storage_class" { type = string }
variable "common_tags" { type = map(string) }