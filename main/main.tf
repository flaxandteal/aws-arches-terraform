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
# EKS
# --------------------------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  name        = module.common.name
  common_tags = module.common.common_tags

  github_repo             = var.github_repo
  eks_admin_principal_arn = var.eks_admin_principal_arn

  cluster_version          = var.cluster_version
  vpc_id                   = var.vpc_id
  subnet_ids               = var.app_subnet_ids
  control_plane_subnet_ids = var.app_subnet_ids

  node_group = {
    instance_type = var.clusters.instance_type
    desired_size  = var.clusters.desired_size
    min_size      = var.clusters.min_size
    max_size      = var.clusters.max_size
  }

  # Circular dependency: KMS needs node_iam_role_name from EKS, EKS needs KMS key
  # EBS volumes still encrypted with AWS-managed key by default
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

# Dedicated bucket for starches media, served live via the s3-gateway pod -
# kept separate from the general-purpose bucket above, and with lifecycle
# transitions disabled since Glacier isn't instantly readable.
module "s3_media" {
  source = "./modules/s3"
  name   = "${module.common.name}-media"

  lifecycle_transition_days = var.lifecycle_transition_days
  enable_lifecycle          = false
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  common_tags               = module.common.common_tags
}

# --------------------------------------------------------------------------
# s3-gateway (srv-starches) access to the media bucket
# --------------------------------------------------------------------------
# IRSA, not a static IAM user: the org SCP (p-1ubxebgn) denies iam:CreateUser
# outright, so static credentials aren't an option here. We swapped the
# gateway image from nginx-s3-gateway (which only takes static env-var
# creds and can't refresh STS tokens itself) to aws-sigv4-proxy, which uses
# the default AWS SDK credential chain and picks up IRSA automatically.
data "aws_iam_policy_document" "s3_gateway_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:srv-starches:s3-gateway"]
    }
  }
}

resource "aws_iam_role" "s3_gateway" {
  name               = "${module.common.name}-s3-gateway"
  assume_role_policy = data.aws_iam_policy_document.s3_gateway_assume_role.json
  tags               = module.common.common_tags
}

data "aws_iam_policy_document" "s3_gateway_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.s3_media.bucket_arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.s3_media.bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_gateway" {
  name   = "${module.common.name}-s3-gateway-access"
  role   = aws_iam_role.s3_gateway.name
  policy = data.aws_iam_policy_document.s3_gateway_access.json
}

# --------------------------------------------------------------------------
# RDS
# --------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name        = module.common.name
  common_tags = module.common.common_tags

  vpc_id     = var.vpc_id
  subnet_ids = var.data_subnet_ids
  eks_sg_id  = module.eks.node_security_group_id

  db_class            = var.db_class
  db_storage          = var.db_storage
  db_multi_az         = var.db_multi_az
  db_backup_retention = var.db_backup_retention
  kms_key_arn         = module.kms.ebs_kms_key_arn
}

# --------------------------------------------------------------------------
# ECR - sji don't need this. images still in github presumably?
# --------------------------------------------------------------------------
# module "ecr" {
#   source = "./modules/ecr"

#   name        = module.common.name
#   common_tags = module.common.common_tags
# }