variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name" {
  description = "Base name for resources"
  type        = string
}

variable "extra_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
}

variable "lifecycle_transition_days" {
  description = "Days before transitioning objects to another storage class"
  type        = number
  default     = 30
  validation {
    condition     = var.lifecycle_transition_days >= 30
    error_message = "Lifecycle transition days must be at least 30."
  }
}

variable "lifecycle_storage_class" {
  description = "Storage class for lifecycle transition"
  type        = string
  default     = "GLACIER"
  validation {
    condition     = contains(["GLACIER", "DEEP_ARCHIVE"], var.lifecycle_storage_class)
    error_message = "Storage class must be GLACIER or DEEP_ARCHIVE."
  }
}