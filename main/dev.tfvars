# --------------------------------------------------------------------------
# Common 
# --------------------------------------------------------------------------
region = "eu-north-1"
name   = "catalina-dev"

common_tags = {
  Project    = "catalina"
  ManagedBy  = "Terraform"
  CostCenter = "IT"
}

extra_tags = {
  Purpose = "development"
}

# --------------------------------------------------------------------------
# VPC 
# --------------------------------------------------------------------------
vpc_cidr = "10.20.0.0/16"
vpc_azs  = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
eks_admin_principal_arn = "arn:aws:iam::034791378213:user/terraform-deployer" #replace this!
cluster_version         = "1.34"

clusters = {
  instance_type      = "t4g.small"
  desired_size       = 1
  min_size           = 1
  max_size           = 2
  log_retention_days = 3
}

github_repo   = "https://github.com/flaxandteal/catalina-fluxcd"

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
lifecycle_transition_days = 30
lifecycle_storage_class   = "GLACIER"
#enable_logging   = false
#logging_bucket   = "catalina-dev-logs-bucket" 