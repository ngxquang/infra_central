provider "aws" {
  region = var.region
}

###############################
# Data
###############################
data "aws_availability_zones" "available" {}

###############################
# Local Logic
###############################
locals {
  use_ipam_vpc = var.ipam_pool_id != "" && var.ipam_netmask_length != 0

  az_list  = data.aws_availability_zones.available.names
  az_count = length(local.az_list)

  total_subnets        = var.number_public_subnets + var.number_private_subnets
  subnet_newbits       = ceil(log(local.total_subnets, 2))
  public_subnet_count  = var.number_public_subnets
  private_subnet_count = var.number_private_subnets
}

###############################
# VPC
###############################
resource "aws_vpc" "main" {
  cidr_block          = local.use_ipam_vpc ? null : var.vpc_cidr
  
  ipv4_ipam_pool_id   = local.use_ipam_vpc ? var.ipam_pool_id : null
  ipv4_netmask_length = local.use_ipam_vpc ? var.ipam_netmask_length : null

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc"
  })
}

###############################
# Subnets
###############################
resource "aws_subnet" "public" {
  count                   = local.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, count.index)
  availability_zone       = local.az_list[count.index % local.az_count]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = local.private_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, count.index + local.public_subnet_count)
  availability_zone = local.az_list[count.index % local.az_count]

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}

###############################
# Internet Gateway
###############################
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-igw"
  })
}

###############################
# NAT Gateway
###############################
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.prefix}-nat-eip"
  })

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.prefix}-nat"
  })

  depends_on = [aws_internet_gateway.gw]
}

###############################
# Route Tables & Associations
###############################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-rt-public"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-rt-private"
  })
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

###############################
# Private Hosted Zone
###############################
resource "aws_route53_zone" "private" {
  count = var.private_domain != "" ? 1 : 0
  name  = var.private_domain

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-${var.private_domain}"
  })
}

resource "aws_route_table_association" "public" {
  count          = local.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = local.private_subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

###############################
# Outputs
###############################
output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnets_cidrs" {
  value = aws_subnet.public[*].cidr_block
}

output "private_subnets_cidrs" {
  value = aws_subnet.private[*].cidr_block
}

output "nat_gateway_id" {
  value = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "nat_eip" {
  value = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "private_hosted_zone_id" {
  value = var.private_domain != "" ? aws_route53_zone.private[0].zone_id : null
}

output "private_domain" {
  value = var.private_domain != "" ? var.private_domain : null
}
