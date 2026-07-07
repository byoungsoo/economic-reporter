################################################################################
# IAM Role
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
  name               = "${local.common_resource_name}-role-economic-reporter-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    { "Name" = "${local.common_resource_name}-role-economic-reporter-lambda" },
    var.common_tags,
  )
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_secretsmanager_secret" "economic_reporter" {
  name = "economic-reporter"
}

resource "aws_iam_role_policy" "permissions" {
  name = "EconomicReporterPermissions"
  role = aws_iam_role.this.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManager"
        Action   = "secretsmanager:GetSecretValue"
        Effect   = "Allow"
        Resource = data.aws_secretsmanager_secret.economic_reporter.arn
      },
      {
        Sid    = "BedrockInvoke"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid      = "SNSPublish"
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = var.sns_topic_arn
      },
      {
        Sid      = "InvokeWorker"
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = aws_lambda_function.worker.arn
      }
    ]
  })
}

################################################################################
# Lambda Layer
################################################################################
resource "aws_lambda_layer_version" "dependencies" {
  layer_name          = "${local.common_resource_name}-layer-economic-reporter-deps"
  filename            = var.layer_zip_path
  source_code_hash    = filebase64sha256(var.layer_zip_path)
  compatible_runtimes = ["python3.11"]
  description         = "strands-agents, requests, python-dotenv for economic-reporter"
}

################################################################################
# Trigger Lambda (Slack 수신 → Worker 비동기 호출)
################################################################################
data "archive_file" "trigger" {
  type        = "zip"
  source_file = "${path.module}/../../../../trigger/slack_handler.py"
  output_path = "${path.module}/.build/slack_handler.zip"
}

resource "aws_lambda_function" "trigger" {
  function_name    = "${local.common_resource_name}-lambda-economic-reporter-trigger"
  role             = aws_iam_role.this.arn
  handler          = "slack_handler.handler"
  runtime          = "python3.11"
  timeout          = 10
  filename         = data.archive_file.trigger.output_path
  source_code_hash = data.archive_file.trigger.output_base64sha256

  environment {
    variables = {
      SLACK_SIGNING_SECRET = var.slack_signing_secret
      WORKER_LAMBDA_ARN    = aws_lambda_function.worker.arn
    }
  }

  tags = merge(
    { "Name" = "${local.common_resource_name}-lambda-economic-reporter-trigger" },
    var.common_tags,
  )
}

resource "aws_lambda_function_event_invoke_config" "trigger" {
  function_name          = aws_lambda_function.trigger.function_name
  maximum_retry_attempts = 0
}

################################################################################
# Worker Lambda (에이전트 직접 실행, 보고서 생성)
################################################################################
data "archive_file" "worker" {
  type        = "zip"
  output_path = "${path.module}/.build/worker.zip"

  source {
    content  = file("${path.module}/../../../../trigger/worker.py")
    filename = "worker.py"
  }

  source {
    content  = file("${path.module}/../../../../agent/__init__.py")
    filename = "agent/__init__.py"
  }

  source {
    content  = file("${path.module}/../../../../agent/main.py")
    filename = "agent/main.py"
  }

  source {
    content  = file("${path.module}/../../../../agent/config.py")
    filename = "agent/config.py"
  }

  source {
    content  = file("${path.module}/../../../../agent/prompts.py")
    filename = "agent/prompts.py"
  }

  source {
    content  = file("${path.module}/../../../../tools/__init__.py")
    filename = "tools/__init__.py"
  }

  source {
    content  = file("${path.module}/../../../../tools/news_fetcher.py")
    filename = "tools/news_fetcher.py"
  }

  source {
    content  = file("${path.module}/../../../../tools/slack_notifier.py")
    filename = "tools/slack_notifier.py"
  }

  source {
    content  = file("${path.module}/../../../../tools/email_sender.py")
    filename = "tools/email_sender.py"
  }
}

resource "aws_lambda_function" "worker" {
  function_name                  = "${local.common_resource_name}-lambda-economic-reporter-worker"
  role                           = aws_iam_role.this.arn
  handler                        = "worker.handler"
  runtime                        = "python3.11"
  timeout                        = 900
  memory_size                    = 512
  filename                       = data.archive_file.worker.output_path
  source_code_hash               = data.archive_file.worker.output_base64sha256
  reserved_concurrent_executions = 1
  layers                         = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      AWS_BEDROCK_MODEL_ID = var.bedrock_model_id
      SLACK_WEBHOOK_URL    = var.slack_webhook_url
    }
  }

  tags = merge(
    { "Name" = "${local.common_resource_name}-lambda-economic-reporter-worker" },
    var.common_tags,
  )
}

resource "aws_lambda_function_event_invoke_config" "worker" {
  function_name          = aws_lambda_function.worker.function_name
  maximum_retry_attempts = 0
}
