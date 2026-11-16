resource "aws_iam_role" "ecs_execution" {
  name = "memos-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "memos-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "memos_database_secret" {
  name = "memos-database-secret"
  role = aws_iam_role.ecs_execution.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.app_secret_arn
    }]
  })
}

resource "aws_iam_role" "memos_setup" {
  name               = "memos-setup"
  assume_role_policy = aws_iam_role.ecs_execution.assume_role_policy
}

resource "aws_iam_role_policy" "memos_setup" {
  name = "memos-setup-secrets"
  role = aws_iam_role.memos_setup.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.admin_secret_arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue"]
        Resource = [var.app_secret_arn, var.website_secret_arn]
      }
    ]
  })
}