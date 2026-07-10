# variables.tf - Variables del módulo CloudWatch Alarmas
# Define los umbrales y configuración de alarmas para Lambda, SQS y API Gateway

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

# ------ Recursos a monitorear ------

variable "lambda_function_name" {
  description = "Nombre de la función Lambda a monitorear"
  type        = string
}

variable "api_gateway_id" {
  description = "ID del API Gateway a monitorear"
  type        = string
  default     = ""
}

variable "api_gateway_stage" {
  description = "Stage del API Gateway (ej: v1)"
  type        = string
  default     = "v1"
}

variable "sqs_queue_name" {
  description = "Nombre de la cola SQS principal a monitorear"
  type        = string
  default     = ""
}

variable "dlq_queue_name" {
  description = "Nombre de la Dead Letter Queue a monitorear"
  type        = string
  default     = ""
}

# ------ Umbrales de alarmas Lambda ------

variable "lambda_error_threshold" {
  description = "Número de errores de Lambda que activan la alarma"
  type        = number
  default     = 5
}

variable "lambda_error_period_seconds" {
  description = "Ventana de tiempo en segundos para evaluar errores de Lambda"
  type        = number
  default     = 60
}

variable "lambda_duration_threshold_ms" {
  description = "Latencia máxima tolerable de Lambda en milisegundos"
  type        = number
  default     = 5000
}

variable "lambda_throttle_threshold" {
  description = "Número de throttles de Lambda que activan la alarma"
  type        = number
  default     = 10
}

# ------ Umbrales de alarmas API Gateway ------

variable "api_5xx_threshold" {
  description = "Número de errores 5xx de API Gateway que activan la alarma"
  type        = number
  default     = 10
}

variable "api_latency_threshold_ms" {
  description = "Latencia máxima tolerable de API Gateway en milisegundos"
  type        = number
  default     = 3000
}

# ------ Umbrales de alarmas SQS ------

variable "dlq_messages_threshold" {
  description = "Número de mensajes en la DLQ que activan la alarma"
  type        = number
  default     = 1
}

variable "queue_age_threshold_seconds" {
  description = "Edad máxima tolerable de mensajes en la cola principal en segundos"
  type        = number
  default     = 300
}

# ------ Notificaciones ------

variable "sns_topic_arn" {
  description = "ARN del SNS topic para enviar notificaciones de alarma (opcional)"
  type        = string
  default     = ""
}

variable "create_sns_topic" {
  description = "Crear un SNS topic nuevo para las alarmas"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos"
  type        = map(string)
  default     = {}
}
