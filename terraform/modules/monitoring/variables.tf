# =============================================================================
# CloudWatch Monitoring Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "ec2_instance_id" {
  description = "EC2 instance ID to monitor"
  type        = string
}

variable "alarm_email" {
  description = "Email for alarm notifications"
  type        = string
}

variable "cpu_threshold" {
  description = "CPU utilization threshold (%)"
  type        = number
  default     = 80
}

variable "evaluation_periods" {
  description = "Number of periods to evaluate"
  type        = number
  default     = 2
}

variable "period_seconds" {
  description = "Period in seconds"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
