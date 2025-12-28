


variable "oracle_updater_schedule" {
  description = "Schedule expression for oracle updater (e.g. rate(5 minutes))"
  type        = string
}

variable "oracle_updater_timeout" {
  description = "Timeout for oracle updater Lambda in seconds"
  type        = number
}

variable "oracle_updater_memory" {
  description = "Memory size for oracle updater Lambda in MB"
  type        = number
}

variable "oracle_updater_account_address" {
  description = "Account address used by oracle updater"
  type        = string
}

variable "oracle_updater_badge_resource_address" {
  description = "Badge resource address used by oracle updater"
  type        = string
}

variable "oracle_updater_component_address" {
  description = "Oracle component address"
  type        = string
}

variable "oracle_updater_badge_nft_id" {
  description = "Badge NFT ID used by oracle updater"
  type        = string
  default     = "#1#"
}

variable "ssm_parameter_name_seed_phrase" {
  description = "The name of the SSM parameter storing the seed phrase"
  type        = string
}

data "aws_ssm_parameter" "seed_phrase" {
  name = var.ssm_parameter_name_seed_phrase
}

module "oracle_updater" {
  source = "../../modules/scheduled_lambda"

  function_name      = var.function_name
  schedule           = var.oracle_updater_schedule
  timeout            = var.oracle_updater_timeout
  memory             = var.oracle_updater_memory
  log_retention_days = var.log_retention_days
  environment_variables = {
    ACCOUNT_ADDRESS          = var.oracle_updater_account_address
    BADGE_RESOURCE_ADDRESS   = var.oracle_updater_badge_resource_address
    ORACLE_COMPONENT_ADDRESS = var.oracle_updater_component_address
    BADGE_NFT_ID             = var.oracle_updater_badge_nft_id
    LOG_LEVEL                = var.log_level
    SEED_PHRASE              = data.aws_ssm_parameter.seed_phrase.value
  }
}

variable "log_level" {
  description = "Log level for all services (debug, info, warn, error)"
  type        = string
  default     = "info"
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}

variable "function_name" {
  description = "Name of the function"
  type        = string
}
