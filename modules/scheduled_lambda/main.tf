variable "schedule" {
  description = "Schedule expression for Lambda (e.g. rate(5 minutes)). If null, no scheduler is created."
  type        = string
  default     = null
}

variable "timeout" {
  description = "Timeout for Lambda in seconds"
  type        = number
}

variable "memory" {
  description = "Memory size for Lambda in MB"
  type        = number
}

variable "environment_variables" {
  description = "Environment variables for Lambda"
  type        = map(string)
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
}

variable "extra_iam_policy_statements" {
  description = "Additional IAM policy statements for the Lambda role"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dummy_payload.zip"
  source {
    content  = "exports.handler = () => 'Dummy code'"
    filename = "dist/index.js"
  }
}

resource "aws_iam_role" "lambda_role" {
  name_prefix = "${var.function_name}-role-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_extra" {
  count = length(var.extra_iam_policy_statements) > 0 ? 1 : 0
  role  = aws_iam_role.lambda_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for statement in var.extra_iam_policy_statements : {
        Effect   = statement.effect
        Action   = statement.actions
        Resource = statement.resources
      }
    ]
  })
}

resource "aws_lambda_function" "lambda" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "dist/index.handler"
  runtime          = "nodejs22.x"
  timeout          = var.timeout
  memory_size      = var.memory
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = var.environment_variables
  }

  lifecycle {
    # CRITICAL: This stops Terraform from reverting your code 
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_scheduler_schedule" "lambda_schedule" {
  count = var.schedule != null ? 1 : 0
  name  = "${var.function_name}-schedule"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.schedule

  target {
    arn      = aws_lambda_function.lambda.arn
    role_arn = aws_iam_role.scheduler_role[0].arn
  }
}

resource "aws_iam_role" "scheduler_role" {
  count       = var.schedule != null ? 1 : 0
  name_prefix = "${var.function_name}-sched-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  count = var.schedule != null ? 1 : 0
  role  = aws_iam_role.scheduler_role[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.lambda.arn
    }]
  })
}
