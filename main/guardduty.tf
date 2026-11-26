# --------------------------------------------------------------------------
# GuardDuty (pentest finding: GuardDuty not enabled)
# --------------------------------------------------------------------------
# Covers var.region only, by design: this project runs in a single region
# (ap-southeast-6) and nothing is deployed elsewhere, so detectors in unused
# regions would only add cost and noise.
resource "aws_guardduty_detector" "this" {
  enable = true

  # Findings go to EventBridge every 15 minutes instead of the 6 hour default.
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = module.common.common_tags
}

# Optional protection plans. Each is billed separately, see GuardDuty pricing.
locals {
  guardduty_features = [
    "S3_DATA_EVENTS",
    "EKS_AUDIT_LOGS",
    "EBS_MALWARE_PROTECTION",
    "RDS_LOGIN_EVENTS",
  ]
}

resource "aws_guardduty_detector_feature" "this" {
  for_each = toset(local.guardduty_features)

  detector_id = aws_guardduty_detector.this.id
  name        = each.value
  status      = "ENABLED"
}

# --------------------------------------------------------------------------
# Alerting: GuardDuty finding -> EventBridge -> SNS (KMS encrypted) -> email
# --------------------------------------------------------------------------
# Email subscriptions must be confirmed by each recipient (a confirmation mail
# is sent on apply). For Slack, Teams or a SIEM, subscribe an HTTPS endpoint or
# AWS Chatbot to the topic instead.
data "aws_caller_identity" "guardduty" {}

data "aws_iam_policy_document" "guardduty_alerts_kms" {
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.guardduty.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowEventBridgePublishToEncryptedTopic"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "guardduty_alerts" {
  description             = "${module.common.name} - GuardDuty alert topic encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.guardduty_alerts_kms.json

  tags = merge(module.common.common_tags, { Name = "${module.common.name}-guardduty-alerts-kms" })
}

resource "aws_sns_topic" "guardduty_alerts" {
  name              = "${module.common.name}-guardduty-alerts"
  kms_master_key_id = aws_kms_key.guardduty_alerts.arn

  tags = module.common.common_tags
}

data "aws_iam_policy_document" "guardduty_alerts_topic" {
  statement {
    sid       = "AllowEventBridgePublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.guardduty_alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [
        aws_cloudwatch_event_rule.guardduty_findings.arn,
        aws_cloudwatch_event_rule.securityhub_findings.arn,
      ]
    }
  }
}

resource "aws_sns_topic_policy" "guardduty_alerts" {
  arn    = aws_sns_topic.guardduty_alerts.arn
  policy = data.aws_iam_policy_document.guardduty_alerts_topic.json
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${module.common.name}-guardduty-findings"
  description = "Forward GuardDuty findings at or above the configured severity to SNS"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.guardduty_min_severity] }]
    }
  })

  tags = module.common.common_tags
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule = aws_cloudwatch_event_rule.guardduty_findings.name
  arn  = aws_sns_topic.guardduty_alerts.arn
}

resource "aws_sns_topic_subscription" "guardduty_email" {
  for_each = toset(var.security_alert_emails)

  topic_arn = aws_sns_topic.guardduty_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}
