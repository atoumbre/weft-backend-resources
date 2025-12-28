variable "aws_region" {
  type = string
  default = "us-east-1"
}

module "networking" {
  source = "../../blueprints/networking"

  vpc_cidr_block      = "10.0.0.0/16"
  public_subnet_count = 2
  tags = {
    Environment = "stokenet"
    ManagedBy   = "Terraform"
  }
}

module "liquidation_service" {
  source = "../../blueprints/liquidation-service"

  aws_region  = var.aws_region
  environment = "stokenet"
  vpc_id      = module.networking.vpc_id
  subnet_ids  = module.networking.public_subnet_ids

  radix_gateway_url  = "https://stokenet.radixdlt.com/"
  log_retention_days = 7
  log_level          = "debug"

  # ECS Configs
  ecs_indexer_cpu    = "256"
  ecs_indexer_memory = "512"

  indexer_image_tag = ""

  indexer_batch_size = 500

  ecs_indexer_min_capacity         = 1
  ecs_indexer_max_capacity         = 5
  ecs_indexer_scaling_target_value = 100.0
  ecs_indexer_scale_out_cooldown   = 300
  ecs_indexer_scale_in_cooldown    = 300

  indexer_sqs_visibility_timeout = 600
  indexer_sqs_max_receive_count  = 3

  ssm_parameter_name_seed_phrase = "/weft/stokenet/liquidation_seed_phrase"

  liquidator_sqs_visibility_timeout = 600
  liquidator_sqs_max_receive_count  = 3

  dispatcher_schedule = "rate(5 minutes)"
  dispatcher_memory   = 128
  dispatcher_timeout  = 300
}

module "price_updater_service" {
  source = "../../blueprints/price-updater-service"

  function_name      = "weft-stokenet-oracle-updater"
  log_retention_days = 7
  log_level          = "debug"

  oracle_updater_schedule               = "rate(10 minutes)"
  oracle_updater_timeout                = 300
  oracle_updater_memory                 = 128
  oracle_updater_account_address        = "TODO_STOKENET_ADDRESS"
  oracle_updater_badge_resource_address = "TODO_STOKENET_ADDRESS"
  oracle_updater_component_address      = "TODO_STOKENET_ADDRESS"
  oracle_updater_badge_nft_id           = "#1#"

  ssm_parameter_name_seed_phrase = "/seed_phrase/liquidation/stokenet"
}

module "grafana_metrics" {
  source = "../../blueprints/grafana-metrics"

  aws_region           = var.aws_region
  firehose_stream_name = "grafana-cloud-stokenet-metric-stream"
  fallback_bucket_name = "grafana-cloud-stokenet-metric-stream-fallback"
  include_namespaces   = ["AWS/ECS", "AWS/SQS", "AWS/Lambda"]

  cloud_provider_url                              = "https://cloud-provider-api-prod-us-east-3.grafana.net"
  ssm_parameter_name_grafana_metric_write_token   = "/observability/grafana_metric_write_token"
  ssm_parameter_name_grafana_cloud_provider_token = "/observability/grafana_provider_token"
  grafana_cloud_stack_slug                        = "atoumbre"
}

module "grafana_logs" {
  source = "../../blueprints/grafana-logs"

  aws_region           = var.aws_region
  firehose_stream_name = "grafana-cloud-stokenet-log-stream"
  fallback_bucket_name = "grafana-cloud-stokenet-log-stream-fallback"

  ssm_parameter_name_grafana_log_write_token = "/observability/grafana_log_token"
  logs_instance_id                           = "1432998"
  target_endpoint                            = "https://aws-logs-prod-042.grafana.net/aws-logs/api/v1/push"
}


# Forward Lambda logs to Grafana Cloud via Firehose
locals {
  lambda_log_groups = {
    liquidator    = module.liquidation_service.liquidator_log_group_name
    dispatcher    = module.liquidation_service.dispatcher_log_group_name
    price_updater = module.price_updater_service.log_group_name
    indexer       = module.liquidation_service.indexer_log_group_name
  }
}

resource "aws_cloudwatch_log_subscription_filter" "lambda_logs" {
  for_each = local.lambda_log_groups

  name            = "${each.key}_log_filter"
  role_arn        = module.grafana_logs.logs_role_arn
  log_group_name  = each.value
  destination_arn = module.grafana_logs.firehose_stream_arn
  distribution    = "ByLogStream"
  filter_pattern  = ""
}
