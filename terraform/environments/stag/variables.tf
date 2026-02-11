# =============================================================================
# Laravel AWS DevOps - STAG Environment Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Core Settings
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stag"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "myproject"
}

variable "ops_name" {
  description = "Operations team name"
  type        = string
  default     = "devops"
}

variable "additional_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Feature Toggles
# -----------------------------------------------------------------------------

variable "create_vpc" {
  description = "Create new VPC"
  type        = bool
  default     = true
}

variable "create_rds" {
  description = "Create new RDS instance"
  type        = bool
  default     = false
}

variable "create_elasticache" {
  description = "Create ElastiCache cluster"
  type        = bool
  default     = false
}

variable "create_s3" {
  description = "Create S3 buckets"
  type        = bool
  default     = true
}

variable "create_codedeploy" {
  description = "Create CodeDeploy resources"
  type        = bool
  default     = true
}

variable "create_ssh_key" {
  description = "Create new SSH key pair (if false, use existing_key_name)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SSH Key Configuration
# -----------------------------------------------------------------------------

variable "existing_key_name" {
  description = "Name of existing SSH key pair (only used if create_ssh_key = false)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Existing VPC Configuration (if create_vpc = false)
# -----------------------------------------------------------------------------

variable "existing_vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "Existing public subnet IDs"
  type        = list(string)
  default     = []
}

variable "existing_data_subnet_ids" {
  description = "Existing data/private subnet IDs"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Existing RDS Configuration (if create_rds = false)
# -----------------------------------------------------------------------------

variable "existing_rds_endpoint" {
  description = "Existing RDS endpoint"
  type        = string
  default     = ""
}

variable "existing_rds_username" {
  description = "Existing RDS username"
  type        = string
  default     = "admin"
}

variable "existing_rds_password" {
  description = "Existing RDS password"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Existing Redis Configuration (if create_elasticache = false)
# -----------------------------------------------------------------------------

variable "existing_redis_endpoint" {
  description = "Existing Redis endpoint"
  type        = string
  default     = "127.0.0.1"
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ca-central-1a", "ca-central-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# EC2 Configuration
# -----------------------------------------------------------------------------

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ec2_root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

variable "ec2_root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "create_eip" {
  description = "Create Elastic IP"
  type        = bool
  default     = true
}

variable "ubuntu_ami_owner" {
  description = "Ubuntu AMI owner ID"
  type        = string
  default     = "099720109477"
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "enable_ssh" {
  description = "Enable SSH access"
  type        = bool
  default     = true
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed for SSH access"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# RDS Configuration (if create_rds = true)
# -----------------------------------------------------------------------------

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "rds_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Max allocated storage for autoscaling"
  type        = number
  default     = 100
}

variable "rds_database_name" {
  description = "Database name"
  type        = string
  default     = "myproject"
}

variable "rds_master_username" {
  description = "Master username"
  type        = string
  default     = "admin"
}

variable "rds_master_password" {
  description = "Master password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_backup_retention_period" {
  description = "Backup retention period"
  type        = number
  default     = 14
}

variable "rds_backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ElastiCache Configuration (if create_elasticache = true)
# -----------------------------------------------------------------------------

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "mon:05:00-mon:06:00"
}

# -----------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------

variable "s3_bucket_prefix" {
  description = "S3 bucket prefix"
  type        = string
  default     = "myproject-stag"
}

variable "s3_bucket_suffixes" {
  description = "S3 bucket suffixes to create"
  type        = list(string)
  default     = ["app-api-uploads", "app-web-uploads", "app-admin-uploads", "app-dashboard-uploads", "codedeploy-artifacts"]
}

variable "s3_artifact_expiration_days" {
  description = "Days to keep artifacts"
  type        = number
  default     = 60
}

variable "s3_noncurrent_expiration_days" {
  description = "Days to keep noncurrent versions"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# CodeDeploy Configuration
# -----------------------------------------------------------------------------

variable "codedeploy_apps" {
  description = "List of CodeDeploy deployment group names (instance IDs)"
  type        = list(string)
  default     = ["app-api", "app-worker", "app-web", "app-admin", "app-dashboard"]
}

# -----------------------------------------------------------------------------
# Monitoring Configuration
# -----------------------------------------------------------------------------

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "cpu_threshold" {
  description = "CPU threshold for alarm"
  type        = number
  default     = 80
}
