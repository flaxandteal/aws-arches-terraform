variable "environment" {}
variable "network_id" {
  description = "ID of the network to assign access to"
  type        = string
}
variable "name" {
  description = "Base name for resources"
  type        = string
  default     = "aws-cloud"
}
variable "tags" {
  description = "Tags for resources"
  type        = map(string)
}
variable "data_bucket_arn" {
  description = "ARN of the data bucket"
  type        = string
}
variable "data_kms_key_arn" {
  description = "ARN of the KMS key for the data bucket"
  type        = string
}