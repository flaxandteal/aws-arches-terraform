# --------------------------------------------------------------------------
# In-cluster Postgres backups (pentest finding: no database backups)
# --------------------------------------------------------------------------
# Arches and GeoServer run against the in-cluster Postgres, not RDS, so RDS
# automated backups do not cover them. A CronJob in catalina-fluxcd
# (srv-catalina-arches/cronjob-pg-backup.yaml) runs pg_dumpall and uploads the
# result here. IRSA again, same reasoning as the other buckets (org SCP denies
# iam:CreateUser).
module "s3_pgbackup" {
  source = "./modules/s3"
  name   = "${module.common.name}-pgbackup"

  lifecycle_transition_days = var.lifecycle_transition_days
  enable_lifecycle          = false # replaced by the expiry rule below
  s3_kms_key_arn            = module.kms.s3_kms_key_arn
  deletion_protection       = var.s3_deletion_protection
  common_tags               = module.common.common_tags
}

# Versioning is on in the s3 module, so expire noncurrent versions too or
# deleted dumps would be kept forever.
resource "aws_s3_bucket_lifecycle_configuration" "pgbackup" {
  bucket = module.s3_pgbackup.bucket_name

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = var.pg_backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 2
    }
  }
}

data "aws_iam_policy_document" "pg_backup_assume_role" {
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
      values   = ["system:serviceaccount:srv-catalina-arches:pg-backup"]
    }
  }
}

resource "aws_iam_role" "pg_backup" {
  name               = "${module.common.name}-pg-backup"
  assume_role_policy = data.aws_iam_policy_document.pg_backup_assume_role.json
  tags               = module.common.common_tags
}

# Write-only: the job can add dumps but not read or delete them, so a
# compromised pod cannot exfiltrate or wipe the backups.
data "aws_iam_policy_document" "pg_backup_access" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_pgbackup.bucket_arn}/*"]
  }

  statement {
    actions   = ["kms:GenerateDataKey*"]
    resources = [module.kms.s3_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "pg_backup" {
  name   = "${module.common.name}-pg-backup-access"
  role   = aws_iam_role.pg_backup.name
  policy = data.aws_iam_policy_document.pg_backup_access.json
}

output "s3_pgbackup_bucket_name" {
  value = module.s3_pgbackup.bucket_name
}

output "pg_backup_role_arn" {
  value = aws_iam_role.pg_backup.arn
}
