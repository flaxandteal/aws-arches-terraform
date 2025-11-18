# --------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------
environment = "stage" # Mirrors Prod

# --------------------------------------------------------------------------
# Common 
# --------------------------------------------------------------------------
region = "eu-north-1"
name   = "catalina-stage"

common_tags = {
  Project    = "catalina"
  ManagedBy  = "Terraform"
  CostCenter = "IT"
  Environment = "Staging"
  Owner       = "FlaxAndTeal"  
}

extra_tags = {
  Purpose = "Staging"
}

# --------------------------------------------------------------------------
# VPC 
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
  desired_size       = 2
  min_size           = 2
  max_size           = 6
  log_retention_days = 30
}

github_repo = "https://github.com/flaxandteal/catalina-fluxcd"

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
lifecycle_transition_days = 60
lifecycle_storage_class   = "GLACIER"