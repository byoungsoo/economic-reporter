module "lambda" {
  source               = "../../modules/lambda"
  project_code         = var.project_code
  account              = var.account
  aws_region           = var.aws_region
  aws_region_code      = var.aws_region_code
  shared_account_id    = var.shared_account_id
  slack_signing_secret = var.slack_signing_secret
  slack_webhook_url    = var.slack_webhook_url
}

module "eventbridge" {
  source          = "../../modules/eventbridge"
  project_code    = var.project_code
  account         = var.account
  aws_region_code = var.aws_region_code
  schedule        = var.schedule
  lambda_arn      = module.lambda.worker_function_arn
}
