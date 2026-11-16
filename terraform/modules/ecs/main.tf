resource "aws_ecs_cluster" "main" {
  name = "memos-cluster"

  tags = {
    Name = "memos-cluster"
  }
}

resource "aws_security_group" "ecs" {
  name        = "memos-ecs-sg"
  description = "Security group for Memos ECS tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name = "memos-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = var.alb_security_group_id

  from_port   = 5230
  to_port     = 5230
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/memos-task"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "app" {
  family                   = "memos-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "memos"
      image     = "${var.ecr_repository_url}:latest"
      essential = true

      environment = [
        {
          name  = "MEMOS_DRIVER"
          value = "postgres"
        }
      ]

      secrets = [
        {
          name      = "MEMOS_DSN"
          valueFrom = var.app_secret_arn
        }
      ]

      portMappings = [
        {
          containerPort = 5230
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = "eu-west-2"
          "awslogs-stream-prefix" = "memos"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name                          = "memos-service"
  cluster                       = aws_ecs_cluster.main.id
  task_definition               = aws_ecs_task_definition.app.arn
  desired_count                 = 0
  availability_zone_rebalancing = "ENABLED"
  launch_type                   = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "memos"
    container_port   = 5230
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 4
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [min_capacity]
  }
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "memos-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_database" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = var.database_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_secretsmanager_secret" "website_admin" {
  name = "memos/website-admin"
}

resource "aws_ecs_task_definition" "setup" {
  family                   = "memos-setup"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = var.ecs_execution_role_arn
  task_role_arn      = var.setup_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "setup"
      image     = "${var.ecr_repository_url}:setup-latest"
      essential = true

      environment = [
        {
          name  = "DB_HOST"
          value = var.database_address
        },
        {
          name  = "ADMIN_SECRET"
          value = var.admin_secret_arn
        },
        {
          name  = "APP_SECRET"
          value = var.app_secret_arn
        },
        {
          name  = "WEBSITE_SECRET"
          value = aws_secretsmanager_secret.website_admin.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = "eu-west-2"
          "awslogs-stream-prefix" = "setup"
        }
      }
    }
  ])
}