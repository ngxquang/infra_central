
# Suggested variable definitions
variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block — used to allow all inbound traffic from within the VPC"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to deploy the EC2 instance into"
  type        = string
}

variable "prefix" {
  description = "Prefix for all resource names (e.g. project name)"
  type        = string
}

variable "suffix" {
  description = "Suffix for all resource names (e.g. environment: qa, prod)"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all taggable resources"
  type        = map(string)
  default     = {}
}

variable "ingress_rules" {
  description = "List of additional ingress rules for the EC2 security group. The VPC all-traffic rule is always included."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "key_name" {
  type    = string
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "ebs_disk_size" {
  type    = number
  default = 100
}

variable "workspace_ebs_name" {
  description = "Name tag for the optional workspace EBS volume. Leave empty to skip creation."
  type        = string
  default     = ""
}

variable "workspace_ebs_size" {
  description = "Size (GiB) of the workspace EBS volume"
  type        = number
  default     = 50
}

variable "target_group_arns" {
  description = "List of ALB target group ARNs the ASG should register with"
  type        = list(string)
  default     = []
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 1
}

variable "gitea_repo_url" {
  description = "Gitea repository URL"
  type        = string
}

variable "ssm_gitea_username_path" {
  description = "SSM Parameter Store path for the Gitea username"
  type        = string
  default     = "/ec2/gitea/username"
}

variable "ssm_gitea_token_path" {
  description = "SSM Parameter Store path for the Gitea access token"
  type        = string
  default     = "/ec2/gitea/token"
}
