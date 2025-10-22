# General Settings
region      = "eu-north-1"
name        = "aws-stage"
account_id  = "234567890123"       # Replace with staging account ID
github_repo = "your-org/your-repo" # Customize
common_tags = {
  Project    = "aws-cloud"
  ManagedBy  = "Terraform"
  CostCenter = "IT"
}
extra_tags = {
  Purpose = "staging"
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
  min_size           = 1
  max_size           = 3
  log_retention_days = 7
}

# Database Settings
db_class            = "db.serverless" # Aurora Serverless
db_multi_az         = false
db_storage          = 0 # Ignored for serverless
db_backup_retention = 7