# --------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------
environment = "dev"

# --------------------------------------------------------------------------
# Common 
# --------------------------------------------------------------------------
region = "eu-north-1"
name   = "catalina-dev"

common_tags = {
  Project     = "catalina"
  ManagedBy   = "Terraform"
  CostCenter  = "IT"
  Environment = "Development"
  Owner       = "FlaxAndTeal"
}

extra_tags = {
  Purpose = "development"
}

# --------------------------------------------------------------------------
# VPC 
# --------------------------------------------------------------------------
vpc_cidr = "10.20.0.0/16"
vpc_azs  = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]

# Smaller subnets – dev doesn't need 3 AZs
app_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
db_subnet_cidrs  = ["10.20.11.0/24", "10.20.12.0/24"]

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
eks_admin_principal_arn = "arn:aws:iam::034791378213:user/terraform-deployer"
cluster_version         = "1.34"

clusters = {
  instance_type      = "t4g.small"
  desired_size       = 1
  min_size           = 1
  max_size           = 2
  log_retention_days = 3
}

github_repo = "https://github.com/flaxandteal/catalina-fluxcd"

log_retention_days = 3

# --------------------------------------------------------------------------
# RDS – smallest possible
# --------------------------------------------------------------------------
db_class            = "db.t3.micro"
db_multi_az         = false
db_backup_retention = 1

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
lifecycle_transition_days = 7
lifecycle_storage_class   = "GLACIER"
#enable_logging   = false
#logging_bucket   = "catalina-dev-logs-bucket" 