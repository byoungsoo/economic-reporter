locals {
  name_prefix = "${var.project_code}-${var.account}-${var.aws_region_code}"
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = "${local.name_prefix}-evb-economic-reporter-schedule"
  description         = "Economic Reporter 스케줄 트리거"
  schedule_expression = var.schedule
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "SlackTriggerLambda"
  arn       = var.lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
