resource "aws_iam_user" "network_access" {
  name = "${var.name}-network-access-${terraform.workspace}"
  tags = merge(var.tags, { Name = "${var.name}-network-access-${terraform.workspace}" })
}

resource "aws_iam_policy" "read_network" {
  name        = "${var.name}-read-network-${terraform.workspace}"
  description = "Read-only access to network (least privilege)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeVpcs", "ec2:DescribeSubnets"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "data_bucket_kms" {
  name        = "${var.name}-data-bucket-kms-${terraform.workspace}"
  description = "Access to KMS key and data bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.data_kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.data_bucket_arn,
          "${var.data_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "read_network" {
  user       = aws_iam_user.network_access.name
  policy_arn = aws_iam_policy.read_network.arn
}

resource "aws_iam_user_policy_attachment" "data_bucket_kms" {
  user       = aws_iam_user.network_access.name
  policy_arn = aws_iam_policy.data_bucket_kms.arn
}