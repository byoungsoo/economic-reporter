################################################################################
# EventBridge
################################################################################
variable "schedule" {
  description = "EventBridge 스케줄 표현식 (UTC 기준, 예: 매일 KST 06:00 = UTC 21:00 전날)"
  type        = string
  default     = "cron(0 21 * * ? *)"
}

################################################################################
# Cross-account
################################################################################
variable "shared_account_id" {
  description = "shared 계정 ID (cross-account API GW Lambda Permission용)"
  type        = string
}

variable "slack_signing_secret" {
  description = "Slack Signing Secret 값"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL (에러 알림용)"
  type        = string
  sensitive   = true
}
