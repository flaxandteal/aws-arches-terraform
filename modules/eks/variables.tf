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

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "clusters" {
  description = "EKS cluster configuration"
  type = object({
    instance_type      = string
    desired_size       = number
    min_size           = number
    max_size           = number
    log_retention_days = number
  })
  default = {
    instance_type      = "t3.nano"
    desired_size       = 1
    min_size           = 1
    max_size           = 2
    log_retention_days = 7
  }
  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small", "m5.large", "c5.large"], var.clusters.instance_type)
    error_message = "Instance type must be one of: t3.nano, t3.micro, t3.small, m5.large, c5.large."
  }
  validation {
    condition     = var.clusters.desired_size >= 1
    error_message = "Desired size must be at least 1."
  }
  validation {
    condition     = var.clusters.min_size >= 1
    error_message = "Minimum size must be at least 1."
  }
  validation {
    condition     = var.clusters.max_size >= var.clusters.min_size
    error_message = "Maximum size must be greater than or equal to minimum size."
  }
  validation {
    condition     = var.clusters.log_retention_days >= 1 && var.clusters.log_retention_days <= 365
    error_message = "Log retention days must be between 1 and 365."
  }
}