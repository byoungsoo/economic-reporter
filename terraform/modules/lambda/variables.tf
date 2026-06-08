variable "project_code" {
  type = string
}

variable "account" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_region_code" {
  type = string
}

variable "shared_account_id" {
  description = "shared 계정 ID (cross-account API GW Lambda Permission용)"
  type        = string
}

variable "slack_signing_secret" {
  description = "Slack Signing Secret 값 (Lambda 환경변수로 직접 주입)"
  type        = string
  sensitive   = true
}

variable "agentcore_agent_arn" {
  description = "AgentCore Runtime ARN"
  type        = string
  default     = "arn:aws:bedrock-agentcore:ap-northeast-2:558846430793:runtime/economic_reporter-Zx64Bh783b"
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL (에러 알림용)"
  type        = string
  sensitive   = true
}

