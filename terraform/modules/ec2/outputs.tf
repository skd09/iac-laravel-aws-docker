# =============================================================================
# EC2 Module - Outputs
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "private_ip" {
  description = "EC2 private IP"
  value       = aws_instance.main.private_ip
}

output "public_ip" {
  description = "EC2 public IP (Elastic IP if created)"
  value       = var.create_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
}

output "eip_id" {
  description = "Elastic IP ID"
  value       = var.create_eip ? aws_eip.main[0].id : null
}
