remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket  = "sandbox-as1-state-tf"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}

terraform {
  source = "../../stack/alb"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region = "ap-south-1"

  vpc_id   = dependency.vpc.outputs.vpc_id
  vpc_cidr = dependency.vpc.outputs.vpc_cidr

  public_subnet_ids = dependency.vpc.outputs.public_subnet_ids

  prefix = "digi-easy"
  suffix = "qa"

  health_check_path = "/"

  acm_certificate_domain = "digital-easy.link"

  waf_web_acl_arn = "arn:aws:wafv2:ap-south-1:736052310305:regional/webacl/ALBWhitelistWebACL/94738143-21e2-4d3d-95d2-61f836225993"

  tags = {
    Project     = "digi-easy"
    Environment = "qa"
    ManagedBy   = "terraform"
  }
}
