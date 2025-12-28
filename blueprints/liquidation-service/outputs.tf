output "dispatcher_function_name" {
  description = "The name of the dispatcher Lambda function"
  value       = module.dispatcher.function_name
}

output "liquidator_function_name" {
  description = "The name of the liquidator Lambda function"
  value       = module.liquidator.function_name
}

output "dispatcher_role_arn" {
  description = "The ARN of the IAM role for the dispatcher Lambda function"
  value       = module.dispatcher.role_arn
}

output "liquidator_role_arn" {
  description = "The ARN of the IAM role for the liquidator Lambda function"
  value       = module.liquidator.role_arn
}

output "dispatcher_log_group_name" {
  description = "The name of the dispatcher CloudWatch log group"
  value       = module.dispatcher.log_group_name
}

output "liquidator_log_group_name" {
  description = "The name of the liquidator CloudWatch log group"
  value       = module.liquidator.log_group_name
}

output "indexer_log_group_name" {
  description = "The name of the indexer CloudWatch log group"
  value       = module.indexer_service.log_group_name
}
