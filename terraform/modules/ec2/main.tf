# =============================================================================
# EC2 Module
# =============================================================================

# -----------------------------------------------------------------------------
# Data: Latest Ubuntu 22.04 AMI
# -----------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ubuntu_ami_owner]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# EC2 Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "main" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name != "" ? var.key_name : null
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.root_volume_encrypted
    delete_on_termination = true
  }

  user_data = var.user_data != "" ? var.user_data : null

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  monitoring = var.enable_monitoring

  tags = merge(
    var.tags,
    var.codedeploy_tags,
    { Name = "${var.name_prefix}-ec2" }
  )
}

# -----------------------------------------------------------------------------
# Elastic IP
# -----------------------------------------------------------------------------

resource "aws_eip" "main" {
  count  = var.create_eip ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eip"
  })
}

resource "aws_eip_association" "main" {
  count = var.create_eip ? 1 : 0

  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main[0].id
}
