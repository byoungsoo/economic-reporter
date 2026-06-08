output "lambda_function_name" {
  description = "Slack 트리거 Lambda 함수명"
  value       = module.lambda.function_name
}

output "lambda_invoke_arn" {
  description = "Trigger Lambda invoke ARN (shared API GW에서 remote state로 참조)"
  value       = module.lambda.invoke_arn
}

output "eventbridge_rule_name" {
  description = "EventBridge 스케줄 규칙명"
  value       = module.eventbridge.rule_name
}
