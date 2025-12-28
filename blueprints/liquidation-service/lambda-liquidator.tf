data "aws_ssm_parameter" "liquidation_seed" {
  name = var.ssm_parameter_name_seed_phrase
}


module "liquidator" {
  source = "../../modules/scheduled_lambda"

  function_name      = "weft-${var.environment}-liquidator"
  timeout            = var.liquidator_lambda_timeout
  memory             = var.liquidator_lambda_memory
  log_retention_days = var.log_retention_days

  # SQS Triggered, not scheduled
  schedule = null

  environment_variables = {
    LIQUIDATION_QUEUE_URL = module.indexer_service.queues["liquidation"].id
    RADIX_GATEWAY_URL     = var.radix_gateway_url
    LOG_LEVEL             = var.log_level
    SEED_PHRASE           = data.aws_ssm_parameter.liquidation_seed.value
  }

  extra_iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      resources = [module.indexer_service.queues["liquidation"].arn]
    },
    {
      effect    = "Allow"
      actions   = ["ssm:GetParameters", "ssm:GetParameter"]
      resources = [data.aws_ssm_parameter.liquidation_seed.arn]
    }
  ]
}

resource "aws_lambda_event_source_mapping" "liquidator_trigger" {
  event_source_arn = module.indexer_service.queues["liquidation"].arn
  function_name    = module.liquidator.function_arn

  # How many messages to grab in one go
  batch_size = var.liquidator_lambda_batch_size

  # How long to wait to fill the batch (in seconds)
  maximum_batching_window_in_seconds = 5

  # Enable partial failure reporting (Must match your code logic)
  function_response_types = ["ReportBatchItemFailures"]

  # Protect your RPC node
  scaling_config {
    maximum_concurrency = var.liquidator_lambda_max_concurrency
  }
}