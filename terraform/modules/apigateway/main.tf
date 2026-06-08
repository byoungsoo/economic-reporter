locals {
  name_prefix = "${var.project_code}-shared-${var.aws_region_code}"
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${local.name_prefix}-apigw-economic-reporter"
}

resource "aws_iam_role" "apigw_authorizer" {
  name = "AWSEconomicReporterAPIGWAuthorizerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "apigw_invoke_authorizer" {
  name = "AllowInvokeAuthorizerLambda"
  role = aws_iam_role.apigw_authorizer.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Effect   = "Allow"
      Resource = var.authorizer_lambda_arn
    }]
  })
}

resource "aws_api_gateway_authorizer" "slack" {
  name                             = "slack-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  authorizer_uri                   = var.authorizer_invoke_arn
  authorizer_credentials           = aws_iam_role.apigw_authorizer.arn
  type                             = "REQUEST"
  identity_source                  = "method.request.header.X-Slack-Signature, method.request.header.X-Slack-Request-Timestamp"
  authorizer_result_ttl_in_seconds = 0
}

resource "aws_api_gateway_resource" "slack" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "slack"
}

resource "aws_api_gateway_method" "slack_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.slack.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.slack.id
}

resource "aws_api_gateway_integration" "slack" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.slack.id
  http_method             = aws_api_gateway_method.slack_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.slack.id,
      aws_api_gateway_method.slack_post.id,
      aws_api_gateway_integration.slack.id,
      aws_api_gateway_authorizer.slack.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "dev"
}
