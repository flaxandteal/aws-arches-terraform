# modules/eks/variables.tf

variable "name_prefix" {
  description = "Prefix for all resource names (e.g. catalina-arches)"
  type        = string
}

variable "environment" {
  description = "Environment name – used for naming, tagging and scoping (uat, prod, dev, stage)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (e.g. 1.30)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker nodes"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Optional dedicated subnets for the EKS control plane (intra subnets). Falls back to private_subnet_ids if empty"
  type        = list(string)
  default     = []
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group"
  type        = string
  default     = "m6i.large"
}

variable "node_ami_type" {
  description = "AMI type for nodes (e.g. AL2023_x86_64_STANDARD or AL2023_ARM_64_STANDARD)"
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
}

variable "node_root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 100
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
}

variable "ebs_kms_key_arn" {
  description = "KMS key ARN used to encrypt EBS volumes"
  type        = string
}

variable "eks_admin_principal_arn" {
  description = "ARN of the IAM principal that gets cluster-admin access (usually your terraform-deployer user/role)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (used for tagging and optional IRSA)"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain EKS control plane logs in CloudWatch"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}