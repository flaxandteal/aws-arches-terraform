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

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "data_bucket_arn" {
  description = "ARN of the data bucket"
  type        = string
}

variable "logs_bucket_arn" {
  description = "ARN of the logs bucket"
  type        = string
}

variable "tfstate_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  type        = string
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