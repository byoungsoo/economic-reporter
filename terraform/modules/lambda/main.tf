locals {
  name_prefix = "${var.project_code}-${var.account}-${var.aws_region_code}"
}

################################################################################
# IAM
################################################################################
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "AWSEconomicReporterLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_secretsmanager_secret" "economic_reporter" {
  name = "economic-reporter"
}

resource "aws_iam_role_policy" "secrets" {
  name = "AllowGetSlackSigningSecret"
  role = aws_iam_role.this.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "secretsmanager:GetSecretValue"
      Effect   = "Allow"
      Resource = data.aws_secretsmanager_secret.economic_reporter.arn
    }]
  })
}

resource "aws_iam_role_policy" "agentcore" {
  name = "AllowInvokeAgentCore"
  role = aws_iam_role.this.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "bedrock-agentcore:InvokeAgentRuntime"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = aws_lambda_function.worker.arn
      }
    ]
  })
}

################################################################################
# Trigger Lambda
################################################################################
data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/../../../trigger/slack_handler.py"
  output_path = "${path.module}/slack_handler.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "${local.name_prefix}-lambda-economic-reporter-slack-trigger"
  role             = aws_iam_role.this.arn
  handler          = "slack_handler.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  environment {
    variables = {
      SLACK_SIGNING_SECRET     = var.slack_signing_secret
      SLACK_SIGNING_SECRET_ARN = data.aws_secretsmanager_secret.economic_reporter.arn
      WORKER_LAMBDA_ARN        = aws_lambda_function.worker.arn
    }
  }
}

################################################################################
# Lambda Layer - requests
################################################################################
module "layer" {
  source      = "../lambda-layer"
  name_prefix = local.name_prefix
}

################################################################################
# Worker Lambda - AgentCore invoke (3~4분 실행)
################################################################################
data "archive_file" "worker" {
  type        = "zip"
  source_file = "${path.module}/../../../trigger/agentcore_worker.py"
  output_path = "${path.module}/agentcore_worker.zip"
}

resource "aws_lambda_function_event_invoke_config" "worker" {
  function_name          = aws_lambda_function.worker.function_name
  maximum_retry_attempts = 0
}

resource "aws_lambda_function_event_invoke_config" "trigger" {
  function_name          = aws_lambda_function.this.function_name
  maximum_retry_attempts = 0
}

resource "aws_lambda_function" "worker" {
  function_name                  = "${local.name_prefix}-lambda-economic-reporter-agentcore-worker"
  role                           = aws_iam_role.this.arn
  handler                        = "agentcore_worker.handler"
  runtime                        = "python3.11"
  filename                       = data.archive_file.worker.output_path
  source_code_hash               = data.archive_file.worker.output_base64sha256
  timeout                        = 600
  layers                         = [module.layer.layer_arn]
  reserved_concurrent_executions = 1

  environment {
    variables = {
      AGENTCORE_AGENT_ARN = var.agentcore_agent_arn
      SLACK_WEBHOOK_URL   = var.slack_webhook_url
    }
  }
}

################################################################################
# Lambda Permission - shared 계정 API GW cross-account invoke 허용
################################################################################
resource "aws_lambda_permission" "allow_shared_apigw" {
  statement_id  = "AllowCrossAccountAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.shared_account_id}:*/*/*"
}
