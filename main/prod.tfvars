# General Settings
region      = "eu-west-2"
name        = "aws-prod"
account_id  = "456789012345"  # Replace with prod account ID
github_repo = "your-org/your-repo"  # Customize
common_tags = {
  Project    = "aws-cloud"
  ManagedBy  = "Terraform"
  CostCenter = "IT"
}
extra_tags = {
  Purpose = "production"
}

# Network Settings
ingress_cidr_blocks      = ["10.0.0.0/16"]
nacl_ingress_cidr_blocks = ["10.0.0.0/16"]
subnet_count             = 2

# Storage Settings
lifecycle_transition_days = 30
lifecycle_storage_class   = "GLACIER"

# Cluster Settings
clusters = {
  instance_type      = "m6g.large"  # Graviton-based
  desired_size       = 3
  min_size           = 3
  max_size           = 10
  log_retention_days = 30
}

# Database Settings
db_class           = "db.m6g.large"  # Graviton-based
db_multi_az        = true
db_storage         = 200
db_backup_retention = 30