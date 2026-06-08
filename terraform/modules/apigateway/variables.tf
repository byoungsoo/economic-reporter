variable "project_code" {
  type = string
}

variable "aws_region_code" {
  type = string
}

variable "lambda_invoke_arn" {
  description = "Trigger Lambda invoke ARN (dev 계정)"
  type        = string
}

variable "authorizer_invoke_arn" {
  description = "Authorizer Lambda invoke ARN (shared 계정)"
  type        = string
}

variable "authorizer_lambda_arn" {
  description = "Authorizer Lambda ARN (IAM Policy용)"
  type        = string
}
