terraform {
  backend "s3" {
    bucket  = "bys-shared-apne2-s3-terraform"
    key     = "aws-dev-apne2/economic-reporter/apigateway/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::558846430793:role/DevTerraformRole"
  }

  default_tags {
    tags = var.common_tags
  }
}
