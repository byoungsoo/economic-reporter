variable "project_code" {
  type = string
}

variable "account" {
  type = string
}

variable "aws_region_code" {
  type = string
}

variable "schedule" {
  description = "EventBridge 스케줄 표현식 (예: cron(0 21 * * ? *))"
  type        = string
}

variable "lambda_arn" {
  description = "트리거할 Lambda 함수 ARN"
  type        = string
}
