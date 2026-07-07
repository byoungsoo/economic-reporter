variable "trigger_lambda_invoke_arn" {
  description = "Trigger Lambda의 Invoke ARN"
  type        = string
}

variable "trigger_lambda_function_name" {
  description = "Trigger Lambda 함수명 (Permission 설정용)"
  type        = string
}
