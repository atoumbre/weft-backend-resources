//--------------------------------------------------------------------------------------//
//                                                                                      //
//                                 Grafana Cloud AWS Metrics Streaming                  //
//                                                                                      //
//--------------------------------------------------------------------------------------//

//--------------------------------------------------------------------------------------//
//                           Terraform provider configuration                           //
//--------------------------------------------------------------------------------------//

# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#     grafana = {
#       source  = "grafana/grafana"
#       version = ">= 3.24.1"
#     }
#   }
# }



# provider "grafana" {
#   cloud_provider_access_token = var.cloud_provider_token
#   cloud_access_policy_token   = var.cloud_provider_token
#   cloud_provider_url          = var.cloud_provider_url
# }

//--------------------------------------------------------------------------------------//
//                                      Variables                                       //
//--------------------------------------------------------------------------------------//

variable "grafana_cloud_sts_aws_account_id" {
  description = "Grafana Cloud AWS account ID used for STS by the AWS Resource Metadata Scrape Job"
  type        = string
  default     = "008923505280"
}

variable "grafana_cloud_stack_slug" {
  description = "Slug of the Grafana Cloud stack to use for the AWS Resource Metadata Scrape Job"
  type        = string
}

variable "include_namespaces" {
  description = "List of AWS namespaces to include in the metric stream."
  type        = list(string)
}

variable "cloud_provider_url" {
  description = "URL to call Grafana Cloud's Cloud Provider API"
  type        = string
}

variable "fallback_bucket_name" {
  type        = string
  description = "Name of the S3 bucket where failed metric batches will be written to"
  # default     = "grafana-cloud-metric-stream-fallback"
}

variable "firehose_stream_name" {
  type        = string
  description = "Name of the CloudWatch metric stream"
  # default     = "grafana-cloud-metric-stream"
}

variable "target_endpoint" {
  description = "Target endpoint for delivering metrics to Grafana Cloud Provider Observability. If empty, this will be computed based on the stack's Prometheus URL."
  type        = string
  default     = ""
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
  default     = "grafana_cloud_metric_stream_errors"
}

variable "errors_log_stream_name" {
  description = "Name of the log stream to write to when `log_delivery_errors` is enabled."
  type        = string
  default     = "DeliveryErrors"
}

data "grafana_cloud_stack" "main" {
  slug = var.grafana_cloud_stack_slug
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

// main IAM role used by the firehose stream for writing failed batches to S3
resource "aws_iam_role" "firehose" {
  name = format("Firehose-%s", var.firehose_stream_name)

  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

// allow firehose to emit error logs and back up to s3
resource "aws_iam_role_policy" "firehose" {
  name = format("Firehose-%s", var.firehose_stream_name)

  // attach to firehose http
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      // allow firehose to write error logs
      {
        Effect   = "Allow"
        Resource = ["*"]
        Action   = ["logs:PutLogEvents"]
      },
      // allow firehose to backup events to s3
      {
        "Sid"    = "s3Permissions"
        "Effect" = "Allow"
        "Action" = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject",
        ]
        "Resource" = [
          aws_s3_bucket.fallback.arn,
          "${aws_s3_bucket.fallback.arn}/*",
        ]
      },
    ]
  })
}

// IAM role used by CloudWatch metric stream for forwarding metrics to Firehose
resource "aws_iam_role" "metric_stream_role" {
  name = format("MetricStream-%s", var.firehose_stream_name)

  // allow metric stream to assume this role
  assume_role_policy = data.aws_iam_policy_document.metric_stream_assume_role.json
}

data "aws_iam_policy_document" "metric_stream_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["streams.metrics.cloudwatch.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "metric_stream_role" {
  name = "AWSCloudWatchMetricStreamPolicy"
  role = aws_iam_role.metric_stream_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      // allow metric stream to write to firehose
      {
        Action = ["firehose:PutRecord", "firehose:PutRecordBatch"]
        Effect = "Allow"
        Resource = [
          aws_kinesis_firehose_delivery_stream.stream.arn,
        ]
      },
    ]
  })
}

// IAM resources needed to authorize Grafana Cloud to scrape AWS resource metadata
data "aws_iam_policy_document" "trust_grafana" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.grafana_cloud_sts_aws_account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.grafana_cloud_stack.main.prometheus_user_id]
    }
  }
}

resource "aws_iam_role" "grafana_cloud_aws_resource_metadata" {
  name        = "GrafanaAWSResourceMetadataScrapeJobAccess"
  description = "Role used by Grafana CloudWatch integration."
  # Allow Grafana Labs' AWS account to assume this role.
  assume_role_policy = data.aws_iam_policy_document.trust_grafana.json
}

resource "aws_iam_role_policy" "grafana_cloud_aws_resource_metadata" {
  name = "GrafanaAWSResourceMetadataScrapeJobAccess"
  role = aws_iam_role.grafana_cloud_aws_resource_metadata.id
  # This policy allows the role to discover resources via tags and API calls.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources",
          "apigateway:GET",
          "aps:ListWorkspaces",
          "autoscaling:DescribeAutoScalingGroups",
          "dms:DescribeReplicationInstances",
          "dms:DescribeReplicationTasks",
          "ec2:DescribeTransitGatewayAttachments",
          "ec2:DescribeSpotFleetRequests",
          "shield:ListProtections",
          "storagegateway:ListGateways",
          "storagegateway:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })
}

// Allow some time for IAM (global) changes to propagate
resource "time_sleep" "wait_iam_propagation" {
  depends_on = [
    aws_iam_role.grafana_cloud_aws_resource_metadata,
    aws_iam_role_policy.grafana_cloud_aws_resource_metadata
  ]
  create_duration = "10s"
}


//--------------------------------------------------------------------------------------//
//                    Grafana Cloud AWS Resource Metadata Scrape Job                    //
//--------------------------------------------------------------------------------------//
resource "grafana_cloud_provider_aws_account" "main" {
  depends_on = [
    time_sleep.wait_iam_propagation
  ]

  stack_id = data.grafana_cloud_stack.main.id
  role_arn = aws_iam_role.grafana_cloud_aws_resource_metadata.arn
  regions  = [var.aws_region]
}

resource "grafana_cloud_provider_aws_resource_metadata_scrape_job" "main" {
  stack_id                = data.grafana_cloud_stack.main.id
  name                    = "aws-resource-metadata-scraper"
  aws_account_resource_id = grafana_cloud_provider_aws_account.main.resource_id

  dynamic "service" {
    for_each = var.include_namespaces
    content {
      name = service.value
    }
  }
}


//--------------------------------------------------------------------------------------//
//                                       Firehose                                       //
//--------------------------------------------------------------------------------------//
locals {
  // If the target endpoint is not explicitly provided, then convert the stack's Prometheus URL 
  // to the Grafana Cloud AWS Metric Streaming ingest endpoint.
  // Ex: https://prometheus-prod-03-prod-us-central-0.grafana.net
  // becomes https://aws-metric-streams-prod-03.grafana.net/aws-metrics/api/v1/push
  target_endpoint = var.target_endpoint != "" ? var.target_endpoint : format("%s/aws-metrics/api/v1/push", replace(
    replace(data.grafana_cloud_stack.main.prometheus_url, "prometheus", "aws-metric-streams"),
    "-${data.grafana_cloud_stack.main.cluster_slug}",
    ""
  ))
}

resource "aws_kinesis_firehose_delivery_stream" "stream" {
  name        = format("%s-firehose", var.firehose_stream_name)
  destination = "http_endpoint"

  http_endpoint_configuration {
    url        = local.target_endpoint
    name       = "Grafana AWS Metric Stream Destination"
    access_key = format("%s:%s", data.grafana_cloud_stack.main.prometheus_user_id, data.aws_ssm_parameter.metric_write_token.value)

    // Buffer incoming data to the specified size, in MBs, before delivering it to the destination
    buffering_size = 1

    // Buffer incoming data for the specified period of time, in seconds, before delivering it to the destination
    // Setting to 1 minute to keep a low enough latency between metric production and actual time they are processed
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
//                                   CloudWatch Metric Stream                          //
//--------------------------------------------------------------------------------------//

resource "aws_cloudwatch_metric_stream" "metric_stream" {
  name          = var.firehose_stream_name
  role_arn      = aws_iam_role.metric_stream_role.arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.stream.arn
  output_format = "opentelemetry1.0"

  dynamic "include_filter" {
    // Stream all metrics from the specified namespaces
    for_each = var.include_namespaces
    content {
      namespace = include_filter.value
    }
  }
}

//--------------------------------------------------------------------------------------//
//                                        Outputs                                       //
//--------------------------------------------------------------------------------------//

output "grafana_cloud_aws_resource_metadata_role_arn" {
  description = "ARN of the Grafana Cloud AWS Resource Metadata Scrape Job access role"
  value       = aws_iam_role.grafana_cloud_aws_resource_metadata.arn
}

output "metric_stream_arn" {
  description = "ARN of the CloudWatch metric stream"
  value       = aws_cloudwatch_metric_stream.metric_stream.arn
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.stream.arn
}

output "fallback_bucket_name" {
  description = "Name of the S3 fallback bucket"
  value       = aws_s3_bucket.fallback.id
}
