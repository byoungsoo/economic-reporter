# Project Configuration
project_code    = "bys"
account         = "shared"
aws_region      = "ap-northeast-2"
aws_region_code = "ap2"

# Common Tags
common_tags = {
  auto-delete = "no"
  Terraform   = "true"
  Environment = "shared"
  Project     = "economic-reporter"
}

# Remote State
dev_tfstate_key = "aws-dev-ap2/economic-reporter/terraform.tfstate"
dev_account_id  = "558846430793"
