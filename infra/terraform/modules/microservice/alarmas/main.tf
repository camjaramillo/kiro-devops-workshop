# main.tf - Módulo CloudWatch Alarmas
# Crea alarmas de CloudWatch para errores, latencia, throttles, DLQ y mensajes envejecidos

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # ARN del SNS topic: usa el existente o el recién creado
  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : (
    var.create_sns_topic ? [aws_sns_topic.alarmas[0].arn] : []
  )

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# ------------------------------------------------------------------
# SNS: Topic para notificaciones (opcional)
# ------------------------------------------------------------------

resource "aws_sns_topic" "alarmas" {
  count = var.create_sns_topic ? 1 : 0
  name  = "${local.name_prefix}-alarmas"
  tags  = local.common_tags
}

# ------------------------------------------------------------------
# LAMBDA: Alarmas de errores
# ------------------------------------------------------------------

# Alarma: errores de invocación de Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  alarm_description   = "Errores en la función Lambda ${var.lambda_function_name}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.lambda_error_period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# Alarma: latencia (duración) de Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.name_prefix}-lambda-duration"
  alarm_description   = "Latencia elevada en Lambda ${var.lambda_function_name} (>${var.lambda_duration_threshold_ms}ms)"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p95"
  threshold           = var.lambda_duration_threshold_ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# Alarma: throttles de Lambda (límite de concurrencia alcanzado)
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name_prefix}-lambda-throttles"
  alarm_description   = "Throttles en Lambda ${var.lambda_function_name}: límite de concurrencia alcanzado"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = var.lambda_throttle_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# ------------------------------------------------------------------
# API GATEWAY: Alarmas de errores y latencia
# ------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  count = var.api_gateway_id != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-api-5xx-errors"
  alarm_description   = "Errores 5xx en API Gateway ${var.api_gateway_id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = var.api_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_gateway_id
    Stage = var.api_gateway_stage
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# Alarma: latencia del API Gateway (p99)
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  count = var.api_gateway_id != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-api-latency"
  alarm_description   = "Latencia elevada en API Gateway (>${var.api_latency_threshold_ms}ms en p99)"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "IntegrationLatency"
  namespace           = "AWS/ApiGateway"
  period              = 60
  extended_statistic  = "p99"
  threshold           = var.api_latency_threshold_ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_gateway_id
    Stage = var.api_gateway_stage
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# ------------------------------------------------------------------
# SQS: Alarmas de mensajes en DLQ y mensajes envejecidos
# ------------------------------------------------------------------

# Alarma crítica: cualquier mensaje que llegue a la DLQ indica un fallo
resource "aws_cloudwatch_metric_alarm" "dlq_messages_visible" {
  count = var.dlq_queue_name != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-dlq-messages"
  alarm_description   = "Mensajes en Dead Letter Queue ${var.dlq_queue_name}: procesamiento fallido"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = var.dlq_messages_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.dlq_queue_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = merge(local.common_tags, { Severity = "critical" })
}

# Alarma: mensajes envejecidos en la cola principal (consumidor lento o caído)
resource "aws_cloudwatch_metric_alarm" "queue_message_age" {
  count = var.sqs_queue_name != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-queue-message-age"
  alarm_description   = "Mensajes envejecidos en cola ${var.sqs_queue_name}: posible consumidor caído"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.queue_age_threshold_seconds
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.sqs_queue_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# ------------------------------------------------------------------
# Dashboard de CloudWatch: vista unificada de todas las métricas
# ------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "microservice" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type       = "metric"
        x          = 0; y = 0; width = 12; height = 6
        properties = {
          title  = "Lambda - Errores y Throttles"
          period = 60
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name, { stat = "Sum", color = "#d62728" }],
            ["AWS/Lambda", "Throttles", "FunctionName", var.lambda_function_name, { stat = "Sum", color = "#ff7f0e" }],
          ]
        }
      },
      {
        type       = "metric"
        x          = 12; y = 0; width = 12; height = 6
        properties = {
          title  = "Lambda - Latencia (p95)"
          period = 60
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "p95", color = "#1f77b4" }],
          ]
        }
      },
      {
        type       = "metric"
        x          = 0; y = 6; width = 12; height = 6
        properties = {
          title  = "SQS - Mensajes en DLQ"
          period = 60
          metrics = var.dlq_queue_name != "" ? [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_queue_name, { stat = "Sum", color = "#d62728" }],
          ] : []
        }
      },
      {
        type       = "metric"
        x          = 12; y = 6; width = 12; height = 6
        properties = {
          title  = "API Gateway - Errores 5xx y Latencia"
          period = 60
          metrics = var.api_gateway_id != "" ? [
            ["AWS/ApiGateway", "5XXError", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage, { stat = "Sum", color = "#d62728" }],
            ["AWS/ApiGateway", "IntegrationLatency", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage, { stat = "p99", color = "#1f77b4" }],
          ] : []
        }
      },
    ]
  })
}
