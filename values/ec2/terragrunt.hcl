remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "ngxquang-as1-state-tf"
    key            = "values/ec2/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
  }
}

terraform {
  source = "../../stack/ec2"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region         = "ap-southeast-1"
  instance_name  = "dev-ec2"
  instance_type  = "t3.small"
  key_name       = "tf-test-keypair"

  vpc_id    = dependency.vpc.outputs.vpc_id
  subnet_id = dependency.vpc.outputs.public_subnet_id

  inbound_ports = [22, 80, 443, 8443]
}