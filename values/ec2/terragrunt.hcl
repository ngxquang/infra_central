remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "sandbox-as1-state-tf"
    key            = "${path_relative_to_include()}/runner/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}

terraform {
  source = "../../stack/ec2"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "alb" {
  config_path = "../alb"
}

inputs = {
  region    = "ap-south-1"
  subnet_id = dependency.vpc.outputs.private_subnet_ids[0]

  vpc_id   = dependency.vpc.outputs.vpc_id
  vpc_cidr = dependency.vpc.outputs.vpc_cidr

  ebs_disk_size = 100

  prefix = "digi-easy"
  suffix = "qa"

  instance_type = "t3.large"
  key_name      = "digi-easy-qa-key"

  target_group_arns  = [dependency.alb.outputs.target_group_arn]

  workspace_ebs_name = "digi-easy-qa-workspace"
  workspace_ebs_size = 50

  gitea_repo_url          = "https://workspace.digital-easy.link:5000/internal/infra_central"
  ssm_gitea_username_path = "/ec2/gitea/username"
  ssm_gitea_token_path    = "/ec2/gitea/token"

  tags = {
    Project     = "digi-easy"
    Environment = "qa"
    ManagedBy   = "terraform"
  }
}
