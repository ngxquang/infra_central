remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "sandbox-as1-state-tf"
    key            = "values/vpc/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
  }
}

terraform {
  source = "../../stack/vpc"
}

inputs = {
  region   = "ap-southeast-1"
  vpc_cidr = "10.0.0.0/16"
  prefix   = "dev"

  azs = [
    "ap-southeast-1a"
  ]
}

