# modules/vpc/main.tf

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = [for i in range(3) : cidrsubnet(var.cidr, 8, i)]
  public_subnets  = [for i in range(3, 6) : cidrsubnet(var.cidr, 8, i + 10)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = merge(
    {
      "Name"                              = var.name
      "kubernetes.io/cluster/${var.name}" = "shared"
      "Environment"                       = var.name
    },
    var.tags
  )

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  enable_dns_hostnames = true # ← private hosted zone
  enable_dns_support   = true # ← Route 53 resolution
}

# root/main.tf – add this after module "vpc" { ... }

# ================================================
# VPC Flow Logs → S3 (standalone, cheap, compliant)
# ================================================
resource "aws_flow_log" "vpc" {
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn # auto-created below
  log_destination      = module.s3_logging_bucket.bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL" # change to "REJECT" later to save ~60 % cost
  vpc_id               = module.vpc.vpc_id

  destination_options {
    file_format        = "parquet" # saves ~70 % storage cost
    per_hour_partition = true      # easier Athena queries
  }

  tags = module.labels.tags
}

# IAM role for VPC Flow Logs delivery to S3 (minimal policy)
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "${var.name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = module.labels.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "vpc-flow-logs-s3-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = "${module.s3_logging_bucket.bucket_arn}/vpc-flow-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}