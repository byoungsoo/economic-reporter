################################################################################
# Remote State - dev 계정 참조
################################################################################
variable "dev_tfstate_key" {
  type    = string
  default = "aws-dev-ap2/economic-reporter/terraform.tfstate"
}

variable "dev_account_id" {
  description = "dev 계정 ID (cross-account Secrets Manager 접근 허용)"
  type        = string
}
