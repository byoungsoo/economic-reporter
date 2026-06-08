data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "bys-shared-ap2-s3-terraform"
    key    = var.dev_tfstate_key
    region = "ap-northeast-2"
  }
}

module "authorizer" {
  source          = "../../modules/authorizer"
  project_code    = var.project_code
  aws_region_code = var.aws_region_code
  dev_account_id  = var.dev_account_id
}

module "apigateway" {
  source                = "../../modules/apigateway"
  project_code          = var.project_code
  aws_region_code       = var.aws_region_code
  lambda_invoke_arn     = data.terraform_remote_state.dev.outputs.lambda_invoke_arn
  authorizer_invoke_arn = module.authorizer.invoke_arn
  authorizer_lambda_arn = module.authorizer.function_arn
}
