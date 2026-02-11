# =============================================================================
# Laravel AWS DevOps - DEV Environment Outputs
# =============================================================================

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "EC2 public IP"
  value       = module.ec2.public_ip
}

output "ec2_private_ip" {
  description = "EC2 private IP"
  value       = module.ec2.private_ip
}

output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = module.security_groups.ec2_security_group_id
}
