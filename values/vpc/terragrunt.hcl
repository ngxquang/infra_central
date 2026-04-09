remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "sandbox-as1-state-tf"
    key            = "values/vpc/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}

terraform {
  source = "../../stack/vpc"
}

inputs = {
  region = "ap-south-1"
  prefix = "digi-easy"

  number_public_subnets  = 2
  number_private_subnets = 2

  vpc_cidr = "10.0.0.0/16"

  enable_nat_gateway = true
  private_domain     = "digi-easy.internal"

  tags = {
    Project     = "digi-easy"
    Environment = "qa"
    ManagedBy   = "terraform"
  }

  # ipam_pool_id        = "ipam-pool-05d0bf3e999f82e78"
  # ipam_netmask_length = 16
}