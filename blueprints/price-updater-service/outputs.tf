output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = module.oracle_updater.log_group_name
}

output "function_name" {
  description = "The name of the Lambda function"
  value       = module.oracle_updater.function_name
}

output "role_arn" {
  description = "The ARN of the IAM role for the Lambda function"
  value       = module.oracle_updater.role_arn
}
