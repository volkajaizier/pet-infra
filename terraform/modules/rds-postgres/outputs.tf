output "address" { value = aws_db_instance.this.address }
output "port" { value = aws_db_instance.this.port }
output "db_name" { value = aws_db_instance.this.db_name }
output "security_group_id" { value = aws_security_group.rds.id }
output "secret_arn" {
  value       = try(aws_secretsmanager_secret.db[0].arn, null)
  description = "Secrets Manager secret ARN with credentials and endpoint"
}
