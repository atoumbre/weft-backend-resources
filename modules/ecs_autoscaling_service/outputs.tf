output "queues" {
  description = "Map of created SQS queues (id and arn)"
  value = {
    for k, v in var.queues_to_create : k => {
      id  = aws_sqs_queue.main[k].id
      arn = aws_sqs_queue.main[k].arn
    }
  }
}

output "task_role_arn" {
  description = "The ARN of the task role"
  value       = local.task_role_arn
}

output "task_role_name" {
  description = "The name of the task role"
  value       = var.create_task_role ? aws_iam_role.task[0].name : null
}

output "repository_url" {
  description = "The URL of the created ECR repository"
  value       = var.create_ecr_repo ? aws_ecr_repository.this[0].repository_url : null
}

output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.name
}
