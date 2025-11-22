# modules/rds/main.tf

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.10.0"

  identifier = "${var.name_prefix}-${var.environment}-postgres"

  engine               = "postgres"
  engine_version       = "16.11" #18.1 poss? sji todo
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.db_class

  allocated_storage     = var.db_storage
  max_allocated_storage = var.db_storage * 3
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = "arches"
  username = "postgres"
  password = var.db_password != "" ? var.db_password : random_password.master[0].result
  port     = 5432

  multi_az               = var.db_multi_az
  publicly_accessible    = false
  vpc_security_group_ids = [module.eks.node_security_group_id]
  subnet_ids             = var.db_subnet_ids

  backup_retention_period = var.db_backup_retention
  skip_final_snapshot     = var.environment != "prod"

  apply_immediately = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-rds"
  })

  performance_insights_enabled          = true
  performance_insights_retention_period = var.performance_insights_retention_period

  iam_database_authentication_enabled = true

  deletion_protection = var.environment != "dev" ? true : false
}

resource "random_password" "master" {
  count   = var.db_password == "" ? 1 : 0
  length  = 20
  special = false
}

# ------------------------------------------------------------------
# Security Group
# ------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-${var.environment}-rds-sg"
  vpc_id      = var.vpc_id
  description = "PostgreSQL from EKS nodes" #Security groups should include a description for auditing purposes.

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.eks_node_sg_id != "" ? [var.eks_node_sg_id] : []
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-rds-sg"
  })
}