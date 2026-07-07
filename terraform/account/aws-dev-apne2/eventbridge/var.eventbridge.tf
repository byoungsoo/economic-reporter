variable "schedule" {
  description = "EventBridge 스케줄 표현식 (UTC 기준)"
  type        = string
  default     = "cron(0 21 * * ? *)"
}

variable "worker_lambda_arn" {
  description = "트리거 대상 Worker Lambda ARN"
  type        = string
}
