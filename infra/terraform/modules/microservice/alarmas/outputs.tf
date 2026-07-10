# outputs.tf - Salidas del módulo CloudWatch Alarmas

output "lambda_errors_alarm_arn" {
  description = "ARN de la alarma de errores de Lambda"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.arn
}

output "lambda_duration_alarm_arn" {
  description = "ARN de la alarma de latencia de Lambda"
  value       = aws_cloudwatch_metric_alarm.lambda_duration.arn
}

output "lambda_throttles_alarm_arn" {
  description = "ARN de la alarma de throttles de Lambda"
  value       = aws_cloudwatch_metric_alarm.lambda_throttles.arn
}

output "api_5xx_alarm_arn" {
  description = "ARN de la alarma de errores 5xx de API Gateway"
  value       = length(aws_cloudwatch_metric_alarm.api_5xx_errors) > 0 ? aws_cloudwatch_metric_alarm.api_5xx_errors[0].arn : ""
}

output "api_latency_alarm_arn" {
  description = "ARN de la alarma de latencia de API Gateway"
  value       = length(aws_cloudwatch_metric_alarm.api_latency) > 0 ? aws_cloudwatch_metric_alarm.api_latency[0].arn : ""
}

output "dlq_alarm_arn" {
  description = "ARN de la alarma de mensajes en DLQ"
  value       = length(aws_cloudwatch_metric_alarm.dlq_messages_visible) > 0 ? aws_cloudwatch_metric_alarm.dlq_messages_visible[0].arn : ""
}

output "queue_age_alarm_arn" {
  description = "ARN de la alarma de mensajes envejecidos en la cola principal"
  value       = length(aws_cloudwatch_metric_alarm.queue_message_age) > 0 ? aws_cloudwatch_metric_alarm.queue_message_age[0].arn : ""
}

output "sns_topic_arn" {
  description = "ARN del SNS topic de notificaciones (vacío si se usó uno externo)"
  value       = var.create_sns_topic ? aws_sns_topic.alarmas[0].arn : var.sns_topic_arn
}

output "dashboard_name" {
  description = "Nombre del dashboard de CloudWatch"
  value       = aws_cloudwatch_dashboard.microservice.dashboard_name
}
