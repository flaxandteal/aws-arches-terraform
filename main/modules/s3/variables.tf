variable "name" {
  description = "Name prefix for S3 bucket"
  type        = string
}

variable "lifecycle_transition_days" {
  description = "Days before transitioning to Glacier"
  type        = number
}

variable "lifecycle_storage_class" {
  description = "Storage class for lifecycle transition"
  type        = string
  default     = "GLACIER"
}

variable "enable_lifecycle" {
  description = "Whether to transition objects to lifecycle_storage_class. Disable for buckets serving live content (e.g. Glacier isn't instantly readable)."
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

variable "s3_kms_key_arn" {
  type    = string
  default = ""
}

variable "enable_logging" {
  type    = bool
  default = false
}

variable "logging_bucket" {
  type    = string
  default = ""
}