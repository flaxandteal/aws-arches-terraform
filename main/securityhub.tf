# --------------------------------------------------------------------------
# Security Hub (pentest finding: AWS Security Hub not enabled)
# --------------------------------------------------------------------------
# Single region by design (see guardduty.tf): this project only runs in
# var.region (ap-southeast-6), and Security Hub is regional, so it has to be
# enabled there explicitly.
#
# Needs the AWS Config recorder running in this account and region (controls
# are evaluated through Config). GuardDuty findings flow in automatically once
# both services are on. Billed per security check and per finding ingested.
data "aws_region" "current" {}

resource "aws_securityhub_account" "this" {
  # Standards are chosen explicitly below instead of AWS's defaults.
  enable_default_standards = false
  auto_enable_controls     = true
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.region}::standards/cis-aws-foundations-benchmark/v/3.0.0"

  depends_on = [aws_securityhub_account.this]
}

# --------------------------------------------------------------------------
# Alerting: new HIGH or CRITICAL Security Hub findings -> the same encrypted
# SNS topic as GuardDuty (guardduty.tf). GuardDuty's own findings are excluded
# here because the GuardDuty rule already alerts on them.
# --------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name        = "${module.common.name}-securityhub-findings"
  description = "Forward new HIGH and CRITICAL Security Hub findings (not from GuardDuty) to SNS"

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        ProductName = [{ "anything-but" = "GuardDuty" }]
        Severity    = { Label = ["HIGH", "CRITICAL"] }
        Workflow    = { Status = ["NEW"] }
        RecordState = ["ACTIVE"]
      }
    }
  })

  tags = module.common.common_tags
}

resource "aws_cloudwatch_event_target" "securityhub_to_sns" {
  rule = aws_cloudwatch_event_rule.securityhub_findings.name
  arn  = aws_sns_topic.guardduty_alerts.arn
}

output "securityhub_account_arn" {
  value = aws_securityhub_account.this.arn
}
