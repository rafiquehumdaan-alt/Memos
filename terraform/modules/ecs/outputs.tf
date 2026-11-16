output "task_security_group_id" {
  value = aws_security_group.ecs.id
}

output "website_secret_arn" {
  value = aws_secretsmanager_secret.website_admin.arn
}