variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block — ALB SG outbound is restricted to this"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB (at least 2 AZs)"
  type        = list(string)
}

variable "prefix" {
  description = "Prefix resource names - Project name"
  type        = string
}

variable "suffix" {
  description = "Suffix resource names - Environment"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

variable "waf_web_acl_arn" {
  description = "ARN WAF to associate with the ALB"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path used by the ALB health check"
  type        = string
  default     = "/"
}

variable "acm_certificate_domain" {
  description = "Domain name of the ACM certificate to attach to the HTTPS listener"
  type        = string
  default     = "digital-easy.link"
}
