resource "aws_db_subnet_group" "memos" {
  name       = var.name
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "PostgreSQL access for Memos"
  vpc_id      = var.vpc_id
}

resource "aws_db_instance" "memos" {
  identifier                  = var.name
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  multi_az                    = false
  publicly_accessible         = false
  backup_retention_period     = 1
  username                    = "memos_admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.memos.name
  vpc_security_group_ids      = [aws_security_group.database.id]
  skip_final_snapshot         = true
}

resource "aws_vpc_security_group_ingress_rule" "database_from_ecs" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = var.ecs_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_secretsmanager_secret" "app" {
  name = "${var.name}/database"
}