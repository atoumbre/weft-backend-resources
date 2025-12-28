variable "budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
}

variable "notification_email" {
  description = "Email address for budget notifications"
  type        = string
}

variable "budget_alerts" {
  description = "List of budget alert configurations"
  type = list(object({
    notification_type = string # "ACTUAL" or "FORECASTED"
    threshold         = number # Percentage threshold
  }))
}

resource "aws_budgets_budget" "monthly" {
  name              = "monthly-spend-budget"
  budget_type       = "COST"
  limit_amount      = var.budget_limit
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00" # Broad start date
  time_unit         = "MONTHLY"

  dynamic "notification" {
    for_each = var.budget_alerts
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.notification_type
      subscriber_email_addresses = [var.notification_email]
    }
  }
}


