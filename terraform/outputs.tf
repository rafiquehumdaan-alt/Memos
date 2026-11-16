output "ecr_repository_url" {
  description = "URL of the RONIN ECR repository"
  value       = aws_ecr_repository.ronin.repository_url
}
