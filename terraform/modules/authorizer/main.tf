locals {
  name_prefix = "${var.project_code}-shared-${var.aws_region_code}"
}

################################################################################
# Secrets Manager - Slack Signing Secret
################################################################################
resource "aws_secretsmanager_secret" "slack" {
  name                    = "economic-reporter/slack-signing-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_policy" "slack" {
  secret_arn = aws_secretsmanager_secret.slack.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowDevAccountLambda"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.dev_account_id}:root"
      }
      Action   = "secretsmanager:GetSecretValue"
      Resource = "*"
    }]
  })
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
  name               = "AWSEconomicReporterLambdaAuthorizerRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.slack.arn]
  }
}

resource "aws_iam_role_policy" "secrets" {
  name   = "AllowGetSlackSigningSecret"
  role   = aws_iam_role.this.name
  policy = data.aws_iam_policy_document.secrets.json
}

################################################################################
# Authorizer Lambda
################################################################################
data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/../../../trigger/slack_authorizer.py"
  output_path = "${path.module}/slack_authorizer.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "${local.name_prefix}-lambda-economic-reporter-slack-authorizer"
  role             = aws_iam_role.this.arn
  handler          = "slack_authorizer.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  environment {
    variables = {
      SLACK_SIGNING_SECRET_ARN = aws_secretsmanager_secret.slack.arn
    }
  }
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
}
