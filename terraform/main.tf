terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

resource "aws_ecr_repository" "memos" {
  name                 = "memos"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "memos"
    Project = "Memos"
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"

  public_subnet_a_cidr  = "10.0.1.0/24"
  public_subnet_b_cidr  = "10.0.2.0/24"
  private_subnet_a_cidr = "10.0.11.0/24"
  private_subnet_b_cidr = "10.0.12.0/24"

  availability_zone_a = "eu-west-2a"
  availability_zone_b = "eu-west-2b"
}

module "iam" {
  source             = "./modules/iam"
  app_secret_arn     = module.database.app_secret_arn
  admin_secret_arn   = module.database.admin_secret_arn
  website_secret_arn = module.ecs.website_secret_arn
}

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = aws_acm_certificate_validation.memos.certificate_arn
}

module "ecs" {
  source = "./modules/ecs"

  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  alb_security_group_id      = module.alb.security_group_id
  target_group_arn           = module.alb.target_group_arn
  database_security_group_id = module.database.security_group_id
  app_secret_arn             = module.database.app_secret_arn
  setup_task_role_arn        = module.iam.setup_task_role_arn
  database_address           = module.database.address
  admin_secret_arn           = module.database.admin_secret_arn

  ecr_repository_url = aws_ecr_repository.memos.repository_url

  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
}

module "database" {
  source = "./modules/database"

  ecs_security_group_id = module.ecs.task_security_group_id

  name               = "memos"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}
