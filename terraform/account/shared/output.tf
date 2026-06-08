output "slack_webhook_url" {
  description = "Slack Event Subscriptions에 등록할 URL"
  value       = module.apigateway.invoke_url
}

output "slack_signing_secret_arn" {
  description = "Slack Signing Secret ARN (dev Lambda에서 cross-account로 참조)"
  value       = module.authorizer.signing_secret_arn
}
