variable "alb_arn_suffix" {
  description = "ARN suffix of the Memos Application Load Balancer used in CloudWatch metrics"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the Memos ECS target group used in CloudWatch metrics"
  type        = string
}

variable "db_instance_identifier" {
  description = "Identifier of the Memos RDS instance"
  type        = string
}