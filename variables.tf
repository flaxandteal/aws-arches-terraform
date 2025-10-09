variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "eu-west-2"
  validation {
    condition     = can(regex("^([a-z]{2}-[a-z]+-[0-9])$", var.region))
    error_message = "Region must be a valid AWS region (e.g., eu-west-2)."
  }
}

variable "name" {
  description = "Base name for resources"
  type        = string
  default     = "aws-cloud"
  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 32
    error_message = "Name must be between 3 and 32 characters."
  }
}

variable "extra_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Common tags for all resources (e.g., Project, ManagedBy, CostCenter)"
  type        = map(string)
  default = {
    Project    = "aws-cloud"
    ManagedBy  = "Terraform"
    CostCenter = "IT"
  }
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks for security group ingress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  validation {
    condition     = alltrue([for cidr in var.ingress_cidr_blocks : can(cidrsubnet(cidr, 0, 0))])
    error_message = "Each ingress_cidr_blocks entry must be a valid CIDR block."
  }
}

variable "nacl_ingress_cidr_blocks" {
  description = "CIDR blocks for Network ACL ingress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  validation {
    condition     = alltrue([for cidr in var.nacl_ingress_cidr_blocks : can(cidrsubnet(cidr, 0, 0))])
    error_message = "Each nacl_ingress_cidr_blocks entry must be a valid CIDR block."
  }
}

variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 1
  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 2
    error_message = "Subnet count must be 1 or 2."
  }
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