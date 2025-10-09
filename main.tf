terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "tfstate-dev"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "fstate-lock-dev"
  }
}

provider "aws" {
  region = var.region
}

locals {
  valid_workspace = contains(["dev", "stage", "uat", "prod"], terraform.workspace) ? terraform.workspace : (terraform.workspace == "default" ? tostring(null) : terraform.workspace)
}

module "common" {
  source      = "./modules/common"
  environment = local.valid_workspace == null ? (file("ERROR: Default workspace is not allowed. Run `terraform workspace select dev` or create a valid workspace (dev, stage, uat, prod).")) : local.valid_workspace
  common_tags = var.common_tags
}

module "network" {
  source                   = "./modules/network"
  environment              = local.valid_workspace == null ? (file("ERROR: Invalid workspace")) : local.valid_workspace
  region                   = var.region
  name                     = var.name
  extra_tags               = var.extra_tags
  cidr_block               = module.common.cidr_blocks[local.valid_workspace]
  tags                     = module.common.tags
  data_bucket_arn          = module.storage.data_bucket_arn
  logs_bucket_arn          = module.storage.logs_bucket_arn
  tfstate_bucket_arn       = module.storage.tfstate_bucket_arn
  ingress_cidr_blocks      = var.ingress_cidr_blocks
  nacl_ingress_cidr_blocks = var.nacl_ingress_cidr_blocks
  subnet_count             = var.subnet_count
}

module "access" {
  source           = "./modules/access"
  environment      = local.valid_workspace == null ? (file("ERROR: Invalid workspace")) : local.valid_workspace
  network_id       = module.network.vpc_id
  tags             = module.common.tags
  data_bucket_arn  = module.storage.data_bucket_arn
  data_kms_key_arn = module.storage.data_kms_key_arn
}

module "storage" {
  source                    = "./modules/storage"
  environment               = local.valid_workspace == null ? (file("ERROR: Invalid workspace")) : local.valid_workspace
  region                    = var.region
  name                      = var.name
  extra_tags                = var.extra_tags
  tags                      = module.common.tags
  lifecycle_transition_days = var.lifecycle_transition_days
  lifecycle_storage_class   = var.lifecycle_storage_class
}

module "eks" {
  source      = "./modules/eks"
  environment = local.valid_workspace == null ? (file("ERROR: Invalid workspace")) : local.valid_workspace
  region      = var.region
  name        = var.name
  extra_tags  = var.extra_tags
  tags        = module.common.tags
  vpc_id      = module.network.vpc_id
  subnet_ids  = module.network.subnet_ids
  clusters    = var.clusters
}