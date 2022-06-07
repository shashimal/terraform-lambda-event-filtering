terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#Creating a SQS
resource "aws_sqs_queue" "order" {
  name = "OrderDetails"
}

#Creating the lambda function
resource "aws_lambda_function" "order_processing_lambda" {
  function_name    = "OrderProcessingFunction"
  role             = aws_iam_role.lambda_execution_role.arn
  filename         = "${abspath(path.root)}/lambda/order-processing.zip"
  handler          = "order-processing.handler"
  source_code_hash = filebase64sha256("lambda/order-processing.zip")
  runtime          = "nodejs12.x"
  depends_on = [
    aws_iam_role.lambda_execution_role,
    aws_cloudwatch_log_group.lambda_cw_log_group
  ]
}

#Creating the lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name               = "LambdaSQSExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_sqs_iam_policy.arn
}

resource "aws_iam_policy" "lambda_sqs_iam_policy" {
  name   = "LambdaSQSPermissions"
  policy = data.aws_iam_policy_document.lambda_sqs_iam_policy_document.json
}

data "aws_iam_policy_document" "lambda_sqs_iam_policy_document" {
  statement {
    sid     = "AllowToPublishToCloudWatchLogGroup"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  statement {
    sid     = "AllowSQS"
    effect  = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      "*",
    ]
  }
}

#Integrating Lambda function with SQS
resource "aws_lambda_event_source_mapping" "url_checker_lambda_event_source_mapping" {
  event_source_arn = aws_sqs_queue.order.arn
  function_name    = aws_lambda_function.order_processing_lambda.arn
  filter_criteria {
    filter {
      pattern = jsonencode(
        {
          body = {
            orderQty : [{ numeric : [">", 10] }]
          }
        }
      )
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_cw_log_group" {
  name              = "/aws/lambda/OrderProcessingLogs"
  retention_in_days = 30
}