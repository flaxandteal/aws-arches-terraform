# modules/rds/variables.tf

variable "name_prefix" {
  description = "Prefix for resource names (e.g. catalina-arches)"
  type        = string
}

variable "environment" {
  description = "Environment name (uat, prod, dev, stage)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "db_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

# variable "eks_node_sg_id" {
#   description = "Security Group ID of the EKS worker nodes (to allow PostgreSQL traffic)"
#   type        = string
# }

variable "db_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_backup_retention" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "db_password" {
  description = "Master password (leave empty to auto-generate a secure one)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "kms_key_arn" { 
  description = "KMS key ARN for RDS encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}