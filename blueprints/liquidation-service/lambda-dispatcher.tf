module "dispatcher" {
  source = "../../modules/scheduled_lambda"

  function_name      = "weft-${var.environment}-dispatcher"
  schedule           = var.dispatcher_schedule
  timeout            = var.dispatcher_timeout
  memory             = var.dispatcher_memory
  log_retention_days = var.log_retention_days
  environment_variables = {
    INDEXER_QUEUE_URL  = module.indexer_service.queues["main"].id
    INDEXER_BATCH_SIZE = var.indexer_batch_size
    RADIX_GATEWAY_URL  = var.radix_gateway_url
    LOG_LEVEL          = var.log_level
  }
  extra_iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
      resources = [module.indexer_service.queues["main"].arn]
    }
  ]
}
