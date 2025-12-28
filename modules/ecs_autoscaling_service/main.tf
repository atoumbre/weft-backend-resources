// VARIABLES

variable "service_name" {
  description = "ECS service name"
  type        = string
}

variable "family" {
  description = "Task definition family (Defaults to service_name)"
  type        = string
  default     = null
}

variable "container_name" {
  description = "Container name (Defaults to service_name)"
  type        = string
  default     = null
}

variable "image" {
  description = "Container image (Optional if create_ecr_repo is true)"
  type        = string
  default     = null
}

variable "cpu" {
  description = "Task CPU"
  type        = string
}

variable "memory" {
  description = "Task memory"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN (Optional if create_task_role is true)"
  type        = string
  default     = null
}

variable "create_task_role" {
  description = "Whether to create a new task role"
  type        = bool
  default     = false
}

variable "extra_task_policy_statements" {
  description = "Extra IAM policy statements for the task role"
  type        = any
  default     = []
}

variable "queues_to_create" {
  description = "Map of SQS queues to create with their access type and optional settings"
  type = map(object({
    access_type        = string # "read", "write", "both"
    create_dlq         = optional(bool, true)
    visibility_timeout = optional(number, 30)
    max_receive_count  = optional(number, 5)
  }))
  default = {}
}

variable "sqs_permissions" {
  description = "List of SQS queues and access types (read, write, both)"
  type = list(object({
    queue_arn   = string
    access_type = string # "read", "write", "both"
  }))
  default = []
}


variable "create_ecr_repo" {
  description = "Whether to create an ECR repository"
  type        = bool
  default     = false
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository (Optional, defaults to service_name)"
  type        = string
  default     = null
}

variable "logging_config" {
  description = "CloudWatch logging configuration"
  type = object({
    retention_days = optional(number, 7)
    group_name     = optional(string)
    stream_prefix  = optional(string)
  })
  default = {}
}


variable "environment" {
  description = "Container environment variables"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Container secrets"
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []
}

variable "network_config" {
  description = "VPC and Cluster network settings"
  type = object({
    cluster_id         = string
    cluster_name       = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
    assign_public_ip   = optional(bool, true)
  })
}

variable "scaling_config" {
  description = "Autoscaling configuration"
  type = object({
    min_capacity       = number
    max_capacity       = number
    target_value       = number
    policy_name        = optional(string)
    scale_in_cooldown  = optional(number, 300)
    scale_out_cooldown = optional(number, 60)
    metric_name        = optional(string, "ApproximateNumberOfMessagesVisible")
    namespace          = optional(string, "AWS/SQS")
    unit               = optional(string, "Count")
    statistic          = optional(string, "Average")
    dimension_name     = optional(string, "QueueName")
    dimension_value    = optional(string)
  })
}


// LOCALS

locals {
  family         = coalesce(var.family, var.service_name)
  container_name = coalesce(var.container_name, var.service_name)

  task_role_arn = var.create_task_role ? aws_iam_role.task[0].arn : var.task_role_arn

  # If we create the repo, we construct the image URL
  # We use ecr_repo_name if provided, otherwise service_name
  ecr_repo_name = var.ecr_repo_name != null ? var.ecr_repo_name : var.service_name
  image         = var.create_ecr_repo ? aws_ecr_repository.this[0].repository_url : var.image

  # Logging config defaults
  log_group_name    = coalesce(var.logging_config.group_name, "/aws/ecs/${var.service_name}")
  log_stream_prefix = coalesce(var.logging_config.stream_prefix, var.service_name)

  # Scaling logic
  # If we create queues, we use the first one in the map (alphabetically) as default dimension if not provided
  first_queue_name = length(var.queues_to_create) > 0 ? aws_sqs_queue.main[keys(var.queues_to_create)[0]].name : null
  scaling_metric_dimension_value = var.scaling_config.dimension_value != null ? var.scaling_config.dimension_value : (
    local.first_queue_name != null ? local.first_queue_name : null
  )

  # SQS Actions Map
  sqs_actions = {
    read  = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    write = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
    both  = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
  }

  # Generate SQS Policy Statements for external queues
  external_sqs_statements = [
    for p in var.sqs_permissions : {
      Effect   = "Allow"
      Action   = local.sqs_actions[p.access_type]
      Resource = [p.queue_arn]
    }
  ]

  # Generate SQS Policy Statements for internal queues
  internal_sqs_statements = [
    for name, config in var.queues_to_create : {
      Effect   = "Allow"
      Action   = local.sqs_actions[config.access_type]
      Resource = [aws_sqs_queue.main[name].arn]
    }
  ]

  # Combined Policy Statements
  all_task_policy_statements = concat(var.extra_task_policy_statements, local.external_sqs_statements, local.internal_sqs_statements)
}

// RESOURCES

resource "aws_ecr_repository" "this" {
  count = var.create_ecr_repo ? 1 : 0
  name  = local.ecr_repo_name
}

resource "aws_sqs_queue" "dlq" {
  for_each = { for k, v in var.queues_to_create : k => v if v.create_dlq }
  name     = "${var.service_name}-${each.key}-queue-dlq"
}

resource "aws_sqs_queue" "main" {
  for_each                   = var.queues_to_create
  name                       = "${var.service_name}-${each.key}-queue"
  visibility_timeout_seconds = each.value.visibility_timeout

  redrive_policy = each.value.create_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = each.value.max_receive_count
  }) : null
}

resource "aws_iam_role" "task" {
  count = var.create_task_role ? 1 : 0
  name  = "${var.service_name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "extra" {
  count = var.create_task_role && length(local.all_task_policy_statements) > 0 ? 1 : 0
  name  = "${var.service_name}-extra-policy"
  role  = aws_iam_role.task[0].name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.all_task_policy_statements
  })
}

resource "aws_iam_role_policy" "execution_ssm" {
  count = length(var.secrets) > 0 ? 1 : 0
  name  = "${var.service_name}-execution-ssm-policy"
  # Extract role name from ARN (arn:aws:iam::account-id:role/role-name)
  role = element(split("/", var.execution_role_arn), length(split("/", var.execution_role_arn)) - 1)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ssm:GetParameters"
        Effect   = "Allow"
        Resource = [for s in var.secrets : s.value_from]
      }
    ]
  })
}


resource "aws_ecs_task_definition" "service" {
  family                   = local.family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = local.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name        = local.container_name
    image       = local.image
    environment = var.environment
    secrets = [
      for secret in var.secrets : {
        name      = secret.name
        valueFrom = secret.value_from
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.log_group_name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = local.log_stream_prefix
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.logging_config.retention_days
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.network_config.cluster_id
  task_definition = aws_ecs_task_definition.service.arn

  network_configuration {
    subnets          = var.network_config.subnet_ids
    security_groups  = var.network_config.security_group_ids
    assign_public_ip = var.network_config.assign_public_ip
  }

  # force_new_deployment = true
  # launch_type          = "FARGATE"
}

resource "aws_appautoscaling_target" "service" {
  max_capacity       = var.scaling_config.max_capacity
  min_capacity       = var.scaling_config.min_capacity
  resource_id        = "service/${var.network_config.cluster_name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "sqs_scaling" {
  name               = coalesce(var.scaling_config.policy_name, "${var.service_name}-sqs-scaling")
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_config.target_value
    scale_in_cooldown  = var.scaling_config.scale_in_cooldown
    scale_out_cooldown = var.scaling_config.scale_out_cooldown

    customized_metric_specification {
      metric_name = var.scaling_config.metric_name
      namespace   = var.scaling_config.namespace
      statistic   = var.scaling_config.statistic
      unit        = var.scaling_config.unit
      dimensions {
        name  = var.scaling_config.dimension_name
        value = local.scaling_metric_dimension_value
      }
    }
  }
}
