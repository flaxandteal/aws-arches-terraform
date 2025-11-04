bucket         = "catalina-terraform-state"
key            = "dev/terraform.tfstate"
region         = "eu-north-1"
dynamodb_table = "terraform-locks"
encrypt        = true