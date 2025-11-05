terraform {
  required_version = ">= 1.6"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.name}-subnets" }
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-sg"
  description = "RDS PostgreSQL access"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-sg" }
}

resource "aws_security_group_rule" "ingress_cidrs" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.rds.id
}

resource "aws_security_group_rule" "ingress_sgs" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = each.value
}

resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!#$%&()*+,-.:;<=>?[]^_{|}~" # exclude '/', '@', '"' which RDS disallows
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = var.parameter_group_family
  description = "Parameter group for ${var.name}"
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  username       = var.username
  password       = random_password.db.result
  db_name        = var.db_name

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_throughput    = var.storage_throughput

  backup_retention_period    = var.backup_retention
  maintenance_window         = var.maintenance_window
  backup_window              = var.backup_window
  deletion_protection        = var.deletion_protection
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  monitoring_interval          = var.monitoring_interval
  performance_insights_enabled = var.performance_insights_enabled

  apply_immediately = true

  parameter_group_name = aws_db_parameter_group.this.name

  skip_final_snapshot = true

  tags = { Name = var.name }
}

resource "aws_secretsmanager_secret" "db" {
  count       = var.create_secret_manager ? 1 : 0
  name        = "${var.name}-credentials"
  description = "Credentials + endpoint for ${var.name}"
}

resource "aws_secretsmanager_secret_version" "db" {
  count     = var.create_secret_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.db[0].id
  secret_string = jsonencode({
    username = var.username,
    password = random_password.db.result,
    host     = aws_db_instance.this.address,
    port     = aws_db_instance.this.port,
    dbname   = var.db_name
  })
}
