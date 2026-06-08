variable "project_code" {
  type = string
}

variable "aws_region_code" {
  type = string
}

variable "dev_account_id" {
  description = "dev 계정 ID (cross-account Secrets Manager 접근 허용)"
  type        = string
}
