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

# --------------------------------------------------------------------------
# IRSA – S3 media access for Arches workloads
# --------------------------------------------------------------------------
data "aws_iam_policy_document" "arches_s3_assume" {
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
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:sub"
      values   = var.arches_s3_service_accounts
    }
  }
}

resource "aws_iam_role" "arches_s3" {
  name               = "${module.common.name}-arches-s3"
  assume_role_policy = data.aws_iam_policy_document.arches_s3_assume.json
  tags               = module.common.common_tags
}

resource "aws_iam_policy" "arches_s3" {
  name = "${module.common.name}-arches-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.s3.bucket_arn,
          "${module.s3.bucket_arn}/*",
        ]
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = [module.kms.s3_kms_key_arn]
      },
    ]
  })
  tags = module.common.common_tags
}

resource "aws_iam_role_policy_attachment" "arches_s3" {
  role       = aws_iam_role.arches_s3.name
  policy_arn = aws_iam_policy.arches_s3.arn
}

# --------------------------------------------------------------------------
# S3 – prebuild bucket (starches tarballs from JupyterHub -> CI)
# --------------------------------------------------------------------------
resource "random_id" "prebuild_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "prebuild" {
  bucket = "${module.common.name}-prebuild-${random_id.prebuild_suffix.hex}"
  tags = merge(module.common.common_tags, {
    Name = "${module.common.name}-prebuild"
  })
}

resource "aws_s3_bucket_versioning" "prebuild" {
  bucket = aws_s3_bucket.prebuild.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prebuild" {
  bucket = aws_s3_bucket.prebuild.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.kms.s3_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "prebuild" {
  bucket                  = aws_s3_bucket.prebuild.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IRSA – JupyterHub notebooks push prebuild tarballs
data "aws_iam_policy_document" "prebuild_push_assume" {
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
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:sub"
      values   = var.prebuild_push_service_accounts
    }
  }
}

resource "aws_iam_role" "prebuild_push" {
  name               = "${module.common.name}-prebuild-push"
  assume_role_policy = data.aws_iam_policy_document.prebuild_push_assume.json
  tags               = module.common.common_tags
}

resource "aws_iam_policy" "prebuild_push" {
  name = "${module.common.name}-prebuild-push"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3PushPrebuild"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.prebuild.arn,
          "${aws_s3_bucket.prebuild.arn}/*",
        ]
      },
      {
        Sid    = "KMSEncrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = [module.kms.s3_kms_key_arn]
      },
    ]
  })
  tags = module.common.common_tags
}

resource "aws_iam_role_policy_attachment" "prebuild_push" {
  role       = aws_iam_role.prebuild_push.name
  policy_arn = aws_iam_policy.prebuild_push.arn
}

# IRSA – CI runner pulls prebuild tarballs
data "aws_iam_policy_document" "prebuild_pull_assume" {
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
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:sub"
      values   = var.prebuild_pull_service_accounts
    }
  }
}

resource "aws_iam_role" "prebuild_pull" {
  name               = "${module.common.name}-prebuild-pull"
  assume_role_policy = data.aws_iam_policy_document.prebuild_pull_assume.json
  tags               = module.common.common_tags
}

resource "aws_iam_policy" "prebuild_pull" {
  name = "${module.common.name}-prebuild-pull"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3PullPrebuild"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.prebuild.arn,
          "${aws_s3_bucket.prebuild.arn}/*",
        ]
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Resource = [module.kms.s3_kms_key_arn]
      },
    ]
  })
  tags = module.common.common_tags
}

resource "aws_iam_role_policy_attachment" "prebuild_pull" {
  role       = aws_iam_role.prebuild_pull.name
  policy_arn = aws_iam_policy.prebuild_pull.arn
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

# --------------------------------------------------------------------------
# ECR - sji don't need this. images still in github presumably?
# --------------------------------------------------------------------------
# module "ecr" {
#   source = "./modules/ecr"

#   name        = module.common.name
#   common_tags = module.common.common_tags
# }
