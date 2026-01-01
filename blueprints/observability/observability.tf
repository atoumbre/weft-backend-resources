variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. mainnet, stokenet)"
  type        = string
}

variable "log_groups" {
  description = "Map of log groups to forward to Grafana Cloud"
  type        = map(string)
}

variable "filter_pattern" {
  description = "Filter pattern for log subscription filters"
  type        = string
}

module "grafana_metrics" {
  source = "../../modules/grafana-metric-stream"

  aws_region           = var.aws_region
  firehose_stream_name = "grafana-cloud-${var.environment}-metric-stream"
  fallback_bucket_name = "grafana-cloud-${var.environment}-metric-stream-fallback"
  include_namespaces = [
    "AWS/ECS",
    "AWS/SQS",
    "AWS/Lambda",
  ]
  ssm_parameter_name_grafana_metric_write_token   = "/observability/grafana_metric_write_token"
  ssm_parameter_name_grafana_cloud_provider_token = "/observability/grafana_provider_token"

  grafana_cloud_stack_slug = "atoumbre"
  cloud_provider_url       = "https://cloud-provider-api-prod-us-east-3.grafana.net"
}

module "grafana_logs" {
  source = "../../modules/grafana-log-stream"

  aws_region                                 = var.aws_region
  firehose_stream_name                       = "grafana-cloud-${var.environment}-log-stream"
  fallback_bucket_name                       = "grafana-cloud-${var.environment}-log-stream-fallback"
  ssm_parameter_name_grafana_log_write_token = "/observability/grafana_log_token"

  logs_instance_id = "1432998"
  target_endpoint  = "https://aws-logs-prod-042.grafana.net/aws-logs/api/v1/push"
}


resource "aws_cloudwatch_log_subscription_filter" "lambda_logs" {
  for_each = var.log_groups

  name            = "${each.key}_log_filter"
  role_arn        = module.grafana_logs.logs_role_arn
  log_group_name  = each.value
  destination_arn = module.grafana_logs.firehose_stream_arn
  distribution    = "ByLogStream"
  filter_pattern  = var.filter_pattern
}



output "grafana_logs_role_arn" {
  value = module.grafana_logs.logs_role_arn
}

output "grafana_logs_firehose_stream_arn" {
  value = module.grafana_logs.firehose_stream_arn
}