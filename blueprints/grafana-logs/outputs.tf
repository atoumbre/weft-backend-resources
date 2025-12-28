output "logs_role_arn" {
  description = "ARN of the IAM role for CloudWatch logs to forward to Firehose"
  value       = aws_iam_role.logs.arn
}

output "firehose_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.main.arn
}

output "firehose_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.main.name
}
