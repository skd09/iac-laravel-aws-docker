# =============================================================================
# Monitoring Module - Outputs
# =============================================================================

output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "cpu_alarm_arn" {
  description = "CPU alarm ARN"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "status_check_alarm_arn" {
  description = "Status check alarm ARN"
  value       = aws_cloudwatch_metric_alarm.status_check.arn
}
