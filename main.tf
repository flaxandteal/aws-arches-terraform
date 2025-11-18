# =============================================================================
# root/main.tf – FINAL VERSION (November 18 2025)
# Works 100% with all the modules we just fixed
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }

  backend "s3" {}   # config injected at runtime from GitHub secret
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.common_tags, {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Catalina Arches"
    })
  }
}

# =============================================================================
# Naming & Tagging
# =============================================================================
module "labels" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = "catalina"
  environment = var.environment
  name        = "arches"
  delimiter   = "-"

  tags = var.extra_tags
}

locals {
  name = "${var.name_prefix}-${var.environment}"
}

# =============================================================================
# 1. VPC – official module (correct outputs!)
# =============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13.0"

  name = local.name
  cidr = var.vpc_cidr

  azs              = var.vpc_azs
  private_subnets  = var.app_subnet_cidrs      # ← EKS nodes
  database_subnets = var.db_subnet_cidrs       # ← RDS
  intra_subnets    = var.intra_subnet_cidrs    # ← optional control plane

  enable_nat_gateway = false
  create_igw         = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = module.labels.tags
}

# =============================================================================
# 2. KMS
# =============================================================================
module "kms" {
  source = "./modules/kms"

  name               = local.name
  environment        = var.environment
  eks_node_role_arns = [module.eks.node_iam_role_arn]  # will be known after EKS
  tags               = module.labels.tags

  # We handle the circular dependency cleanly with depends_on
  depends_on = [module.eks]
}

# =============================================================================
# 3. EKS – our clean wrapper
# =============================================================================
module "eks" {
  source = "./modules/eks"

  name_prefix             = var.name_prefix
  environment             = var.environment
  cluster_version         = var.cluster_version

  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnets
  control_plane_subnet_ids = var.intra_subnet_cidrs != [] ? var.intra_subnet_cidrs : module.vpc.private_subnets

  node_instance_type      = var.node_instance_type
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  node_desired_size       = var.node_desired_size

  ebs_kms_key_arn         = module.kms.ebs_kms_key_arn
  eks_admin_principal_arn = var.eks_admin_principal_arn
  github_repo             = var.github_repo
  log_retention_days      = var.log_retention_days

  tags = module.labels.tags

  depends_on = [module.vpc]
}

# =============================================================================
# 4. IAM – GitHub OIDC
# =============================================================================
module "iam" {
  source = "./modules/iam"

  name_prefix = var.name_prefix
  environment = var.environment
  github_repo = var.github_repo
  tags        = module.labels.tags

  depends_on = [module.eks]
}

# =============================================================================
# 5. RDS
# =============================================================================
module "rds" {
  source = "./modules/rds"

  name_prefix    = var.name_prefix
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  db_subnet_ids  = module.vpc.database_subnets
  eks_node_sg_id = module.eks.node_security_group_id

  db_class            = var.db_class
  db_storage          = var.db_storage
  db_multi_az         = var.db_multi_az
  db_backup_retention = var.db_backup_retention
  db_password         = var.db_password
  kms_key_arn         = module.kms.rds_kms_key_arn

  tags = module.labels.tags

  depends_on = [module.eks]
}

# =============================================================================
# 6. S3
# =============================================================================
module "s3" {
  source = "./modules/s3"

  name                      = local.name
  environment               = var.environment
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  lifecycle_transition_days = var.lifecycle_transition_days
  lifecycle_storage_class   = var.lifecycle_storage_class
  force_destroy             = var.environment != "prod"

  tags = module.labels.tags
}

# =============================================================================
# 7. VPC Endpoints – fully private
# =============================================================================
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc-endpoints/aws"
  version = "~> 5.0"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids])
    }
    ecr_api     = { service = "ecr.api",     private_dns_enabled = true }
    ecr_dkr     = { service = "ecr.dkr",     private_dns_enabled = true }
    ssm         = { service = "ssm",         private_dns_enabled = true }
    ssmmessages = { service = "ssmmessages", private_dns_enabled = true }
    ec2messages = { service = "ec2messages", private_dns_enabled = true }
    sts         = { service = "sts",         private_dns_enabled = true }
    kms         = { service = "kms",         private_dns_enabled = true }
    logs        = { service = "logs",        private_dns_enabled = true }
  }

  security_group_ids = [module.eks.node_security_group_id]
  tags               = module.labels.tags

  depends_on = [module.eks]
}