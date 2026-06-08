################################################################################
# Default
################################################################################
variable "project_code" {
  type    = string
  default = "bys"
}

variable "account" {
  type    = string
  default = "shared"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_region_code" {
  type    = string
  default = "ap2"
}

################################################################################
# Common Tags
################################################################################
variable "common_tags" {
  type    = map(string)
  default = {}
}
