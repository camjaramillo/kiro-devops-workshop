# outputs.tf - Salidas del módulo DynamoDB

output "table_name" {
  description = "Nombre de la tabla DynamoDB"
  value       = aws_dynamodb_table.microservice.name
}

output "table_arn" {
  description = "ARN de la tabla DynamoDB"
  value       = aws_dynamodb_table.microservice.arn
}

output "table_id" {
  description = "ID de la tabla DynamoDB"
  value       = aws_dynamodb_table.microservice.id
}

output "table_hash_key" {
  description = "Partition key de la tabla"
  value       = aws_dynamodb_table.microservice.hash_key
}

output "table_range_key" {
  description = "Sort key de la tabla (vacío si no se configuró)"
  value       = aws_dynamodb_table.microservice.range_key
}
