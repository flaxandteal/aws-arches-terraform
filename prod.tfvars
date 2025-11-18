# --------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------
environment = "prod"

# --------------------------------------------------------------------------
# Common 
# --------------------------------------------------------------------------
region = "eu-north-1"
name   = "catalina-prod"

common_tags = {
  Project     = "catalina"
  ManagedBy   = "Terraform"
  CostCenter  = "IT"
  Environment = "Production"
}

extra_tags = {
  Purpose = "Production"
}

# --------------------------------------------------------------------------
# VPC – same CIDR range as UAT (allowed – they’re logically separated by tags & state)
# --------------------------------------------------------------------------
vpc_cidr = "10.20.0.0/16"
vpc_azs  = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]

app_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
db_subnet_cidrs  = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
eks_admin_principal_arn = "arn:aws:iam::123456:user/terraform-deployer" #replace this!
cluster_version         = "1.34"

clusters = {
  instance_type      = "t4g.medium"
  desired_size       = 3
  min_size           = 3
  max_size           = 10
  log_retention_days = 90
}

github_repo = "https://github.com/flaxandteal/catalina-fluxcd"

# --------------------------------------------------------------------------
# RDS
# --------------------------------------------------------------------------
db_class            = "db.m5.large"
db_multi_az         = true
db_backup_retention = 35

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
lifecycle_transition_days = 90
lifecycle_storage_class   = "GLACIER"