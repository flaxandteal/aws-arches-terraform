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
# Prebuild data bucket (starches CI) - source of the prebuild.tar the
# catalina-starches Docker build pulls in. Separate from the media bucket
# above: different consumer (CI runner pod, not the live s3-gateway),
# different lifecycle needs.
# --------------------------------------------------------------------------
module "s3_prebuild" {
  source = "./modules/s3"
  name   = "${module.common.name}-prebuild"

  lifecycle_transition_days = var.lifecycle_transition_days
  enable_lifecycle          = false
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  common_tags               = module.common.common_tags
}

# --------------------------------------------------------------------------
# starches-ci (srv-github-ci) access to the prebuild bucket
# --------------------------------------------------------------------------
# IRSA again, same reasoning as s3-gateway above: the org SCP denies
# iam:CreateUser, so a static S3_ACCESS_KEY/S3_SECRET_KEY pair (what the old
# dev CI used) isn't possible on this account. The new-zealand-starches-uat
# runner pod is bound to a dedicated ServiceAccount (srv-github-ci/starches-ci)
# scoped to just this role, so no other CI job on the cluster inherits it.
data "aws_iam_policy_document" "starches_ci_assume_role" {
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
      values   = ["system:serviceaccount:srv-github-ci:starches-ci"]
    }
  }
}

resource "aws_iam_role" "starches_ci" {
  name               = "${module.common.name}-starches-ci"
  assume_role_policy = data.aws_iam_policy_document.starches_ci_assume_role.json
  tags               = module.common.common_tags
}

data "aws_iam_policy_document" "starches_ci_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.s3_prebuild.bucket_arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${module.s3_prebuild.bucket_arn}/*"]
  }

  # The bucket's SSE-KMS default encryption means S3 alone isn't enough -
  # the calling principal also needs kms:Decrypt/GenerateDataKey* on the
  # key itself. The key's policy allows IAM delegation ("Enable IAM User
  # Permissions" statement in modules/kms/main.tf), but that only takes
  # effect once the calling role's own identity policy grants it too.
  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = [module.kms.s3_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "starches_ci" {
  name   = "${module.common.name}-starches-ci-access"
  role   = aws_iam_role.starches_ci.name
  policy = data.aws_iam_policy_document.starches_ci_access.json
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
# GitHub Actions deploy role (catalina-<environment>-github-actions-deploy)
# --------------------------------------------------------------------------
# Originally created out-of-band (bootstrap chicken-and-egg: something has
# to create the first OIDC-trusted role before GitHub Actions can assume
# anything itself). Brought fully under Terraform - via `terraform import`
# of the existing UAT role, matching its live config exactly below - so a
# fresh environment (prod) doesn't need this hand-created again. See
# catalina-aws-deploy/README.md's "GitHub OIDC" section for the OIDC/sub
# claim background.
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_deploy_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Numeric org/repo IDs, not org/repo names: this org is on GitHub
    # Enterprise, whose sub claim uses the ID form regardless of what the
    # AWS console's OIDC wizard assumes. Both IDs belong to
    # tepapaatawhai/catalina-aws-deploy specifically (the repo that runs
    # this Terraform for every environment) - only the environment suffix
    # varies per environment.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:tepapaatawhai@144412126/catalina-aws-deploy@1354178491:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${module.common.name}-github-actions-deploy"
  description        = "OIDC role assumed by GitHub Actions (tepapaatawhai/catalina-aws-deploy) to deploy Catalina ${upper(var.environment)} infrastructure via Terraform"
  assume_role_policy = data.aws_iam_policy_document.github_actions_deploy_assume_role.json
  tags               = module.common.common_tags
}

data "aws_iam_policy_document" "github_actions_deploy_secrets_access" {
  statement {
    actions   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:GetResourcePolicy"]
    resources = [module.rds.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy_secrets_access" {
  name   = "${module.common.name}-github-actions-deploy-secrets-access"
  role   = aws_iam_role.github_actions_deploy.name
  policy = data.aws_iam_policy_document.github_actions_deploy_secrets_access.json
}

# Pre-existing custom inline policies, adopted as-is via import - not
# tightened here, that's a separate exercise from making this reproducible.
resource "aws_iam_role_policy" "github_actions_deploy_eks_full_access" {
  name = "eks-full-access"
  role = aws_iam_role.github_actions_deploy.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "eks:*", Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_deploy_kms_full_access" {
  name = "kms-full-access"
  role = aws_iam_role.github_actions_deploy.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "kms:*", Resource = "*" }
    ]
  })
}

locals {
  github_actions_deploy_managed_policy_arns = toset([
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  ])
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  for_each   = local.github_actions_deploy_managed_policy_arns
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = each.value
}

# --------------------------------------------------------------------------
# ECR - GHCR -> ECR migration for catalina-arches / catalina-starches images.
# Names are fixed (not environment-prefixed): they're baked directly into
# the catalina-build workflows (IMAGE_NAME/matrix.image) and into Flux's
# image-repository refs in catalina-fluxcd, both of which need to agree with
# whatever's created here.
# --------------------------------------------------------------------------
module "ecr_catalina_arches" {
  source = "./modules/ecr"
  name   = "catalina-arches"

  common_tags = module.common.common_tags
}

module "ecr_catalina_arches_static" {
  source = "./modules/ecr"
  name   = "catalina-arches_static"

  common_tags = module.common.common_tags
}

module "ecr_catalina_arches_static_py" {
  source = "./modules/ecr"
  name   = "catalina-arches_static_py"

  common_tags = module.common.common_tags
}

module "ecr_catalina_starches" {
  source = "./modules/ecr"
  name   = "catalina-starches"

  common_tags = module.common.common_tags
}

module "ecr_catalina_starches_private" {
  source = "./modules/ecr"
  name   = "catalina-starches-private"

  common_tags = module.common.common_tags
}

# --------------------------------------------------------------------------
# catalina-build push role - GitHub OIDC role assumed by catalina-build's
# Actions runs to push arches/starches images to the 5 ECR repos above.
# Trust subject and scoping given directly by DOC (2026-09-17): scoped to
# the main branch only (this workflow has no GitHub Environment, unlike
# github_actions_deploy above), using the numeric org/repo ID form since
# that's what this org's OIDC provider actually issues - see
# github_actions_deploy_assume_role above for the same pattern and the
# background on why it's IDs, not names.
# --------------------------------------------------------------------------
data "aws_iam_policy_document" "catalina_build_ecr_push_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:tepapaatawhai@144412126/catalina-build@1353062778:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "catalina_build_ecr_push" {
  name               = "${module.common.name}-catalina-build-ecr-push"
  description        = "OIDC role assumed by GitHub Actions (tepapaatawhai/catalina-build, main branch only) to push catalina-arches/catalina-starches images to ECR"
  assume_role_policy = data.aws_iam_policy_document.catalina_build_ecr_push_assume_role.json
  tags               = module.common.common_tags
}

data "aws_iam_policy_document" "catalina_build_ecr_push_access" {
  # GetAuthorizationToken is not resource-scoped - ECR requires "*" here
  # regardless of which repos the token ends up being used against.
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
    ]
    resources = [
      module.ecr_catalina_arches.repository_arn,
      module.ecr_catalina_arches_static.repository_arn,
      module.ecr_catalina_arches_static_py.repository_arn,
      module.ecr_catalina_starches.repository_arn,
      module.ecr_catalina_starches_private.repository_arn,
    ]
  }
}

resource "aws_iam_role_policy" "catalina_build_ecr_push" {
  name   = "${module.common.name}-catalina-build-ecr-push-access"
  role   = aws_iam_role.catalina_build_ecr_push.name
  policy = data.aws_iam_policy_document.catalina_build_ecr_push_access.json
}

# --------------------------------------------------------------------------
# Flux image-reflector-controller ECR read - DOC's note: "The EKS node role
# already has ECR read access" covers kubelet pulls, but Flux's
# ImageRepository polling (used to auto-detect new tags for
# srv-catalina-arches/config.yaml and srv-starches/starches-dv-deployment.yaml)
# is a separate API call made by the image-reflector-controller pod itself,
# which doesn't inherit the node role. IRSA'd to that controller's own
# ServiceAccount (flux-system/image-reflector-controller) so only it gets
# this, not every pod on the node. Scoped read-only to the two repos Flux
# actually watches today (catalina-arches_static_py, catalina-starches-private)
# - extend if a third ImageRepository is added later.
# --------------------------------------------------------------------------
data "aws_iam_policy_document" "flux_image_reflector_assume_role" {
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
      values   = ["system:serviceaccount:flux-system:image-reflector-controller"]
    }
  }
}

resource "aws_iam_role" "flux_image_reflector" {
  name               = "${module.common.name}-flux-image-reflector"
  description        = "IRSA role for Flux's image-reflector-controller to poll ECR tags (spec.provider: aws on the ImageRepository resources)"
  assume_role_policy = data.aws_iam_policy_document.flux_image_reflector_assume_role.json
  tags               = module.common.common_tags
}

data "aws_iam_policy_document" "flux_image_reflector_access" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      module.ecr_catalina_arches_static_py.repository_arn,
      module.ecr_catalina_starches_private.repository_arn,
    ]
  }
}

resource "aws_iam_role_policy" "flux_image_reflector" {
  name   = "${module.common.name}-flux-image-reflector-access"
  role   = aws_iam_role.flux_image_reflector.name
  policy = data.aws_iam_policy_document.flux_image_reflector_access.json
}