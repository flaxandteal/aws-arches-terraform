terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # ← Required by EKS module v21+
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.common_tags, {
      Environment = var.environment
      ManagedBy   = "Terraform"
    })
  }
}

locals {
  name         = "${var.name_prefix}-${var.environment}"
  cluster_name = "${var.name_prefix}-${var.environment}"
}

# --------------------------------------------------------------------------
# Labelc
# --------------------------------------------------------------------------
module "labels" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = "catalina"
  environment = var.environment
  name        = "arches"
  delimiter   = "-"

  tags = var.extra_tags
}

# # --------------------------------------------------------------------------
# # Common 
# # --------------------------------------------------------------------------
# module "common" {
#   source = "./modules/common"

#   name        = var.name
#   common_tags = var.common_tags
#   extra_tags  = var.extra_tags
# }

# --------------------------------------------------------------------------
# VPC
# --------------------------------------------------------------------------
# module "vpc" {
#   source = "./modules/vpc"

#   name        = module.common.name
#   common_tags = module.common.common_tags

#   cidr = var.vpc_cidr
#   azs  = var.vpc_azs
# }
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13.0"

  name = local.name
  cidr = var.vpc_cidr

  azs              = var.vpc_azs
  private_subnets  = var.app_subnet_cidrs
  database_subnets = var.db_subnet_cidrs

  enable_nat_gateway = false
  create_igw         = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = module.labels.tags
}

# --------------------------------------------------------------------------
# IAM
# --------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  name        = module.common.name
  common_tags = module.common.common_tags
  github_repo = var.github_repo
  region      = var.region
}

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  name        = module.common.name
  common_tags = module.common.common_tags

  github_repo             = var.github_repo
  eks_admin_principal_arn = var.eks_admin_principal_arn

  cluster_version          = var.cluster_version
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.control_plane_subnet_ids

  node_group = {
    instance_type = var.clusters.instance_type
    desired_size  = var.clusters.desired_size
    min_size      = var.clusters.min_size
    max_size      = var.clusters.max_size
  }

  #ebs_kms_key_arn = module.kms.ebs_kms_key_arn

  log_retention_days = var.clusters.log_retention_days

}

# --------------------------------------------------------------------------
# KMS 
# --------------------------------------------------------------------------
module "kms" {
  source = "./modules/kms"

  name               = module.common.name
  common_tags        = module.common.common_tags
  node_iam_role_name = module.eks.node_iam_role_name # for EBS key policy
}

# --------------------------------------------------------------------------
# s3
# --------------------------------------------------------------------------
# module "s3" {
#   source = "./modules/s3"
#   name   = module.common.name

#   lifecycle_transition_days = var.lifecycle_transition_days
#   lifecycle_storage_class   = var.lifecycle_storage_class
#   s3_kms_key_arn            = module.kms.s3_kms_key_arn
#   common_tags               = module.common.common_tags
# }

module "s3" {
  source = "./modules/s3"

  name                      = local.name
  environment = var.environment
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  lifecycle_transition_days = var.lifecycle_transition_days
  lifecycle_storage_class   = var.lifecycle_storage_class

  tags = module.labels.tags
}

# --------------------------------------------------------------------------
# RDS
# --------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name        = module.common.name
  common_tags = module.common.common_tags

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  eks_sg_id  = module.eks.node_security_group_id

  db_class            = var.db_class
  db_storage          = var.db_storage
  db_multi_az         = var.db_multi_az
  db_backup_retention = var.db_backup_retention
  kms_key_arn         = module.kms.ebs_kms_key_arn
}

# module "ecr" {
#   source = "./modules/ecr"

#   name        = module.common.name
#   common_tags = module.common.common_tags
# }