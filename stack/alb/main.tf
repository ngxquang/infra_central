provider "aws" {
  region = var.region
}

###############################
# ALB Security Group
###############################
locals {
  name_prefix = "${var.prefix}-${var.suffix}"
  alb_name    = "${local.name_prefix}-alb"
  sg_name     = "${local.name_prefix}-alb-sg"
  tg_name     = "${local.name_prefix}-alb-tg"
}

resource "aws_security_group" "alb_sg" {
  name        = local.sg_name
  description = "Security group for ${local.alb_name} ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from public internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from public internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound to VPC only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = local.sg_name
  })
}

###############################
# ACM Certificate
###############################
data "aws_acm_certificate" "main" {
  domain      = var.acm_certificate_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

###############################
# Application Load Balancer
###############################
resource "aws_lb" "main" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, {
    Name = local.alb_name
  })
}

###############################
# ALB Target Group
###############################
resource "aws_lb_target_group" "codeserver" {
  name        = local.tg_name
  port        = 8443
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name = local.tg_name
  })
}

###############################
# Listener - HTTP :80
###############################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

###############################
# Listener - HTTPS :443
###############################
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.codeserver.arn
  }
}

###############################
# WAF Association
###############################
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.waf_web_acl_arn != "" ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_web_acl_arn
}

###############################
# Outputs
###############################
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_name" {
  value = aws_lb.main.name
}

output "target_group_arn" {
  value = aws_lb_target_group.codeserver.arn
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}
