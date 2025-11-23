# modules/rds/main.tf

# data "aws_ec2_managed_prefix_list" "s3" {
#   name = "com.amazonaws.${var.region}.s3"
# }

# data "aws_ec2_managed_prefix_list" "kms" {
#   name = "com.amazonaws.${var.region}.kms"
# }

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

  multi_az            = var.db_multi_az
  publicly_accessible = false

  create_db_subnet_group = true
  db_subnet_group_name   = "${var.name_prefix}-${var.environment}-db-subnet-group"

  vpc_security_group_ids = [aws_security_group.rds.id]
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
  description = "PostgreSQL from EKS nodes" #Security groups must include a description for auditing purposes.

  # --------------------------------------------------
  # INGRESS: Only EKS worker nodes PostgreSQL
  # --------------------------------------------------
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
  # --------------------------------------------------
  # EGRESS: Only what RDS actually needs (no internet!)
  # --------------------------------------------------
# ------------------------------------------------------------------
# EGRESS – fully private, works in every region (no prefix-list drift)
# ------------------------------------------------------------------

# # 1. HTTPS to ALL interface VPC endpoints (KMS, Secrets Manager, SSM, etc.)
#   egress {
#     description              = "RDS → all interface VPC endpoints (KMS, Secrets Manager, SSM, etc.)"
#     from_port                = 443
#     to_port                  = 443
#     protocol                 = "tcp"
#     source_security_group_id = var.vpc_endpoints_security_group_id   # passed from root
#   }

#   # 2. HTTPS to S3 gateway endpoint (backups, extensions, pg_dump, etc.)
#   egress {
#     description     = "RDS → S3 (backups, extensions)"
#     from_port       = 443
#     to_port         = 443
#     protocol        = "tcp"
#     prefix_list_ids = [data.aws_ec2_managed_prefix_list.s3.id]   # S3 is always available
#   }

#   # 3. Return traffic on ephemeral ports (stateful – safe)
#   egress {
#     description = "Ephemeral return traffic"
#     from_port   = 1024
#     to_port     = 65535
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]   # required for return traffic; SGs are stateful
  #}

  # # HTTPS to S3 VPC endpoint (automated backups, pg_dump to S3, extensions)
  # egress {
  #   description     = "RDS S3 (backups, extensions)"
  #   from_port       = 443
  #   to_port         = 443
  #   protocol        = "tcp"
  #   prefix_list_ids = [data.aws_ec2_managed_prefix_list.s3.id]
  # }

  # # HTTPS to KMS VPC endpoint (EBS/RDS encryption)
  # egress {
  #   description     = "RDS KMS (encryption)"
  #   from_port       = 443
  #   to_port         = 443
  #   protocol        = "tcp"
  #   prefix_list_ids = [data.aws_ec2_managed_prefix_list.kms.id]
  # }

  # # Return traffic on ephemeral ports
  # egress {
  #   description = "Return traffic from AWS services only"
  #   from_port   = 1024
  #   to_port     = 65535
  #   protocol    = "tcp"
  #   prefix_list_ids = [
  #     data.aws_ec2_managed_prefix_list.s3.id,
  #     data.aws_ec2_managed_prefix_list.kms.id,
  #   ]
  #}

#   tags = merge(var.tags, {
#     Name = "${var.name_prefix}-${var.environment}-rds-sg"
#   })

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# ——————————————————————————————————————————————————————————————————
# EGRESS RULES – separate resources
# ——————————————————————————————————————————————————————————————————
resource "aws_security_group_rule" "rds_egress_to_vpc_endpoints" {
  description              = "RDS → all interface VPC endpoints (KMS, Secrets Manager, SSM, etc.)"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.vpc_endpoints_security_group_id   # from root
}

resource "aws_security_group_rule" "rds_egress_to_s3" {
  description       = "RDS → S3 gateway endpoint (backups, extensions)"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.s3.id]
}

resource "aws_security_group_rule" "rds_egress_ephemeral" {
  description       = "Return traffic (stateful)"
  type              = "egress"
  from_port         = 1024
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
}