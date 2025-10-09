# General Settings
region = "eu-west-2"
name   = "aws-prod"
extra_tags = {
  Purpose = "production"
}
common_tags = {
  Project    = "aws-cloud"
  ManagedBy  = "Terraform"
  CostCenter = "PROD-IT"
}

# Network Settings
ingress_cidr_blocks      = ["10.0.0.0/16"]
nacl_ingress_cidr_blocks = ["10.0.0.0/16"]
subnet_count             = 2

# Storage Settings
lifecycle_transition_days = 30
lifecycle_storage_class   = "DEEP_ARCHIVE"

# Cluster Settings
clusters = {
  instance_type      = "m5.large"
  desired_size       = 3
  min_size           = 2
  max_size           = 6
  log_retention_days = 14
}