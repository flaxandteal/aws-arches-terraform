resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, var.extra_tags, { Name = "${var.name}-vpc-${terraform.workspace}" })
}

resource "aws_subnet" "public" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}${count.index == 0 ? "a" : "b"}"
  tags                    = merge(var.tags, var.extra_tags, { Name = "${var.name}-public-subnet-${count.index}-${terraform.workspace}" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, var.extra_tags, { Name = "${var.name}-igw-${terraform.workspace}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, var.extra_tags, { Name = "${var.name}-rt-public-${terraform.workspace}" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "main" {
  name        = "${var.name}-sg-${terraform.workspace}"
  description = "Security group for ${terraform.workspace} environment"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

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
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, var.extra_tags, { Name = "${var.name}-sg-${terraform.workspace}" })
}

resource "aws_network_acl" "main" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id
  tags       = merge(var.tags, var.extra_tags, { Name = "${var.name}-nacl-${terraform.workspace}" })
}

resource "aws_network_acl_rule" "ingress_http" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = element(var.nacl_ingress_cidr_blocks, 0)
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ingress_https" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = element(var.nacl_ingress_cidr_blocks, 0)
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "egress_all" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 300
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "ingress_ephemeral" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 400
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = element(var.nacl_ingress_cidr_blocks, 0)
  from_port      = 1024
  to_port        = 65535
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.public.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:PutObject"]
        Resource  = [var.data_bucket_arn, "${var.data_bucket_arn}/*", var.logs_bucket_arn, "${var.logs_bucket_arn}/*", var.tfstate_bucket_arn, "${var.tfstate_bucket_arn}/*"]
      }
    ]
  })
  tags = merge(var.tags, var.extra_tags, { Name = "${var.name}-s3-endpoint-${terraform.workspace}" })
}
