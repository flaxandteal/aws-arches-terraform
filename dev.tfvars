# General Settings
region = "us-east-2"
name   = "aws-dev"
extra_tags = {
  Purpose = "development"
}
common_tags = {
  Project    = "aws-cloud"
  ManagedBy  = "Terraform"
  CostCenter = "IT"
}

# Network Settings
ingress_cidr_blocks      = ["0.0.0.0/0"]
nacl_ingress_cidr_blocks = ["0.0.0.0/0"]
subnet_count             = 1

# Storage Settings
lifecycle_transition_days = 30
lifecycle_storage_class   = "GLACIER"

# Cluster Settings
clusters = {
  instance_type      = "t3.nano"
  desired_size       = 1
  min_size           = 1
  max_size           = 1
  log_retention_days = 3
}