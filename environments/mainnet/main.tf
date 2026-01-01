variable "aws_region" {
  type    = string
  default = "us-east-1"
}

module "networking" {
  source = "../../blueprints/networking"

  vpc_cidr_block      = "10.0.0.0/16"
  public_subnet_count = 2
  tags = {
    Environment = "mainnet"
    ManagedBy   = "Terraform"
  }
}

module "liquidation_service" {
  source = "../../blueprints/liquidation-service"

  aws_region  = var.aws_region
  environment = "mainnet"
  vpc_id      = module.networking.vpc_id
  subnet_ids  = module.networking.public_subnet_ids

  radix_gateway_url  = "https://mainnet.radixdlt.com/"
  log_retention_days = 7
  log_level          = "info"

  ecs_indexer_cpu    = "256"
  ecs_indexer_memory = "512"

  indexer_image_tag = ""

  indexer_batch_size = 1000

  ecs_indexer_min_capacity         = 1
  ecs_indexer_max_capacity         = 5
  ecs_indexer_scaling_target_value = 10
  ecs_indexer_scale_out_cooldown   = 120
  ecs_indexer_scale_in_cooldown    = 120

  indexer_sqs_visibility_timeout = 600
  indexer_sqs_max_receive_count  = 3

  ssm_parameter_name_seed_phrase = "/seed_phrase/liquidation/mainnet"

  liquidator_sqs_visibility_timeout = 600
  liquidator_sqs_max_receive_count  = 3

  dispatcher_schedule = "rate(1 minutes)"
  dispatcher_memory   = 128
  dispatcher_timeout  = 300
}

module "price_updater_service" {
  source = "../../blueprints/price-updater-service"

  function_name      = "weft-mainnet-oracle-updater"
  log_retention_days = 7
  log_level          = "info"

  oracle_updater_schedule               = "rate(10 minutes)"
  oracle_updater_timeout                = 300
  oracle_updater_memory                 = 128
  oracle_updater_account_address        = "TODO_MAINNET_ADDRESS"
  oracle_updater_badge_resource_address = "TODO_MAINNET_ADDRESS"
  oracle_updater_component_address      = "TODO_MAINNET_ADDRESS"
  oracle_updater_badge_nft_id           = "#1#"

  ssm_parameter_name_seed_phrase = "/seed_phrase/price_updater/mainnet"
}

module "observability" {
  source = "../../blueprints/observability"

  aws_region  = var.aws_region
  environment = "mainnet"

  filter_pattern = ""

  metric_namespaces = [
    "AWS/ECS",
    "AWS/SQS",
    "AWS/Lambda",
  ]

  log_groups = {
    "liquidator"    = module.liquidation_service.liquidator_log_group_name
    "dispatcher"    = module.liquidation_service.dispatcher_log_group_name
    "indexer"       = module.liquidation_service.indexer_log_group_name
    "price_updater" = module.price_updater_service.log_group_name
  }
}