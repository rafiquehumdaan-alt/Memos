terraform {
  backend "s3" {
    bucket       = "memos-terraform-state-435059220418"
    key          = "memos/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
