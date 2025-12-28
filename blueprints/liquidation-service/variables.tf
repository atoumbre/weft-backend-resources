#--------------------------------------------------------------------------------------#
#                         Liquidation Service Variables                                #
#--------------------------------------------------------------------------------------#

#------------------------------------------------------------------------------
# Core Configuration
#------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. mainnet, stokenet)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "The IDs of the subnets where ECS tasks will run"
  type        = list(string)
}

variable "radix_gateway_url" {
  description = "Radix gateway URL"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
}

variable "log_level" {
  description = "Log level for all services (debug, info, warn, error)"
  type        = string
  default     = "info"
}

variable "ssm_parameter_name_seed_phrase" {
  description = "The name of the SSM parameter storing the seed phrase"
  type        = string
}

#------------------------------------------------------------------------------
# ECS Indexer Configuration
#------------------------------------------------------------------------------

variable "ecs_indexer_cpu" {
  description = "CPU units for indexer task"
  type        = string
}

variable "ecs_indexer_memory" {
  description = "Memory for indexer task"
  type        = string
}

variable "ecs_indexer_min_capacity" {
  description = "Minimum tasks for indexer"
  type        = number
}

variable "ecs_indexer_max_capacity" {
  description = "Maximum tasks for indexer"
  type        = number
}

variable "ecs_indexer_scaling_target_value" {
  description = "SQS messages per task for indexer scaling"
  type        = number
}

variable "ecs_indexer_scale_out_cooldown" {
  description = "Cool down after scale out for indexer"
  type        = number
}

variable "ecs_indexer_scale_in_cooldown" {
  description = "Cool down after scale in for indexer"
  type        = number
}

variable "indexer_image_tag" {
  description = "Tag of the indexer image (e.g. v1.0.0 or latest)"
  type        = string
}

variable "indexer_batch_size" {
  description = "Number of CDPs per batch for indexer"
  type        = number
}

variable "indexer_sqs_visibility_timeout" {
  description = "Visibility timeout for SQS queues in seconds"
  type        = number
}

variable "indexer_sqs_max_receive_count" {
  description = "Max receive count before moving to DLQ"
  type        = number
}

#------------------------------------------------------------------------------
# Dispatcher Lambda Configuration
#------------------------------------------------------------------------------

variable "dispatcher_schedule" {
  description = "Schedule expression for dispatcher (e.g. rate(5 minutes))"
  type        = string
}

variable "dispatcher_timeout" {
  description = "Timeout for dispatcher Lambda in seconds"
  type        = number
}

variable "dispatcher_memory" {
  description = "Memory size for dispatcher Lambda in MB"
  type        = number
}

#------------------------------------------------------------------------------
# Liquidator Lambda Configuration
#------------------------------------------------------------------------------

variable "liquidator_lambda_timeout" {
  description = "Timeout for liquidator Lambda in seconds"
  type        = number
  default     = 60
}

variable "liquidator_lambda_memory" {
  description = "Memory size for liquidator Lambda in MB"
  type        = number
  default     = 256
}

variable "liquidator_lambda_batch_size" {
  description = "Number of items to process in a single batch"
  type        = number
  default     = 10
}

variable "liquidator_lambda_max_concurrency" {
  description = "Maximum concurrency for liquidator Lambda"
  type        = number
  default     = 50
}

variable "liquidator_sqs_visibility_timeout" {
  description = "Visibility timeout for SQS queues in seconds"
  type        = number
}

variable "liquidator_sqs_max_receive_count" {
  description = "Max receive count before moving to DLQ"
  type        = number
}
