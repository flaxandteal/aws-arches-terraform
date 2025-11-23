# modules/vpc/variables.tf
variable "name" {
  type        = string
  description = "Full cluster name (e.g. arches-prod)"
}

variable "cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags to add on top of the ones from the label module"
}

variable "s3_logging_bucket_arn" {
  description = "ARN of the central S3 bucket used for VPC Flow Logs"
  type        = string
}

variable "account_id" {
  description = "AWS account ID (passed from root)"
  type        = string
}