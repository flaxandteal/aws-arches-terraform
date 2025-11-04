locals {
  tags          = {}
  is_serverless = var.db_class == "db.serverless"
  apply_now     = var.environment == "prod" ? false : true
}

# ------------------------------------------------------------------
# Secrets Manager – FORCE DELETE + NO RECOVERY
# ------------------------------------------------------------------
resource "random_password" "db" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.name}/rds-credentials"
  kms_key_id  = var.kms_key_arn != "" ? var.kms_key_arn : null
  description = "RDS credentials for ${var.name}"

  recovery_window_in_days        = 0 # IMMEDIATE DELETION
  force_overwrite_replica_secret = true

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-rds-secret" }
  )

  lifecycle {
    ignore_changes = [name] # Prevent re‑creation if name changes
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "postgres" # FIXED
    password = random_password.db.result
    engine   = local.is_serverless ? "aurora-postgresql" : "postgres"
    host     = local.is_serverless ? module.rds_aurora[0].cluster_endpoint : module.rds_standard[0].db_instance_endpoint
    port     = 5432
    dbname   = "appdb"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-rds-subnet-group" }
  )
}

# ------------------------------------------------------------------
# Security Group
# ------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name   = "${var.name}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-rds-sg" }
  )
}

# ------------------------------------------------------------------
# Aurora Serverless
# ------------------------------------------------------------------
module "rds_aurora" {
  count   = local.is_serverless ? 1 : 0
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 8.0"

  name           = "${var.name}-aurora"
  engine         = "aurora-postgresql"
  engine_version = "14.6"
  engine_mode    = "provisioned"

  instances = { one = {} }

  serverlessv2_scaling_configuration = {
    min_capacity = 0.5
    max_capacity = 4.0
  }

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  create_db_subnet_group = false

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null

  database_name               = "appdb"
  master_username             = "postgres" # FIXED: not "admin"
  manage_master_user_password = false
  master_password             = random_password.db.result

  backup_retention_period = 1
  apply_immediately       = local.apply_now
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-aurora" }
  )
}

# ------------------------------------------------------------------
# Standard RDS – FIXED: username = "postgres"
# ------------------------------------------------------------------
module "rds_standard" {
  count   = local.is_serverless ? 0 : 1
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.name}-postgres"

  engine         = "postgres"
  engine_version = "16"
  family         = "postgres16"
  instance_class = var.db_class

  allocated_storage     = var.db_storage
  max_allocated_storage = var.db_storage * 2
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn != "" ? var.kms_key_arn : null

  db_name  = "appdb"
  username = "postgres" # FIXED: not "admin"
  password = random_password.db.result
  port     = 5432

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  create_db_subnet_group = false

  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = local.apply_now

  parameters = [
    {
      name         = "rds.logical_replication"
      value        = "1"
      apply_method = "pending-reboot"
    }
  ]

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-postgres" }
  )
}