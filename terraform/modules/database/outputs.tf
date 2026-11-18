output "security_group_id" {
  value = aws_security_group.database.id
}

output "address" {
  value = aws_db_instance.memos.address
}

output "admin_secret_arn" {
  value = one(aws_db_instance.memos.master_user_secret).secret_arn
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "identifier" {
  value = aws_db_instance.memos.identifier
}