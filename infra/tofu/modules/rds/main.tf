resource "aws_db_subnet_group" "main" {
  name       = "${var.namespace}-rds-subnets"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.namespace}-rds-subnets" }
}

resource "aws_db_parameter_group" "postgres" {
  name        = "${var.namespace}-pg15"
  family      = "postgres15"
  description = "PostgreSQL 15 with pgvector"

  parameter {
    name  = "shared_preload_libraries"
    value = "pgvector"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.namespace}-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name                = "safehire"
  username               = "safehire"
  password               = var.db_password
  port                   = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  parameter_group_name   = aws_db_parameter_group.postgres.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot    = var.environment != "production"
  deletion_protection    = var.environment == "production"

  tags = { Name = "${var.namespace}-postgres" }
}

resource "random_password" "schema_password" {
  length  = 16
  special = false
}

output "endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}

output "db_username" {
  value = aws_db_instance.postgres.username
}
