terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"  # ← Required by EKS module v21+
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
}

# --------------------------------------------------------------------------
# Common 
# --------------------------------------------------------------------------
module "common" {
  source = "./modules/common"

  name        = var.name
  common_tags = var.common_tags
  extra_tags  = var.extra_tags
}

# --------------------------------------------------------------------------
# VPC
# --------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name        = module.common.name
  common_tags = module.common.common_tags

  cidr = var.vpc_cidr
  azs  = var.vpc_azs
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
module "s3" {
  source = "./modules/s3"
  name   = module.common.name

  lifecycle_transition_days = var.lifecycle_transition_days
  lifecycle_storage_class   = var.lifecycle_storage_class
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  common_tags               = module.common.common_tags
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