variable "github_repository_subject" {
  description = "GitHub OIDC subject allowed to deploy the test stack"
  type        = string
}

variable "github_actions_role_name" {
  description = "Name of the IAM role assumed by Memos GitHub Actions workflows"
  type        = string
  default     = "memos-github-actions"
}

variable "github_oidc_provider_url" {
  description = "GitHub Actions OIDC issuer URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}
