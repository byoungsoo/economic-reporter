# Project Configuration
project_code    = "bys"
account         = "dev"
aws_region      = "ap-northeast-2"
aws_region_code = "ap2"

# Common Tags
common_tags = {
  auto-delete = "no"
  Terraform   = "true"
  Environment = "dev"
  Project     = "economic-reporter"
}

# Cross-account
shared_account_id = "202949997891"

# EventBridge - KST 06:00 = UTC 21:00 (전날)
schedule = "cron(0 21 * * ? *)"
