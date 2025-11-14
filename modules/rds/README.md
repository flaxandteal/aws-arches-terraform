<!-- BEGIN_TF_DOCS -->


## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_rds_aurora"></a> [rds\_aurora](#module\_rds\_aurora) | terraform-aws-modules/rds-aurora/aws | ~> 8.0 |
| <a name="module_rds_standard"></a> [rds\_standard](#module\_rds\_standard) | terraform-aws-modules/rds/aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_db_subnet_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_secretsmanager_secret.db_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.db_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [random_password.db](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | n/a | `map(string)` | `{}` | no |
| <a name="input_db_backup_retention"></a> [db\_backup\_retention](#input\_db\_backup\_retention) | Backup retention in days | `number` | `1` | no |
| <a name="input_db_class"></a> [db\_class](#input\_db\_class) | RDS instance class (use 'db.serverless' for Aurora Serverless) | `string` | `"db.t3.micro"` | no |
| <a name="input_db_multi_az"></a> [db\_multi\_az](#input\_db\_multi\_az) | Enable Multi-AZ (standard RDS only) | `bool` | `false` | no |
| <a name="input_db_storage"></a> [db\_storage](#input\_db\_storage) | Allocated storage in GB (standard RDS only) | `number` | `20` | no |
| <a name="input_eks_sg_id"></a> [eks\_sg\_id](#input\_eks\_sg\_id) | EKS node security group ID | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment (dev/stage/prod) - used for apply\_immediately | `string` | `"dev"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key ARN for Secrets Manager (optional) | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | Cluster/environment name prefix | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private subnet IDs (at least 2 AZs) | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_db_endpoint"></a> [db\_endpoint](#output\_db\_endpoint) | RDS endpoint (host:port) |
| <a name="output_db_secret_arn"></a> [db\_secret\_arn](#output\_db\_secret\_arn) | Secrets Manager secret ARN |
| <a name="output_db_security_group_id"></a> [db\_security\_group\_id](#output\_db\_security\_group\_id) | Security group ID for RDS |
<!-- END_TF_DOCS -->