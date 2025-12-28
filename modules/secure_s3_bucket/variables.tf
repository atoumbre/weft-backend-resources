variable "bucket_name" {
  description = "The name of the bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Whether versioning is enabled"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Whether to allow the bucket to be destroyed even if it contains objects"
  type        = bool
  default     = false
}
