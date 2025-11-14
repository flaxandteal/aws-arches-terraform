# Create/Update AWS Infrastructure
1. cd /main

2. Check that the env bootstrap and tfvars files you are using are correct.

bucket         = "tfstate-dev-034791378213"
key            = "global/terraform.tfstate"
region         = "eu-central-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:eu-central-1:034791378213:key/924ad126-24c3-4d13-a32d-ba858a90b8a9"
dynamodb_table = "tflocks-dev-034791378213"

1. Initialize Locally and test (choose correct backend file):
```
terraform init   -backend-config=dev.backend.tfvars
```

2. Format and Validate Terraform
terraform fmt --recursive
terraform validate
```

If any specific module gets stuck or fails or if you simply wish to remove it:
```
terraform destroy -target module.rds.module.rds_aurora[0]
```

aws sts get-caller-identity

~/.aws/config

# 1. Authenticate
aws configure

# 2. Re-run
aws eks update-kubeconfig \
  --name catalina-eks \
  --region eu-north-1 \
  --alias catalina-eks

# 3. Watch
kubectl get nodes --watch

#Scribbles sji - tidy/remove
Terraform init —backend-config=/env/dev.conf

Terraform apply —var-file=/env/dev.tfvars

# 1. Verify AWS auth
aws sts get-caller-identity

# 2. Update kubeconfig
aws eks update-kubeconfig --name catalina-eks --region eu-north-1 --alias catalina-eks

# 3. Check context
kubectl config current-context

# 4. Get nodes
kubectl get nodes

# 1. Create access entry for your user
aws eks create-access-entry \
  --cluster-name catalina-eks \
  --principal-arn arn:aws:iam::034791378213:user/terraform-deployer \
  --type STANDARD \
  --region eu-north-1

# 2. Grant Cluster Admin
aws eks associate-access-policy \
  --cluster-name catalina-eks \
  --principal-arn arn:aws:iam::034791378213:user/terraform-deployer \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region eu-north-1


#test install app:
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc -w

# Delete 
kubectl delete deployment nginx
kubectl delete service nginx

kubectl get pods,svc | grep nginx

terraform state list

terraform state rm module.vpc


aws secretsmanager delete-secret \
  --secret-id catalina/rds-credentials \
  --force-delete-without-recovery
  
#end scribbles


Run this once from inside modules/secrets/rotation/: 
pip install psycopg2-binary -t python
zip -r ../rotation.zip python lambda_function.py
This ensures all dependencies are included.

The resulting rotation.zip goes in modules/secrets/.

Important!
https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html

***Important Notes***
Use .tfvars files for environment-specific settings (e.g., dev.tfvars for cheaper regions).

#sji todo
If rerunning this secrets may be a problem. You may get this error:
Error: creating Secrets Manager Secret (catalina/rds-credentials): operation error Secrets Manager: CreateSecret, https response error StatusCode: 400, RequestID: 5eef5c99-dd26-41bb-866e-b02004b45660, InvalidRequestException: You can't create this secret because a secret with this name is already scheduled for deletion.

To delete the secret:
aws secretsmanager list-secrets --query 'SecretList[].Name' --region'<your-region>'
# find catalina/rds-credentials

aws secretsmanager delete-secret \
  --secret-id catalina/rds-credentials \
  --force-delete-without-recovery \
  --region'<your-region>'


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | = 6.15.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.19 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_common"></a> [common](#module\_common) | ./modules/common | n/a |
| <a name="module_eks"></a> [eks](#module\_eks) | ./modules/eks | n/a |
| <a name="module_iam"></a> [iam](#module\_iam) | ./modules/iam | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ./modules/kms | n/a |
| <a name="module_rds"></a> [rds](#module\_rds) | ./modules/rds | n/a |
| <a name="module_s3"></a> [s3](#module\_s3) | ./modules/s3 | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/vpc | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | n/a | `string` | n/a | yes |
| <a name="input_clusters"></a> [clusters](#input\_clusters) | n/a | <pre>object({<br/>    instance_type      = string<br/>    desired_size       = number<br/>    min_size           = number<br/>    max_size           = number<br/>    log_retention_days = number<br/>  })</pre> | n/a | yes |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | n/a | `map(string)` | `{}` | no |
| <a name="input_db_backup_retention"></a> [db\_backup\_retention](#input\_db\_backup\_retention) | n/a | `number` | `1` | no |
| <a name="input_db_class"></a> [db\_class](#input\_db\_class) | -------------------------------------------------------------------------- RDS -------------------------------------------------------------------------- | `string` | `"db.t3.micro"` | no |
| <a name="input_db_multi_az"></a> [db\_multi\_az](#input\_db\_multi\_az) | n/a | `bool` | `false` | no |
| <a name="input_db_storage"></a> [db\_storage](#input\_db\_storage) | n/a | `number` | `20` | no |
| <a name="input_eks_admin_principal_arn"></a> [eks\_admin\_principal\_arn](#input\_eks\_admin\_principal\_arn) | -------------------------------------------------------------------------- EKS -------------------------------------------------------------------------- | `string` | n/a | yes |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | n/a | `map(string)` | `{}` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | n/a | `string` | n/a | yes |
| <a name="input_lifecycle_storage_class"></a> [lifecycle\_storage\_class](#input\_lifecycle\_storage\_class) | S3 lifecycle storage class | `string` | n/a | yes |
| <a name="input_lifecycle_transition_days"></a> [lifecycle\_transition\_days](#input\_lifecycle\_transition\_days) | Days before transitioning S3 objects | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | -------------------------------------------------------------------------- Common -------------------------------------------------------------------------- | `string` | n/a | yes |
| <a name="input_vpc_azs"></a> [vpc\_azs](#input\_vpc\_azs) | n/a | `list(string)` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | -------------------------------------------------------------------------- VPC -------------------------------------------------------------------------- | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | n/a |
<!-- END_TF_DOCS -->