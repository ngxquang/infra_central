
###############################
# Variables
###############################
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "region" {
  description = "AWS Region to deploy into"
  type        = string
}

variable "number_public_subnets" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2
}

variable "number_private_subnets" {
  description = "Number of private subnets to create"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ipam_pool_id" {
  description = "Optional IPAM pool ID."
  type        = string
  default     = ""
}

variable "ipam_netmask_length" {
  description = "Netmask length for IPAM allocation"
  type        = number
  default     = 0
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "private_domain" {
  description = "Internal domain name for the Route 53 private hosted zone."
  type        = string
  default     = ""
}
