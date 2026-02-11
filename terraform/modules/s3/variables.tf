# =============================================================================
# S3 Module - Variables
# =============================================================================

variable "bucket_names" {
  description = "List of bucket names"
  type        = list(string)
}

variable "enable_versioning" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Block public access"
  type        = bool
  default     = true
}

variable "artifact_expiration_days" {
  description = "Days before artifact expiration"
  type        = number
  default     = 30
}

variable "noncurrent_expiration_days" {
  description = "Days before noncurrent version expiration"
  type        = number
  default     = 30
}

variable "enable_lifecycle" {
  description = "Enable lifecycle rules"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
