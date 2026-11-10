terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive" }
  }
}

provider "aws" { region = var.region }

data "aws_caller_identity" "current" {}

# ---------- S3 ----------
resource "aws_s3_bucket" "uploads" {
  bucket        = "${var.project}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # lets `terraform destroy` delete a non-empty bucket
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ---------- SNS ----------
resource "aws_sns_topic" "notify" {
  name = "${var.project}-topic"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notify.arn
  protocol  = "email"
  endpoint  = var.email
}

# ---------- IAM ----------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "publish" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.notify.arn]
  }
}

resource "aws_iam_role_policy" "publish" {
  name   = "sns-publish"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.publish.json
}

# ---------- Lambda ----------
data "archive_file" "zip" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda_function.py"
  output_path = "${path.module}/function.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}"
  retention_in_days = 7
}

resource "aws_lambda_function" "notifier" {
  function_name    = var.project
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  environment {
    variables = { TOPIC_ARN = aws_sns_topic.notify.arn }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

# ---------- S3 -> Lambda wiring ----------
resource "aws_lambda_permission" "s3" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.notifier.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.uploads.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.notifier.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3] 
}