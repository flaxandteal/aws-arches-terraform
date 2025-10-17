terraform {
  required_version = ">= 1.9.7"

  backend "s3" {
    bucket = "tf-state"  # run backend.tf to create this bucket
    key    = "terraform/state.tfstate"
    region = "eu-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "common" {
  source = "./modules/common"

  name        = var.name
  common_tags = var.common_tags
  extra_tags  = var.extra_tags
}

module "vpc" {
  source = "./modules/vpc"

  region                   = var.region
  name                    = module.common.name
  vpc_cidr                = local.vpc_cidr
  azs                     = local.azs
  subnet_count            = var.subnet_count
  single_nat              = module.common.name != "aws-prod"
  ingress_cidr_blocks     = var.ingress_cidr_blocks
  nacl_ingress_cidr_blocks = var.nacl_ingress_cidr_blocks
  common_tags             = module.common.common_tags
}

module "kms" {
  source = "./modules/kms"

  name        = module.common.name
  common_tags = module.common.common_tags
}

module "eks" {
  source = "./modules/eks"

  name               = module.common.name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  instance_type      = var.clusters.instance_type
  desired_size       = var.clusters.desired_size
  min_size           = var.clusters.min_size
  max_size           = var.clusters.max_size
  log_retention_days = var.clusters.log_retention_days
  kms_key_arn        = module.kms.data_key_arn
  common_tags        = module.common.common_tags
}

module "rds" {
  source = "./modules/rds"

  name               = module.common.name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  eks_sg_id          = module.eks.node_security_group_id
  db_class           = var.db_class
  db_multi_az        = var.db_multi_az
  db_storage         = var.db_storage
  db_backup_retention = var.db_backup_retention
  kms_key_arn        = module.kms.data_key_arn
  common_tags        = module.common.common_tags
}

module "s3" {
  source = "./modules/s3"

  name                     = module.common.name
  account_id               = var.account_id
  kms_key_arn              = module.kms.data_key_arn
  lifecycle_transition_days = var.lifecycle_transition_days
  lifecycle_storage_class   = var.lifecycle_storage_class
  common_tags              = module.common.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  name        = module.common.name
  kms_key_arn = module.kms.ecr_key_arn
  common_tags = module.common.common_tags
}

module "secrets" {
  source = "./modules/secrets"

  name        = module.common.name
  rds_secret  = module.rds.db_credentials_secret_arn
  kms_key_arn = module.kms.secrets_key_arn
  common_tags = module.common.common_tags
}

module "iam" {
  source = "./modules/iam"

  name           = module.common.name
  github_repo    = var.github_repo
  eks_oidc_arn   = module.eks.oidc_provider_arn
  account_id     = var.account_id
  s3_bucket      = module.s3.bucket_name
  ecr_repository = module.ecr.repository_url
  common_tags    = module.common.common_tags
}

output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "rds_instance_endpoint" { value = module.rds.db_instance_endpoint }
output "ecr_repository_url" { value = module.ecr.repository_url }
output "s3_bucket_name" { value = module.s3.bucket_name }