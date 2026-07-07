variable "project_code" {
  description = "프로젝트 코드"
  type        = string
  default     = "bys"
}

variable "account" {
  description = "계정 식별자"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_region_code" {
  description = "AWS 리전 코드"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    "Terraform"   = "true"
    "auto-delete" = "no"
  }
}

locals {
  common_resource_name = "${var.project_code}-${var.account}-${var.aws_region_code}"
}
