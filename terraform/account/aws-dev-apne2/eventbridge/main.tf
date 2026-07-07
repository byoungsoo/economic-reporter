################################################################################
# EventBridge Rule (스케줄 트리거)
################################################################################
resource "aws_cloudwatch_event_rule" "this" {
  name                = "${local.common_resource_name}-evb-economic-reporter-schedule"
  description         = "Economic Reporter 스케줄 트리거 (매일 KST 06:00)"
  schedule_expression = var.schedule

  tags = merge(
    { "Name" = "${local.common_resource_name}-evb-economic-reporter-schedule" },
    var.common_tags,
  )
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "WorkerLambda"
  arn       = var.worker_lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.worker_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
