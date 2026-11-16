terraform {
  backend "s3" {
    bucket       = "test-memos-terraform-state-435059220418"
    key          = "test-memos/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
