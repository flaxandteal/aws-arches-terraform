variable "name" {
  description = "Base name (e.g. catalina-arches-uat)"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "s3_kms_key_arn" {
  description = "ARN of the KMS key used for SSE-KMS"
  type        = string
}

variable "lifecycle_transition_days" {
  type    = number
  default = 30
}

variable "lifecycle_storage_class" {
  type    = string
  default = "GLACIER_IR"
  validation {
    condition     = contains(["GLACIER_IR", "DEEP_ARCHIVE", "GLACIER"], var.lifecycle_storage_class)
    error_message = "Must be GLACIER_IR, DEEP_ARCHIVE or GLACIER."
  }
}

variable "enable_logging" {
  type    = bool
  default = false
}

variable "logging_bucket" {
  type    = string
  default = ""
}

variable "force_destroy" {
  description = "Allow terraform destroy to empty and delete bucket (true for dev/stage, false for uat/prod"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}