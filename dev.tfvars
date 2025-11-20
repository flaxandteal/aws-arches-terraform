# --------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------
environment = "dev"

# --------------------------------------------------------------------------
# Common 
# --------------------------------------------------------------------------
region      = "eu-north-1"
name_prefix = "catalina"

extra_tags = {
  Project     = "catalina"
  ManagedBy   = "Terraform"
  CostCenter  = "IT"
  Environment = "Development"
  Owner       = "FlaxAndTeal"
  Purpose     = "development"
}

use_random_suffix = true #set for testing only

# --------------------------------------------------------------------------
# VPC 
# --------------------------------------------------------------------------
vpc_cidr = "10.20.0.0/16"
vpc_azs  = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]

intra_subnet_cidrs = []
# # Smaller subnets – dev doesn't need 3 AZs
# app_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
# db_subnet_cidrs  = ["10.20.11.0/24", "10.20.12.0/24"]

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
eks_admin_principal_arn = "arn:aws:iam::034791378213:user/terraform-deployer"
cluster_version         = "1.34"

node_instance_type = "t4g.small"
node_desired_size  = 1
node_min_size      = 1
node_max_size      = 2

log_retention_days = 3

github_repo = "https://github.com/flaxandteal/catalina-fluxcd"

# --------------------------------------------------------------------------
# RDS – smallest possible
# --------------------------------------------------------------------------
db_class            = "db.t3.micro"
db_multi_az         = false
db_backup_retention = 1

db_storage = 20

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
lifecycle_transition_days = 7
lifecycle_storage_class   = "GLACIER"
force_destroy             = true
#enable_logging   = false
#logging_bucket   = "catalina-dev-logs-bucket" 