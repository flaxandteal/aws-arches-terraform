# --------------------------------------------------------------------------
# Common
# --------------------------------------------------------------------------
variable "region" { type = string }
variable "name" { type = string }

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

# --------------------------------------------------------------------------
# VPC
# --------------------------------------------------------------------------
variable "vpc_cidr" { type = string }
variable "vpc_azs" { type = list(string) }

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
variable "eks_admin_principal_arn" { type = string }

variable "cluster_version" { type = string }

variable "clusters" {
  type = object({
    instance_type      = string
    desired_size       = number
    min_size           = number
    max_size           = number
    log_retention_days = number
  })
}

variable "github_repo" { type = string }

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
variable "lifecycle_transition_days" {
  description = "Days before transitioning S3 objects"
  type        = number
}

variable "lifecycle_storage_class" {
  description = "S3 lifecycle storage class"
  type        = string
}

# --------------------------------------------------------------------------
# RDS
# --------------------------------------------------------------------------
variable "db_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention" {
  type    = number
  default = 1
}