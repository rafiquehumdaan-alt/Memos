output "alb_arn_suffix" {
  description = "ARN suffix of the Memos Application Load Balancer"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the Memos ECS target group"
  value       = aws_lb_target_group.ecs.arn_suffix
}