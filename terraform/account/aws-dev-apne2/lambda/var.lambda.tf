variable "slack_signing_secret" {
  description = "Slack Signing Secret (Trigger Lambda 환경변수로 주입)"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL (에러 알림 및 보고서 발송)"
  type        = string
  sensitive   = true
}

variable "sns_topic_arn" {
  description = "SNS Topic ARN (이메일 발송용)"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock 모델 ID"
  type        = string
  default     = "global.anthropic.claude-sonnet-4-6"
}

variable "layer_zip_path" {
  description = "Lambda Layer ZIP 파일 경로"
  type        = string
  default     = "layers/python-dependencies-layer.zip"
}
