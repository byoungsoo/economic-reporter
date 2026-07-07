output "rule_name" {
  description = "EventBridge Rule 이름"
  value       = aws_cloudwatch_event_rule.this.name
}

output "rule_arn" {
  description = "EventBridge Rule ARN"
  value       = aws_cloudwatch_event_rule.this.arn
}
