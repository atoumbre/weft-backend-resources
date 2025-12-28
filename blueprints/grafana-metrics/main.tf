
terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.24.1"
    }
  }
}

variable "aws_region" {
  description = "AWS region to deploy observability resources into."
  type        = string
}

provider "grafana" {
  cloud_provider_access_token = data.aws_ssm_parameter.cloud_provider_token.value
  cloud_access_policy_token   = data.aws_ssm_parameter.cloud_provider_token.value
  cloud_provider_url          = var.cloud_provider_url
}

variable "ssm_parameter_name_grafana_metric_write_token" {
  type = string
}

variable "ssm_parameter_name_grafana_cloud_provider_token" {
  type = string
}

data "aws_ssm_parameter" "metric_write_token" {
  name = var.ssm_parameter_name_grafana_metric_write_token
}

data "aws_ssm_parameter" "cloud_provider_token" {
  name = var.ssm_parameter_name_grafana_cloud_provider_token
}