output "api_endpoint" {
  description = "API Gateway 엔드포인트"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "slack_url" {
  description = "Slack Slash Command에 등록할 URL"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/slack"
}
