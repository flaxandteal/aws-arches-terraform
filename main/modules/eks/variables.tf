variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "account_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "desired_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "kms_key_arn" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

# New variable for the IAM principal that can assume the EKS admin role
variable "eks_admin_principal_arn" {
  description = "ARN of the IAM user or role allowed to assume the EKS admin role"
  type        = string
}
