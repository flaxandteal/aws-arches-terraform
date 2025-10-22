# General Settings
region      = "eu-north-1"
name        = "aws-uat"
account_id  = "345678901234"       # Replace with uat account ID
github_repo = "your-org/your-repo" # Customize
common_tags = {
  Project    = "aws-cloud"
  ManagedBy  = "Terraform"
  CostCenter = "IT"
}
extra_tags = {
  Purpose = "uat"
}

# Network Settings
ingress_cidr_blocks      = ["10.0.0.0/16"]
nacl_ingress_cidr_blocks = ["10.0.0.0/16"]
subnet_count             = 1

# Storage Settings
lifecycle_transition_days = 30
lifecycle_storage_class   = "GLACIER"

# Cluster Settings
clusters = {
  instance_type      = "t4g.medium" # Graviton-based
  desired_size       = 2
  min_size           = 2
  max_size           = 4
  log_retention_days = 14
}

# Database Settings
db_class            = "db.t4g.medium" # Graviton-based
db_multi_az         = true
db_storage          = 100
db_backup_retention = 14