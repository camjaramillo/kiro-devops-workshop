# variables.tf - Variables del módulo Lambda + API Gateway
# Define los parámetros configurables del módulo

variable "project_name" {
  description = "Nombre del proyecto para etiquetar recursos"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging, production)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "El ambiente debe ser dev, staging o production."
  }
}

variable "lambda_filename" {
  description = "Ruta al archivo ZIP con el código de la función Lambda"
  type        = string
  default     = "lambda.zip"
}

variable "lambda_handler" {
  description = "Handler de la función Lambda (archivo.función)"
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Runtime de la función Lambda"
  type        = string
  default     = "nodejs20.x"

  validation {
    condition     = contains(["nodejs20.x", "nodejs18.x", "python3.11", "python3.12"], var.lambda_runtime)
    error_message = "El runtime debe ser un valor soportado."
  }
}

variable "lambda_memory_mb" {
  description = "Memoria asignada a la Lambda en MB"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_mb >= 128 && var.lambda_memory_mb <= 10240
    error_message = "La memoria debe estar entre 128 y 10240 MB."
  }
}

variable "lambda_timeout_seconds" {
  description = "Timeout máximo de la Lambda en segundos"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout_seconds >= 1 && var.lambda_timeout_seconds <= 900
    error_message = "El timeout debe estar entre 1 y 900 segundos."
  }
}

variable "environment_variables" {
  description = "Variables de entorno para la Lambda"
  type        = map(string)
  default     = {}
}

variable "dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB a la que la Lambda tendrá acceso"
  type        = string
  default     = ""
}

variable "sqs_queue_arn" {
  description = "ARN de la cola SQS a la que la Lambda tendrá acceso"
  type        = string
  default     = ""
}

variable "sqs_queue_url" {
  description = "URL de la cola SQS para enviar mensajes"
  type        = string
  default     = ""
}

variable "api_stage_name" {
  description = "Nombre del stage de API Gateway"
  type        = string
  default     = "v1"
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos"
  type        = map(string)
  default     = {}
}
