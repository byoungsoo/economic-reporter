output "trigger_function_name" {
  description = "Trigger Lambda 함수명"
  value       = aws_lambda_function.trigger.function_name
}

output "trigger_function_arn" {
  description = "Trigger Lambda ARN"
  value       = aws_lambda_function.trigger.arn
}

output "trigger_invoke_arn" {
  description = "Trigger Lambda Invoke ARN (API Gateway에서 참조)"
  value       = aws_lambda_function.trigger.invoke_arn
}

output "worker_function_name" {
  description = "Worker Lambda 함수명"
  value       = aws_lambda_function.worker.function_name
}

output "worker_function_arn" {
  description = "Worker Lambda ARN (EventBridge에서 참조)"
  value       = aws_lambda_function.worker.arn
}

output "function_url" {
  description = "Slack Slash Command에 등록할 API Gateway URL (apigateway 컴포넌트 apply 후 확인)"
  value       = "apigateway 컴포넌트의 output 참조"
}
