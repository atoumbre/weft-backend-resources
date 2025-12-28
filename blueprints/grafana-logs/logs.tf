//--------------------------------------------------------------------------------------//
//                                                                                      //
//                                   Grafana AWS Logs                                   //
//                                                                                      //
//--------------------------------------------------------------------------------------//
// Tested with hashicorp/aws v5.4.0 provider

//--------------------------------------------------------------------------------------//
//                           Terraform provider configuration                           //
//--------------------------------------------------------------------------------------//



//--------------------------------------------------------------------------------------//
//                                      Variables                                       //
//--------------------------------------------------------------------------------------//

variable "fallback_bucket_name" {
  type        = string
  description = "Name of the S3 bucket where failed batches will be written to"
}

variable "firehose_stream_name" {
  type        = string
  description = "Name of the AWS Firehose delivery stream"
}

variable "target_endpoint" {
  description = "Target endpoint for delivering logs to"
  type        = string
}

variable "logs_instance_id" {
  description = "Grafana Loki instance ID"
  type        = number
}

// Optional 

variable "log_delivery_errors" {
  description = "When enabled, delivery errors will be logged in the configured log group."
  type        = bool
  default     = false
}

variable "errors_log_group_name" {
  description = "Name of the log group to use when `log_delivery_errors` is enabled."
  type        = string
  default     = "grafana_aws_logs_errors"
}

variable "errors_log_stream_name" {
  description = "Name of the log stream to write to when `log_delivery_errors` is enabled."
  type        = string
  default     = "DeliveryErrors"
}

//--------------------------------------------------------------------------------------//
//                                          S3                                          //
//--------------------------------------------------------------------------------------//
//
// Batches whose delivery failed are written here
//

resource "aws_s3_bucket" "fallback" {
  bucket = var.fallback_bucket_name
}

//--------------------------------------------------------------------------------------//
//                                         IAM                                          //
//--------------------------------------------------------------------------------------//

// get caller identity to get AWS account number
data "aws_caller_identity" "current" {}

// main IAM role used by the firehose stream for writing failed batches to S3
resource "aws_iam_role" "firehose" {
  name = "aws_logs_firehose"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      },
    ],
  })
}

resource "aws_iam_role_policy" "firehose" {
  name = "aws_logs_firehose"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # allow firehose to r/w the fallback bucket
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject",
        ]
        Effect = "Allow"
        Resource = [
          format("arn:aws:s3:::%s", aws_s3_bucket.fallback.id),
          format("arn:aws:s3:::%s/*", aws_s3_bucket.fallback.id),
        ]
      },
      # allow firehose to write error logs
      {
        Effect = "Allow"
        Resource : ["*"],
        Action = ["logs:PutLogEvents"]
      }
    ]
  })
}

// IAM role used by CloudWatch logs for forwarding log records to Firehose
resource "aws_iam_role" "logs" {
  name = "aws_logs_logs_subscription"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "logs.amazonaws.com"
        },
        # handle confused deputy problem by checking we are assuming from the same account
        # and a logs based service (logs subscription)
        Condition = {
          StringLike = {
            "aws:SourceArn" = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
    ],
  })
}

resource "aws_iam_role_policy" "logs" {
  name = "aws_logs_logs_subscription"
  role = aws_iam_role.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # allow logs to write to firehose
      {
        Action = ["firehose:PutRecord"]
        Effect = "Allow"
        Resource = [
          aws_kinesis_firehose_delivery_stream.main.arn,
        ]
      },
    ]
  })
}

//--------------------------------------------------------------------------------------//
//                                       Firehose                                       //
//--------------------------------------------------------------------------------------//

resource "aws_kinesis_firehose_delivery_stream" "main" {
  name        = var.firehose_stream_name
  destination = "http_endpoint"

  // this block configures the main destination of the delivery stream
  http_endpoint_configuration {
    url        = var.target_endpoint
    name       = "Grafana AWS Logs Destination"
    access_key = format("%s:%s", var.logs_instance_id, data.aws_ssm_parameter.logs_write_token.value)

    // Buffer incoming data to the specified size, in MBs, before delivering it to the destination
    buffering_size = 1

    // Buffer incoming data for the specified period of time, in seconds, before delivering it to the destination
    // 
    // Setting to 1 minute to keep a low enough latency between log production and actual time they are processed in Loki
    buffering_interval = 60

    role_arn       = aws_iam_role.firehose.arn
    s3_backup_mode = "FailedDataOnly"

    request_configuration {
      content_encoding = "GZIP"
    }

    // this block configured the fallback s3 bucket destination
    s3_configuration {
      role_arn           = aws_iam_role.firehose.arn
      bucket_arn         = aws_s3_bucket.fallback.arn
      buffering_size     = 5
      buffering_interval = 300
      compression_format = "GZIP"
    }

    // Optional block for writing delivery failures to a CW log group
    // this assumes the target log group has been created, or is created in this same snippet
    dynamic "cloudwatch_logging_options" {
      for_each = var.log_delivery_errors ? [1] : []
      content {
        enabled         = true
        log_group_name  = var.errors_log_group_name
        log_stream_name = var.errors_log_stream_name
      }
    }
  }
}

//--------------------------------------------------------------------------------------//
//                            CloudWatch logs subscriptions                             //
//--------------------------------------------------------------------------------------//

// This module snippet creates the main resources for moving logs from AWS into Grafana Cloud Loki.
// To pump the logs into the delivery pipeline (firehose), log subscription filters are needed. The
// example below shows how the snippet for creating one of these looks like.

// resource "aws_cloudwatch_log_subscription_filter" "example-subscription" {
//   name            = "grafana-logs-subscription"
//   role_arn        = aws_iam_role.logs_subscription.arn
//   log_group_name  = // log group where to read logs from
//   filter_pattern  = // optional filtering pattern for subscription
//   destination_arn = aws_kinesis_firehose_delivery_stream.main.arn
//   distribution    = "ByLogStream"
// }
