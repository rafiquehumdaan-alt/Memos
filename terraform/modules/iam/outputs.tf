output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_execution.arn
}

output "setup_task_role_arn" {
  value = aws_iam_role.memos_setup.arn
}