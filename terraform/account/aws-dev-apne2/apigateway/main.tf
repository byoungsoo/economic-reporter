################################################################################
# API Gateway HTTP API (Slack 엔드포인트)
################################################################################
resource "aws_apigatewayv2_api" "this" {
  name          = "${local.common_resource_name}-apigw-economic-reporter"
  protocol_type = "HTTP"

  tags = merge(
    { "Name" = "${local.common_resource_name}-apigw-economic-reporter" },
    var.common_tags,
  )
}

resource "aws_apigatewayv2_integration" "trigger" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.trigger_lambda_invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "slack" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /slack"
  target    = "integrations/${aws_apigatewayv2_integration.trigger.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }

  tags = merge(
    { "Name" = "${local.common_resource_name}-apigw-economic-reporter-default" },
    var.common_tags,
  )
}

################################################################################
# Lambda Permission (API Gateway → Trigger Lambda 호출 허용)
################################################################################
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.trigger_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
