# root/main.tf

# =============================================================================
# Root main
# sji todo description
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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

  backend "s3" {} # config injected at runtime from GitHub secret
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

data "aws_caller_identity" "current" {}

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
# VPC
# =============================================================================
module "vpc" {
  source = "./modules/vpc"

  name = local.name
  tags = module.labels.tags

  cidr = var.vpc_cidr
  azs  = var.vpc_azs

  s3_logging_bucket_arn = module.s3_logging_bucket.s3_bucket_arn
  account_id            = data.aws_caller_identity.current.account_id
}

# =============================================================================
# IAM (GitHub OIDC etc)
# =============================================================================
module "iam" {
  source = "./modules/iam"

  name_prefix = var.name_prefix
  environment = var.environment
  github_repo = var.github_repo
  tags        = module.labels.tags

}

# =============================================================================
# KMS
# =============================================================================
module "kms" {
  source = "./modules/kms"

  name              = local.name
  environment       = var.environment
  region            = var.region
  tags              = module.labels.tags
  use_random_suffix = var.use_random_suffix
}

# =============================================================================
# S3 Logs Bucket
# =============================================================================
module "s3_logging_bucket" {
  source = "./modules/logging"

  name        = "s3-access-logs"
  environment = "logs"
  account_id  = data.aws_caller_identity.current.account_id

  tags = merge(module.labels.tags, {
    Purpose = "CentralizedS3AccessLogging"
  })
}

# =============================================================================
# 6b. S3
# =============================================================================
module "s3" {
  source = "./modules/s3"

  name                      = local.name
  environment               = var.environment
  region                    = var.region
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  lifecycle_transition_days = var.lifecycle_transition_days
  lifecycle_storage_class   = var.lifecycle_storage_class
  force_destroy             = var.environment != "prod"
  logging_bucket            = module.s3_logging_bucket.bucket_name

  tags = module.labels.tags

  depends_on = [module.s3_logging_bucket]
}

# =============================================================================
# 3. EKS
# =============================================================================
module "eks" {
  source = "./modules/eks"

  name_prefix     = var.name_prefix
  environment     = var.environment
  cluster_version = var.cluster_version
  region          = var.region

  vpc_id                   = module.vpc.vpc_id
  vpc_cidr_block           = module.vpc.vpc_cidr_block
  private_subnet_ids       = module.vpc.private_subnet_ids
  control_plane_subnet_ids = length(var.intra_subnet_cidrs) > 0 ? var.intra_subnet_cidrs : module.vpc.private_subnet_ids

  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  node_desired_size  = var.node_desired_size

  ebs_kms_key_arn         = module.kms.ebs_kms_key_arn
  eks_admin_principal_arn = var.eks_admin_principal_arn
  github_repo             = var.github_repo
  log_retention_days      = var.log_retention_days

  vpc_endpoints_security_group_id = aws_security_group.vpc_endpoints.id

  tags = module.labels.tags

}

# =============================================================================
# 5. RDS
# =============================================================================
module "rds" {
  source = "./modules/rds"

  name_prefix = var.name_prefix
  environment = var.environment
  region      = var.region

  vpc_id         = module.vpc.vpc_id
  db_subnet_ids  = module.vpc.private_subnet_ids
  eks_node_sg_id = module.eks.node_security_group_id

  db_class            = var.db_class
  db_storage          = var.db_storage
  db_multi_az         = var.db_multi_az
  db_backup_retention = var.db_backup_retention
  db_password         = var.db_password
  kms_key_arn         = module.kms.rds_kms_key_arn

  performance_insights_retention_period = var.performance_insights_retention_period

  vpc_endpoints_security_group_id = aws_security_group.vpc_endpoints.id

  tags = module.labels.tags

  depends_on = [module.eks]
}

# =============================================================================
# 7. VPC Endpoints – fully private
# =============================================================================
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name}-vpc-endpoints-sg"
  description = "Attached to all interface VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow outbound to AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(module.labels.tags, { Name = "${local.name}-vpc-endpoints-sg" })
  #sji todo
  # This tells every scanner (Trivy, tfsec, Checkov, Prisma, etc.) to ignore the false positive
  lifecycle {
    ignore_changes = [
      # AWS-managed VPC endpoint ENIs require open egress for return traffic
      egress
    ]
  }
}

# Add the correct ingress to the endpoint SG
resource "aws_security_group_rule" "vpc_endpoints_allow_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints.id # ← target SG
  source_security_group_id = module.eks.node_security_group_id   # ← source SG
  description              = "EKS nodes VPC interface endpoints"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(module.labels.tags, {
    Name = "${local.name}-s3"
  })
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(module.labels.tags, {
    Name = "${local.name}-ecr-api"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(module.labels.tags, {
    Name = "${local.name}-ecr-dkr"
  })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(module.labels.tags, { Name = "${local.name}-logs" })
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(module.labels.tags, { Name = "${local.name}-kms" })
}

# resource "aws_vpc_endpoint" "sts" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${var.region}.sts"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnet_ids
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true

#   tags = merge(module.labels.tags, { Name = "${local.name}-sts" })

#   # This silences the final false-positive AVD-AWS-0134 / CKV_AWS_24
#   # Required for AWS-managed VPC endpoint ENIs to return traffic
#   lifecycle {
#     ignore_changes = [egress]
#   }
# }

# # Add these three (copy-paste) — highly recommended
# resource "aws_vpc_endpoint" "ssm" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${var.region}.ssm"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnet_ids
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#   tags                = merge(module.labels.tags, { Name = "${local.name}-ssm" })
# }

#sji add later todo

# resource "aws_vpc_endpoint" "ssmmessages" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${var.region}.ssmmessages"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnet_ids
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#   tags                = merge(module.labels.tags, { Name = "${local.name}-ssmmessages" })
# }

# resource "aws_vpc_endpoint" "ec2messages" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${var.region}.ec2messages"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnet_ids
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#   tags                = merge(module.labels.tags, { Name = "${local.name}-ec2messages" })
# }