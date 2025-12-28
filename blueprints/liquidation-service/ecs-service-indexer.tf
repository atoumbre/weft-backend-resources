module "cdp_data_bucket" {
  source      = "../../modules/secure_s3_bucket"
  bucket_name = "weft-${var.environment}-cdp-data"
}

module "indexer_service" {
  source = "../../modules/ecs_autoscaling_service"

  service_name       = "weft-${var.environment}-indexer"
  family             = "weft-indexer"
  container_name     = "indexer"
  cpu                = var.ecs_indexer_cpu
  memory             = var.ecs_indexer_memory
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  aws_region         = var.aws_region

  create_ecr_repo  = true
  ecr_repo_name    = "weft-indexer"
  create_task_role = true

  logging_config = {
    retention_days = var.log_retention_days
    group_name     = "/aws/ecs/weft-${var.environment}-indexer"
    stream_prefix  = "indexer"
  }

  scaling_config = {
    min_capacity       = var.ecs_indexer_min_capacity
    max_capacity       = var.ecs_indexer_max_capacity
    target_value       = var.ecs_indexer_scaling_target_value
    scale_in_cooldown  = var.ecs_indexer_scale_in_cooldown
    scale_out_cooldown = var.ecs_indexer_scale_out_cooldown
    dimension_value    = "weft-${var.environment}-indexer-main-queue"
  }

  network_config = {
    cluster_id         = aws_ecs_cluster.main.id
    cluster_name       = aws_ecs_cluster.main.name
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.ecs_sg.id]
    assign_public_ip   = true
  }

  queues_to_create = {
    main = {
      access_type        = "read"
      visibility_timeout = var.indexer_sqs_visibility_timeout
      max_receive_count  = var.indexer_sqs_max_receive_count
    }
    liquidation = {
      access_type        = "write"
      visibility_timeout = var.liquidator_sqs_visibility_timeout
      max_receive_count  = var.liquidator_sqs_max_receive_count
    }
  }

  environment = [
    { name = "QUEUE_URL", value = module.indexer_service.queues["main"].id },
    { name = "LIQUIDATION_QUEUE_URL", value = module.indexer_service.queues["liquidation"].id },
    { name = "BUCKET_NAME", value = module.cdp_data_bucket.bucket_id },
    { name = "RADIX_GATEWAY_URL", value = var.radix_gateway_url },
    { name = "LOG_LEVEL", value = var.log_level }
  ]

  extra_task_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = ["${module.cdp_data_bucket.bucket_arn}/*"]
    }
  ]
}
