variable "region" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "subnet_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "inbound_ports" {
  type    = list(number)
  default = [22, 80, 443, 8443]
}

variable "allowed_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}