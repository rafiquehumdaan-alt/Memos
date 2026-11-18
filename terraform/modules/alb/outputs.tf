output "security_group_id" {
  description = "Security group ID of the Memos ALB"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the Memos ECS target group"
  value       = aws_lb_target_group.ecs.arn

  depends_on = [aws_lb_listener.https]
}

output "alb_dns_name" {
  description = "DNS name of the Memos Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the Memos Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the Memos Application Load Balancer"
  value       = aws_lb.main.arn
}