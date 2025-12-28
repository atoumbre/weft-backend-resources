terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {}
}

provider "aws" {}

module "admin" {
  source = "../../blueprints/admin"

  notification_email = "atoumbre@gmail.com"
  budget_limit       = "25"
  budget_alerts = [
    {
      notification_type = "ACTUAL"
      threshold         = 80
    },
    {
      notification_type = "FORECASTED"
      threshold         = 100
    }
  ]

  github_repo = "weft-backend-*"

  // Grafana AWS Account ID
  external_id = "2874643"
}


