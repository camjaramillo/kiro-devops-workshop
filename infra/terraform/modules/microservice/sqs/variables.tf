# variables.tf - Variables del módulo SQS + Dead Letter Queue
# Define los parámetros configurables de las colas SQS

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

variable "queue_name" {
  description = "Nombre de la cola SQS (opcional, se genera automáticamente)"
  type        = string
  default     = ""
}

variable "visibility_timeout_seconds" {
  description = "Tiempo en segundos que un mensaje es invisible después de ser recibido"
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "El visibility timeout debe estar entre 0 y 43200 segundos."
  }
}

variable "message_retention_seconds" {
  description = "Tiempo en segundos que SQS retiene un mensaje no eliminado"
  type        = number
  default     = 86400 # 1 día

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "La retención debe estar entre 60 y 1209600 segundos (14 días)."
  }
}

variable "max_message_size" {
  description = "Tamaño máximo del mensaje en bytes"
  type        = number
  default     = 262144 # 256 KB

  validation {
    condition     = var.max_message_size >= 1024 && var.max_message_size <= 262144
    error_message = "El tamaño máximo debe estar entre 1024 y 262144 bytes."
  }
}

variable "delay_seconds" {
  description = "Segundos de retraso antes de que un mensaje sea visible"
  type        = number
  default     = 0

  validation {
    condition     = var.delay_seconds >= 0 && var.delay_seconds <= 900
    error_message = "El delay debe estar entre 0 y 900 segundos."
  }
}

variable "receive_wait_time_seconds" {
  description = "Tiempo de espera para long polling (0 = short polling)"
  type        = number
  default     = 10

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "El wait time debe estar entre 0 y 20 segundos."
  }
}

variable "max_receive_count" {
  description = "Número máximo de intentos antes de enviar el mensaje a la DLQ"
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "El max_receive_count debe estar entre 1 y 1000."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Tiempo de retención de mensajes en la Dead Letter Queue"
  type        = number
  default     = 604800 # 7 días

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "La retención de la DLQ debe estar entre 60 y 1209600 segundos."
  }
}

variable "enable_fifo" {
  description = "Habilitar cola FIFO (exactamente-una-vez, ordenada)"
  type        = bool
  default     = false
}

variable "lambda_function_arn" {
  description = "ARN de la Lambda que consumirá la cola (para event source mapping)"
  type        = string
  default     = ""
}

variable "lambda_batch_size" {
  description = "Número de mensajes por batch enviado a la Lambda"
  type        = number
  default     = 10

  validation {
    condition     = var.lambda_batch_size >= 1 && var.lambda_batch_size <= 10000
    error_message = "El batch size debe estar entre 1 y 10000."
  }
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos"
  type        = map(string)
  default     = {}
}
