# =============================================================================
# CloudWatch Monitoring Module
# =============================================================================

# -----------------------------------------------------------------------------
# SNS Topic for Alarms
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-alarms"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------------------------------------------------------
# CPU High Alarm
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.period_seconds
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "CPU utilization is above ${var.cpu_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Status Check Failed Alarm
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "${var.name_prefix}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 status check failed"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Disk Usage Alarm (requires CloudWatch Agent)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.name_prefix}-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = var.period_seconds
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Disk usage is above 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
    path       = "/"
    fstype     = "ext4"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Memory Usage Alarm (requires CloudWatch Agent)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.name_prefix}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = var.period_seconds
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Memory usage is above 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = var.tags
}
