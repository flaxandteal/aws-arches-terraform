locals {
  tags = {}
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = flatten([for az in var.azs : [for i in range(var.subnet_count) : cidrsubnet(var.vpc_cidr, 8, (index(var.azs, az) * var.subnet_count) + i + 1)]])
  public_subnets  = flatten([for az in var.azs : [for i in range(var.subnet_count) : cidrsubnet(var.vpc_cidr, 8, (index(var.azs, az) * var.subnet_count) + i + 101)]])

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat

  tags = merge(var.common_tags, local.tags)
}

resource "aws_network_acl" "private" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  dynamic "ingress" {
    for_each = toset(var.nacl_ingress_cidr_blocks)
    content {
      protocol   = "tcp"
      rule_no    = 100
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0
      to_port    = 65535
    }
  }

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.common_tags, local.tags)
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
  tags              = merge(var.common_tags, local.tags)
}

locals {
  interface_endpoints = ["ecr.dkr", "ecr.api", "logs", "ssm", "ssmmessages", "ec2messages", "secretsmanager", "kms"]
}

resource "aws_vpc_endpoint" "interface" {
  count = length(local.interface_endpoints)

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${local.interface_endpoints[count.index]}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  tags                = merge(var.common_tags, local.tags)
}

resource "aws_security_group" "vpc_endpoint" {
  name   = "${var.name}-vpc-endpoint-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
  tags = merge(var.common_tags, local.tags)
}