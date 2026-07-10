# variables.tf - Variables del módulo Terraform para WebApp
# Este archivo define las variables configurables del módulo

variable "project_name" {
  description = "Nombre del proyecto para etiquetar recursos"
  type        = string
  default     = "webapp"

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "El nombre del proyecto debe tener máximo 32 caracteres."
  }
}

variable "environment" {
  description = "Entorno de despliegue (dev, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "El ambiente debe ser dev, staging o production."
  }
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.tags : length(k) <= 128 && length(v) <= 256])
    error_message = "Las etiquetas deben tener claves <= 128 y valores <= 256 caracteres."
  }
}

variable "bucket_name" {
  description = "Nombre del bucket S3 (opcional, se genera automáticamente si no se especifica)"
  type        = string
  default     = ""

  validation {
    condition     = var.bucket_name == "" || (length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63)
    error_message = "El nombre del bucket debe tener entre 3 y 63 caracteres."
  }
}

variable "enable_logging" {
  description = "Habilitar logging de accesos al bucket S3"
  type        = bool
  default     = false
}

variable "logging_bucket_name" {
  description = "Nombre del bucket para logs (requerido si enable_logging es true)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN del certificado ACM para HTTPS en CloudFront"
  type        = string
  default     = ""

  validation {
    condition     = var.certificate_arn == "" || can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "El ARN del certificado debe ser válido (arn:aws:acm:...)."
  }
}

variable "custom_domain" {
  description = "Dominio personalizado para la CloudFront distribution"
  type        = string
  default     = ""

  validation {
    condition     = var.custom_domain == "" || can(regex("^[a-zA-Z0-9.-]+$", var.custom_domain))
    error_message = "El dominio personalizado debe ser válido."
  }
}