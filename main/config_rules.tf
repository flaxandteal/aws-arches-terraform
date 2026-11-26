# --------------------------------------------------------------------------
# AWS Config rules: ongoing encryption-at-rest checks (pentest finding AR04)
# --------------------------------------------------------------------------
# These only evaluate resources, they change nothing. They need the AWS Config
# recorder to be running in this account and region, which Control Tower
# normally enables for enrolled accounts. If `terraform apply` reports
# NoAvailableConfigurationRecorder, the recorder is missing here.
locals {
  encryption_config_rules = {
    # Attached EBS volumes must be encrypted.
    encrypted-volumes = "ENCRYPTED_VOLUMES"
    # Account-level EBS default encryption must stay on (see
    # aws_ebs_encryption_by_default in main.tf).
    ebs-encryption-by-default = "EC2_EBS_ENCRYPTION_BY_DEFAULT"
    # RDS instances must have storage encryption.
    rds-storage-encrypted = "RDS_STORAGE_ENCRYPTED"
    # RDS instances must have auto minor version upgrade on (pentest finding:
    # outdated RDS engine).
    rds-auto-minor-upgrade = "RDS_AUTOMATIC_MINOR_VERSION_UPGRADE_ENABLED"
    # SNS topics in this account must use a KMS key.
    sns-encrypted-kms = "SNS_ENCRYPTED_KMS"
  }
}

resource "aws_config_config_rule" "encryption" {
  for_each = local.encryption_config_rules

  name = "${module.common.name}-${each.key}"

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  tags = module.common.common_tags
}
