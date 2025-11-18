# =============================================================================
# Catalina Arches – Root main.tf (November 2025)
# Single source of truth · Zero duplication · Fully private · DOC-compliant
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70" # Stable + compatible with all official modules below
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

  backend "s3" {} # Config generated at runtime from GitHub secret
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
# Naming & Tagging (cloudposse/label – the gold standard)
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
# 1. VPC – Fully private, isolated subnets
# =============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13.0"

  name = local.name
  cidr = var.vpc_cidr

  azs              = var.vpc_azs
  private_subnets  = var.app_subnet_cidrs # EKS worker nodes
  database_subnets = var.db_subnet_cidrs  # Isolated RDS
  #intra_subnets    = var.intra_subnet_cidrs    # Optional: extra isolation for control plane

  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  create_igw           = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = module.labels.tags
}

# =============================================================================
# 2. KMS – Per-environment keys (created early – many things depend on them)
# =============================================================================
module "kms" {
  source = "./modules/kms"

  name = local.name
  #environment        = var.environment
  eks_node_role_arns = [] # Filled in after EKS (null_resource workaround below)
  tags               = module.labels.tags
}

# =============================================================================
# 3. EKS – Fully private cluster
# =============================================================================
module "eks" {
  source = "./modules/eks"

  name_prefix     = var.name_prefix
  environment     = var.environment
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnets
  control_plane_subnet_ids = var.intra_subnet_cidrs != [] ? var.intra_subnet_cidrs : module.vpc.private_subnets

  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  node_desired_size  = var.node_desired_size

  ebs_kms_key_arn         = module.kms.ebs_kms_key_arn
  eks_admin_principal_arn = var.eks_admin_principal_arn
  github_repo             = var.github_repo
  log_retention_days      = var.log_retention_days

  tags = module.labels.tags

  depends_on = [module.kms]
}

# =============================================================================
# 4. Update KMS policy with EKS node role (circular dependency fix)
# =============================================================================
resource "aws_kms_key_policy" "update_storage_policy" {
  key_id     = module.kms.ebs_kms_key_id
  policy     = data.aws_iam_policy_document.updated_storage.json
  depends_on = [module.eks]
}

data "aws_iam_policy_document" "updated_storage" {
  override_policy_documents = [module.kms.storage_key_policy]

  statement {
    sid    = "AllowEKSNodes"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.eks.node_iam_role_arn]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }
}

# =============================================================================
# 5. IAM – GitHub OIDC + IRSA
# =============================================================================
module "iam" {
  source = "./modules/iam"

  name_prefix = var.name_prefix
  environment = var.environment
  github_repo = var.github_repo
  tags        = module.labels.tags

  depends_on = [module.eks] # Needs OIDC URL from cluster
}

# =============================================================================
# 6. RDS – Standard PostgreSQL (official module wrapper)
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
  #db_password            = var.db_password   # optional – auto-generated if empty
  kms_key_arn = module.kms.rds_kms_key_arn

  tags = module.labels.tags

  depends_on = [module.eks]
}

# =============================================================================
# 7. S3 – Application data bucket
# =============================================================================
module "s3" {
  source = "./modules/s3"

  name                      = local.name
  environment               = var.environment
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  lifecycle_transition_days = var.lifecycle_transition_days
  lifecycle_storage_class   = var.lifecycle_storage_class
  force_destroy             = var.environment != "prod" # easy cleanup in lower envs

  tags = module.labels.tags
}

# =============================================================================
# 8. VPC Endpoints – Mandatory for fully private operation
# =============================================================================
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc-endpoints/aws"
  version = "~> 5.0"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids])
    }
    ecr_api     = { service = "ecr.api", private_dns_enabled = true }
    ecr_dkr     = { service = "ecr.dkr", private_dns_enabled = true }
    ssm         = { service = "ssm", private_dns_enabled = true }
    ssmmessages = { service = "ssmmessages", private_dns_enabled = true }
    ec2messages = { service = "ec2messages", private_dns_enabled = true }
    sts         = { service = "sts", private_dns_enabled = true }
    kms         = { service = "kms", private_dns_enabled = true }
    logs        = { service = "logs", private_dns_enabled = true }
  }

  security_group_ids = [module.eks.node_security_group_id]
  tags               = module.labels.tags

  depends_on = [module.eks]
}