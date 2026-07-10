# variables.tf - Variables del módulo DynamoDB
# Define los parámetros configurables de la tabla DynamoDB

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

variable "table_name" {
  description = "Nombre de la tabla DynamoDB (opcional, se genera automáticamente)"
  type        = string
  default     = ""
}

variable "hash_key" {
  description = "Nombre del atributo de partition key (clave de partición)"
  type        = string
  default     = "id"
}

variable "hash_key_type" {
  description = "Tipo del partition key: S (string), N (number), B (binary)"
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "El tipo debe ser S, N o B."
  }
}

variable "range_key" {
  description = "Nombre del atributo de sort key (opcional)"
  type        = string
  default     = ""
}

variable "range_key_type" {
  description = "Tipo del sort key: S (string), N (number), B (binary)"
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "El tipo debe ser S, N o B."
  }
}

variable "billing_mode" {
  description = "Modo de facturación: PAY_PER_REQUEST (on-demand) o PROVISIONED"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "El modo de facturación debe ser PAY_PER_REQUEST o PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Unidades de capacidad de lectura (solo para modo PROVISIONED)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Unidades de capacidad de escritura (solo para modo PROVISIONED)"
  type        = number
  default     = 5
}

variable "enable_ttl" {
  description = "Habilitar Time To Live (TTL) en la tabla"
  type        = bool
  default     = false
}

variable "ttl_attribute" {
  description = "Nombre del atributo TTL (requerido si enable_ttl es true)"
  type        = string
  default     = "expires_at"
}

variable "enable_point_in_time_recovery" {
  description = "Habilitar recuperación point-in-time (PITR)"
  type        = bool
  default     = true
}

variable "global_secondary_indexes" {
  description = "Lista de Global Secondary Indexes a crear en la tabla"
  type = list(object({
    name            = string
    hash_key        = string
    hash_key_type   = string
    range_key       = optional(string, "")
    range_key_type  = optional(string, "S")
    projection_type = optional(string, "ALL")
  }))
  default = []
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos"
  type        = map(string)
  default     = {}
}
