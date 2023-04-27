
# variables
variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-south-1"
}

# PROVIDERS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.30.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.3.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ProjectName = "autotag-project"
    }
  }
}

# CLOUDTRAIL
data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "autotag-trail" {
  name                          = "autotag-trail"
  s3_bucket_name                = aws_s3_bucket.autotag-trail-bucket.id
  include_global_service_events = false
}

resource "aws_s3_bucket" "autotag-trail-bucket" {
  bucket_prefix = "autotag-trail-"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.autotag-trail-bucket.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AWSCloudTrailAclCheck",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudtrail.amazonaws.com"
          },
          "Action" : "s3:GetBucketAcl",
          "Resource" : [aws_s3_bucket.autotag-trail-bucket.arn]
        },
        {
          "Sid" : "AWSCloudTrailWrite",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudtrail.amazonaws.com"
          },
          "Action" : "s3:PutObject",
          "Resource" : ["${aws_s3_bucket.autotag-trail-bucket.arn}/AWSLogs/*"],
          "Condition" : {
            "StringEquals" : {
              "s3:x-amz-acl" : "bucket-owner-full-control"
            }
          }
        }
      ]
    }
  )
}


# EVENTBRIDGE
resource "aws_cloudwatch_event_rule" "default" {
  name        = "autotag-rule"
  description = "Triggers Lambda on cloudtrail api events"
  is_enabled  = true
  event_pattern = jsonencode({
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventSource" : [
        "sns.amazonaws.com",
      ],
      "eventName" : [
        "CreateTopic",
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule       = aws_cloudwatch_event_rule.default.name
  arn        = aws_lambda_function.autotag.arn
  depends_on = [aws_lambda_function.autotag]
}

resource "aws_lambda_permission" "event_brige_rule" {
  statement_id  = "AllowExecutionFromEventBridgeRule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autotag.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.default.arn
  depends_on    = [aws_lambda_function.autotag]
}

# LAMBDA
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_inline_policy" {
  statement {
    effect = "Allow"
    actions = [
      "tag:TagResources",
      "tag:TagResource",
      "SNS:TagResource",
    ]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda-autotag"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  inline_policy {
    name   = "AutotagFunctionPermissions"
    policy = data.aws_iam_policy_document.lambda_inline_policy.json
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_grp" {
  name              = "/aws/lambda/autotag"
  retention_in_days = 30
}

data "archive_file" "lambda_autotag" {
  type        = "zip"
  source_file = "autotag.py"
  output_path = "dist/autotag.py.zip"
}

resource "aws_lambda_function" "autotag" {
  role = aws_iam_role.lambda_exec_role.arn

  function_name    = "autotag"
  filename         = "dist/autotag.py.zip"
  handler          = "autotag.lambda_handler"
  source_code_hash = data.archive_file.lambda_autotag.output_base64sha256

  runtime     = "python3.9"
  timeout     = 300
  memory_size = 128

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_grp
  ]
}
