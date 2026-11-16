variable "vpc_id" {
  description = "ID of the RONIN VPC"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the RONIN ALB"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the RONIN ECR repository"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets for the RONIN ECS tasks"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "database_security_group_id" {
  type = string
}

variable "app_secret_arn" {
  type = string
}

variable "setup_task_role_arn" {
  type = string
}

variable "database_address" {
  type = string
}

variable "admin_secret_arn" {
  type = string
}