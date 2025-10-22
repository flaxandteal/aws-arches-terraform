locals {
  tags          = {}
  is_serverless = var.db_class == "db.serverless"
}

resource "random_password" "db" {
  length = 16
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name       = "${var.name}/rds-credentials"
  kms_key_id = var.kms_key_arn
  tags       = merge(var.common_tags, local.tags)
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db.result
  })
}

module "rds_aurora" {
  count   = local.is_serverless ? 1 : 0
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 6.0"

  name           = "${var.name}-postgres"
  engine         = "aurora-postgresql"
  engine_version = "13"
  instance_class = var.db_class
  instances      = {}

  vpc_security_group_ids = [aws_security_group.rds.id]
  subnet_ids             = var.subnet_ids
  storage_encrypted      = true
  kms_key_id             = var.kms_key_arn
  deletion_protection    = true

  database_name   = "appdb"
  master_username = "admin"
  master_password = random_password.db.result
  port            = 5432

  enabled_cloudwatch_logs_exports = ["postgresql"]
  backup_retention_period         = var.db_backup_retention
  apply_immediately               = var.name == "aws-prod" ? false : true

  parameters = [
    { name = "rds.logical_replication", value = "1" }
  ]

  tags = merge(var.common_tags, local.tags)
}

module "rds_standard" {
  count   = local.is_serverless ? 0 : 1
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_class

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  storage_encrypted      = true
  kms_key_id             = var.kms_key_arn
  deletion_protection    = true

  db_name  = "appdb"
  username = "admin"
  password = random_password.db.result
  port     = 5432

  enabled_cloudwatch_logs_exports = ["postgresql"]
  backup_retention_period         = var.db_backup_retention
  multi_az                        = var.db_multi_az
  allocated_storage               = var.db_storage

  apply_immediately = var.name == "aws-prod" ? false : true

  parameters = [
    { name = "rds.logical_replication", value = "1" }
  ]

  tags = merge(var.common_tags, local.tags)
}

resource "aws_db_subnet_group" "rds" {
  count      = local.is_serverless ? 0 : 1
  name       = "${var.name}-rds-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = merge(var.common_tags, local.tags)
}

resource "aws_security_group" "rds" {
  name   = "${var.name}-rds-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_sg_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
  tags = merge(var.common_tags, local.tags)
}