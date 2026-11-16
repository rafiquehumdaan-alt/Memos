output "ecr_repository_url" {
  description = "URL of the Memos ECR repository"
  value       = aws_ecr_repository.memos.repository_url
}
