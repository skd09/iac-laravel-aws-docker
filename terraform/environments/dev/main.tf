# =============================================================================
# Laravel AWS DevOps - DEV Environment
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      Owner       = var.ops_name
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project
      Owner       = var.ops_name
    },
    var.additional_tags
  )

  # Resolve resources
  vpc_id            = var.create_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  public_subnet_ids = var.create_vpc ? module.vpc[0].public_subnet_ids : var.existing_public_subnet_ids
  data_subnet_ids   = var.create_vpc ? module.vpc[0].data_subnet_ids : var.existing_data_subnet_ids

  rds_endpoint = var.create_rds ? module.rds[0].address : var.existing_rds_endpoint
  rds_username = var.create_rds ? var.rds_master_username : var.existing_rds_username
  rds_password = var.create_rds ? var.rds_master_password : var.existing_rds_password

  redis_endpoint = var.create_elasticache ? module.elasticache[0].endpoint : var.existing_redis_endpoint

  # S3 bucket names with random suffix
  s3_bucket_names = [for suffix in var.s3_bucket_suffixes : "${var.s3_bucket_prefix}-${suffix}"]

  # SSH key - use created key or existing key name
  ssh_key_name = var.create_ssh_key ? aws_key_pair.generated[0].key_name : var.existing_key_name

}

# -----------------------------------------------------------------------------
# Random ID for S3 bucket uniqueness
# -----------------------------------------------------------------------------

# resource "random_id" "bucket_suffix" {
#   byte_length = 3
# }

# -----------------------------------------------------------------------------
# SSH Key Pair (Optional - Create New)
# -----------------------------------------------------------------------------

resource "tls_private_key" "ssh" {
  count     = var.create_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  count      = var.create_ssh_key ? 1 : 0
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.ssh[0].public_key_openssh

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-key"
  })
}

resource "local_file" "private_key" {
  count           = var.create_ssh_key ? 1 : 0
  content         = tls_private_key.ssh[0].private_key_pem
  filename        = "${path.module}/keys/${local.name_prefix}-key.pem"
  file_permission = "0400"
}

# -----------------------------------------------------------------------------
# VPC Module
# -----------------------------------------------------------------------------

module "vpc" {
  count  = var.create_vpc ? 1 : 0
  source = "../../modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Security Groups Module
# -----------------------------------------------------------------------------

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix       = local.name_prefix
  vpc_id            = local.vpc_id
  enable_ssh        = var.enable_ssh
  ssh_allowed_cidrs = var.ssh_allowed_cidrs

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM Role for EC2
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.common_tags
}

# SSM access for fetching .env parameters
data "aws_iam_policy_document" "ssm_access" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project}/*"
    ]
  }
}

resource "aws_iam_policy" "ssm_access" {
  name   = "${local.name_prefix}-ssm-access"
  policy = data.aws_iam_policy_document.ssm_access.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 access
data "aws_iam_policy_document" "s3_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_prefix}-*",
      "arn:aws:s3:::${var.s3_bucket_prefix}-*/*"
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "${local.name_prefix}-s3-access"
  policy = data.aws_iam_policy_document.s3_access.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# CloudWatch Logs access
data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_logs" {
  name   = "${local.name_prefix}-cloudwatch-logs"
  policy = data.aws_iam_policy_document.cloudwatch_logs.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# EC2 Module
# -----------------------------------------------------------------------------

module "ec2" {
  source = "../../modules/ec2"

  name_prefix          = local.name_prefix
  instance_type        = var.ec2_instance_type
  subnet_id            = local.public_subnet_ids[0]
  security_group_ids   = [module.security_groups.ec2_security_group_id]
  key_name             = local.ssh_key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  root_volume_size     = var.ec2_root_volume_size
  root_volume_type     = var.ec2_root_volume_type
  create_eip           = var.create_eip
  ubuntu_ami_owner     = var.ubuntu_ami_owner

  codedeploy_tags = var.create_codedeploy ? {
    for app in var.codedeploy_apps : "cdg-${app}" => "${local.name_prefix}-${app}"
  } : {}

  user_data = templatefile("${path.module}/user-data.sh", {
    environment    = var.environment
    project        = var.project
    rds_endpoint   = local.rds_endpoint
    rds_username   = local.rds_username
    rds_password   = local.rds_password
    redis_endpoint = local.redis_endpoint
    aws_region     = var.aws_region
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# RDS Module
# -----------------------------------------------------------------------------

module "rds" {
  count  = var.create_rds ? 1 : 0
  source = "../../modules/rds"

  name_prefix             = local.name_prefix
  subnet_ids              = local.data_subnet_ids
  security_group_ids      = [module.security_groups.rds_security_group_id]
  instance_class          = var.rds_instance_class
  engine_version          = var.rds_engine_version
  allocated_storage       = var.rds_allocated_storage
  max_allocated_storage   = var.rds_max_allocated_storage
  database_name           = var.rds_database_name
  master_username         = var.rds_master_username
  master_password         = var.rds_master_password
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window
  multi_az                = var.rds_multi_az
  deletion_protection     = var.rds_deletion_protection

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# ElastiCache Module
# -----------------------------------------------------------------------------

module "elasticache" {
  count  = var.create_elasticache ? 1 : 0
  source = "../../modules/elasticache"

  name_prefix        = local.name_prefix
  subnet_ids         = local.data_subnet_ids
  security_group_ids = [module.security_groups.redis_security_group_id]
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_cache_nodes
  engine_version     = var.redis_engine_version
  maintenance_window = var.redis_maintenance_window

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# S3 Module
# -----------------------------------------------------------------------------

module "s3" {
  count  = var.create_s3 ? 1 : 0
  source = "../../modules/s3"

  bucket_names               = local.s3_bucket_names
  enable_versioning          = true
  enable_lifecycle           = true
  artifact_expiration_days   = var.s3_artifact_expiration_days
  noncurrent_expiration_days = var.s3_noncurrent_expiration_days

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CodeDeploy
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "codedeploy_assume" {
  count = var.create_codedeploy ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  count = var.create_codedeploy ? 1 : 0

  name               = "${local.name_prefix}-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  count = var.create_codedeploy ? 1 : 0

  role       = aws_iam_role.codedeploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_app" "main" {
  count = var.create_codedeploy ? 1 : 0

  name             = "${local.name_prefix}-apps"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "apps" {
  for_each = var.create_codedeploy ? toset(var.codedeploy_apps) : []

  app_name              = aws_codedeploy_app.main[0].name
  deployment_group_name = "${local.name_prefix}-${each.value}"
  service_role_arn      = aws_iam_role.codedeploy[0].arn

  deployment_config_name = "CodeDeployDefault.OneAtATime"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "cdg-${each.value}"
      type  = "KEY_AND_VALUE"
      value = "${local.name_prefix}-${each.value}"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# -----------------------------------------------------------------------------
# Monitoring Module
# -----------------------------------------------------------------------------

module "monitoring" {
  count  = var.enable_monitoring && var.alarm_email != "" ? 1 : 0
  source = "../../modules/monitoring"

  name_prefix     = local.name_prefix
  ec2_instance_id = module.ec2.instance_id
  alarm_email     = var.alarm_email
  cpu_threshold   = var.cpu_threshold

  tags = local.common_tags
}
