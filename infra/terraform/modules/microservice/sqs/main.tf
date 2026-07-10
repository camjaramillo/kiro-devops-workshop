# main.tf - Módulo SQS + Dead Letter Queue
# Crea la cola principal SQS, la DLQ y el event source mapping hacia Lambda

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
  # Los nombres FIFO deben terminar en .fifo
  queue_suffix = var.enable_fifo ? ".fifo" : ""
  queue_name   = var.queue_name != "" ? var.queue_name : "${local.name_prefix}-queue${local.queue_suffix}"
  dlq_name     = var.queue_name != "" ? "${var.queue_name}-dlq${local.queue_suffix}" : "${local.name_prefix}-dlq${local.queue_suffix}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# ------------------------------------------------------------------
# SQS: Dead Letter Queue
# Recibe mensajes que fallaron después de max_receive_count intentos
# ------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  name = local.dlq_name

  # Retención más larga en la DLQ para tener tiempo de investigar
  message_retention_seconds = var.dlq_message_retention_seconds

  # FIFO si la cola principal también lo es
  fifo_queue                  = var.enable_fifo
  content_based_deduplication = var.enable_fifo

  tags = merge(local.common_tags, {
    Type = "dead-letter-queue"
  })
}

# ------------------------------------------------------------------
# SQS: Cola principal del microservicio
# ------------------------------------------------------------------

resource "aws_sqs_queue" "main" {
  name = local.queue_name

  # Configuración de tiempos
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  # FIFO: garantiza orden y entrega exactamente una vez
  fifo_queue                  = var.enable_fifo
  content_based_deduplication = var.enable_fifo

  # Redirección a la DLQ tras max_receive_count intentos fallidos
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(local.common_tags, {
    Type = "main-queue"
  })
}

# ------------------------------------------------------------------
# Event Source Mapping: conecta la cola con la Lambda (opcional)
# Se activa solo si se proporciona el ARN de la función Lambda
# ------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  count = var.lambda_function_arn != "" ? 1 : 0

  event_source_arn = aws_sqs_queue.main.arn
  function_name    = var.lambda_function_arn
  enabled          = true
  batch_size       = var.lambda_batch_size

  # Espera hasta llenar el batch o hasta 20s antes de invocar Lambda
  maximum_batching_window_in_seconds = 5

  # En caso de fallo parcial del batch, solo reintenta los mensajes fallidos
  function_response_types = ["ReportBatchItemFailures"]
}

# ------------------------------------------------------------------
# Política de la cola DLQ: permite a la cola principal enviar mensajes
# ------------------------------------------------------------------

data "aws_iam_policy_document" "dlq_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["sqs.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sqs_queue.main.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = data.aws_iam_policy_document.dlq_policy.json
}
