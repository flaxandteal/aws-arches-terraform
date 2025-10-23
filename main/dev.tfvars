# General Settings
region      = "eu-north-1"
name        = "catalina"
account_id  = "034791378213"                                # Replace with dev account ID
github_repo = "https://github.com/flaxandteal/coral-arches" # Customize
common_tags = {
  Project    = "catalina"
  ManagedBy  = "Terraform"
  CostCenter = "IT"
}
extra_tags = {
  Purpose = "development"
}

# Secrets Settings
#rotation_lambda_arn = "arn:aws:lambda:eu-north-1:034791378213:function:SecretsManager-RotatePostgreSQLSingleUser"

# Network Settings
ingress_cidr_blocks      = ["10.0.0.0/16"]
nacl_ingress_cidr_blocks = ["10.0.0.0/16"]
subnet_count             = 1

# Storage Settings
lifecycle_transition_days = 30
lifecycle_storage_class   = "GLACIER"

# Cluster Settings
eks_admin_principal_arn = "arn:aws:iam::034791378213:user/terraform-deployer"
clusters = {
  instance_type      = "t4g.small" # Graviton-based
  desired_size       = 1
  min_size           = 1
  max_size           = 2
  log_retention_days = 3
}

# Database Settings
db_class            = "db.serverless" # Aurora Serverless
db_multi_az         = false
db_storage          = 0 # Ignored for serverless
db_backup_retention = 7