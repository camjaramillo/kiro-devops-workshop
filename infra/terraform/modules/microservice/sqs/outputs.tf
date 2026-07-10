# outputs.tf - Salidas del módulo SQS + DLQ

output "queue_id" {
  description = "URL de la cola SQS principal (usado como ID)"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "ARN de la cola SQS principal"
  value       = aws_sqs_queue.main.arn
}

output "queue_url" {
  description = "URL de la cola SQS principal"
  value       = aws_sqs_queue.main.url
}

output "queue_name" {
  description = "Nombre de la cola SQS principal"
  value       = aws_sqs_queue.main.name
}

output "dlq_id" {
  description = "URL de la Dead Letter Queue (usado como ID)"
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "ARN de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_name" {
  description = "Nombre de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.name
}
