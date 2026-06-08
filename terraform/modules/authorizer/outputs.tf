output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "signing_secret_arn" {
  value = aws_secretsmanager_secret.slack.arn
}
