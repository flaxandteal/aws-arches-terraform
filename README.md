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
<!-- END_TF_DOCS -->