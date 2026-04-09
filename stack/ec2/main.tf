provider "aws" {
  region = var.region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnet" "target_subnet" {
  id = var.subnet_id
}

###############################
# Naming & common locals
###############################
locals {
  name_prefix   = "${var.prefix}-${var.suffix}"
  instance_name = local.name_prefix
  sg_name       = "${local.name_prefix}-sg"
  has_workspace = var.workspace_ebs_name != ""
}

###############################
# IAM Role for SSM access
###############################
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_ssm_read" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:*:parameter${var.ssm_gitea_username_path}",
      "arn:aws:ssm:${var.region}:*:parameter${var.ssm_gitea_token_path}",
    ]
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.instance_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${local.instance_name}-ec2-role"
  })
}

resource "aws_iam_role_policy" "ec2_ssm_read" {
  name   = "${local.instance_name}-ssm-read"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_ssm_read.json
}

# Only created when workspace EBS is configured — allows the instance to
# self-attach the data volume after a replacement/launch by the ASG.
data "aws_iam_policy_document" "ec2_ebs_attach" {
  count = local.has_workspace ? 1 : 0

  statement {
    sid       = "DescribeVolumes"
    actions   = ["ec2:DescribeVolumes"]
    resources = ["*"]
  }

  statement {
    sid     = "AttachWorkspaceVolume"
    actions = ["ec2:AttachVolume"]
    resources = [
      aws_ebs_volume.workspace[0].arn,
      "arn:aws:ec2:${var.region}:*:instance/*",
    ]
  }
}

resource "aws_iam_role_policy" "ec2_ebs_attach" {
  count  = local.has_workspace ? 1 : 0
  name   = "${local.instance_name}-ebs-attach"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_ebs_attach[0].json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.instance_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "ec2_sg" {
  name   = local.sg_name
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "All traffic from within the VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = local.sg_name
  })
}

resource "aws_launch_template" "ec2_launch_template" {
  name_prefix   = "${local.instance_name}-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.ebs_disk_size
      volume_type = "gp3"
    }
  }

  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups            = [aws_security_group.ec2_sg.id]
    subnet_id                  = data.aws_subnet.target_subnet.id
  }

  user_data = base64encode(templatefile("${path.module}/user_data/init.sh.tpl", {
    workspace_ebs_name      = var.workspace_ebs_name
    region                  = var.region
    gitea_repo_url          = var.gitea_repo_url
    ssm_gitea_username_path = var.ssm_gitea_username_path
    ssm_gitea_token_path    = var.ssm_gitea_token_path
  }))

  tags = merge(var.tags, {
    Name = "${local.instance_name}-template"
  })

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = local.instance_name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${local.instance_name}-root"
    })
  }
}

###############################
# Workspace EBS (persistent data volume — never destroyed by Terraform)
# The ASG instance self-attaches this volume via user_data on every launch.
###############################
resource "aws_ebs_volume" "workspace" {
  count             = local.has_workspace ? 1 : 0
  availability_zone = data.aws_subnet.target_subnet.availability_zone
  size              = var.workspace_ebs_size
  type              = "gp3"

  tags = merge(var.tags, {
    Name = var.workspace_ebs_name
  })

  lifecycle {
    prevent_destroy = true
  }
}

###############################
# Auto Scaling Group
###############################
resource "aws_autoscaling_group" "main" {
  name                = "${local.instance_name}-asg"
  vpc_zone_identifier = [var.subnet_id]
  target_group_arns   = var.target_group_arns

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # EC2 health check: ASG replaces the instance if it becomes unhealthy
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

  # Rolling refresh when launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = local.instance_name })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

###############################
# Outputs
###############################
output "asg_name" {
  value = aws_autoscaling_group.main.name
}

output "asg_arn" {
  value = aws_autoscaling_group.main.arn
}

output "workspace_ebs_id" {
  value = local.has_workspace ? aws_ebs_volume.workspace[0].id : null
}