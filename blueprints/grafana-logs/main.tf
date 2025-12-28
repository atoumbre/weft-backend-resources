
variable "aws_region" {
  description = "AWS region to deploy observability resources into."
  type        = string
}

variable "ssm_parameter_name_grafana_log_write_token" {
  type = string
}

data "aws_ssm_parameter" "logs_write_token" {
  name = var.ssm_parameter_name_grafana_log_write_token
}
