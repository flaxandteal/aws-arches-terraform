# root/variables.tf

# Vvariables used by root main.tf and modules

# --------------------------------------------------------------------------
# Common
# --------------------------------------------------------------------------
variable "environment" {
  description = "Environment name (dev, stage, uat, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names (e.g. catalina-arches)"
  type        = string
  default     = "catalina-arches"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "extra_tags" {
  description = "Extra tags merged via cloudposse/label"
  type        = map(string)
  default     = {}
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (e.g. flaxandteal/catalina-arches)"
  type        = string
}

variable "eks_admin_principal_arn" {
  description = "ARN of IAM principal that gets cluster-admin (usually terraform-deployer user/role)"
  type        = string
}

variable "use_random_suffix" {
  description = "Whether to add a random suffix to KMS alias names (useful for ephemeral or test environments)"
  type        = bool
  default     = false
}

# --------------------------------------------------------------------------
# VPC
# --------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_azs" {
  description = "List of Availability Zones"
  type        = list(string)
}

# variable "app_subnet_cidrs" {
#   description = "CIDR blocks for application (EKS node) private subnets"
#   type        = list(string)
#   default     = []
# }

# variable "db_subnet_cidrs" {
#   description = "CIDR blocks for isolated database subnets"
#   type        = list(string)
#   default     = []
# }

variable "intra_subnet_cidrs" {
  description = "Optional dedicated CIDR blocks for EKS control plane (intra subnets). Leave empty to reuse app subnets"
  type        = list(string)
  default     = []
}

# --------------------------------------------------------------------------
# S3
# --------------------------------------------------------------------------
variable "lifecycle_transition_days" {
  description = "Days before transitioning objects to cheaper storage class"
  type        = number
  default     = 30
}

variable "lifecycle_storage_class" {
  description = "Storage class for lifecycle transition (GLACIER_IR, DEEP_ARCHIVE, etc.)"
  type        = string
  default     = "GLACIER_IR"
}

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.30"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "m6i.large"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 0
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention for EKS control plane"
  type        = number
  default     = 30
}

# --------------------------------------------------------------------------
# RDS
# --------------------------------------------------------------------------
variable "db_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "db_backup_retention" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "db_password" {
  description = "RDS master password (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}