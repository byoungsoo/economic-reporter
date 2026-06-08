terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    bucket  = "bys-shared-ap2-s3-terraform"
    key     = "aws-shared-ap2/economic-reporter/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::202949997891:role/SharedTerraformRole"
  }

  default_tags {
    tags = var.common_tags
  }
}

# Resource Naming Rule
# ${var.project_code}-${var.account}-${var.aws_region_code}-resource-{az}-{name}
