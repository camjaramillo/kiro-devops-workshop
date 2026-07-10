# main.tf - Módulo DynamoDB
# Crea la tabla DynamoDB del microservicio con GSIs opcionales, TTL y PITR

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
  table_name  = var.table_name != "" ? var.table_name : "${local.name_prefix}-table"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# ------------------------------------------------------------------
# DynamoDB: Tabla principal del microservicio
# ------------------------------------------------------------------

resource "aws_dynamodb_table" "microservice" {
  name         = local.table_name
  billing_mode = var.billing_mode

  # Capacidad provisionada (solo aplica si billing_mode = PROVISIONED)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Partition key
  hash_key = var.hash_key

  # Sort key (opcional)
  range_key = var.range_key != "" ? var.range_key : null

  # Definición del partition key
  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Definición del sort key (solo si se especificó)
  dynamic "attribute" {
    for_each = var.range_key != "" ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  # Atributos de GSIs: se agregan dinámicamente
  dynamic "attribute" {
    for_each = {
      for gsi in var.global_secondary_indexes :
      gsi.hash_key => gsi
      if gsi.hash_key != var.hash_key && gsi.hash_key != var.range_key
    }
    content {
      name = attribute.value.hash_key
      type = attribute.value.hash_key_type
    }
  }

  # Global Secondary Indexes (opcionales)
  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key != "" ? global_secondary_index.value.range_key : null
      projection_type = global_secondary_index.value.projection_type

      # Capacidad del GSI (solo en modo PROVISIONED)
      read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
      write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
    }
  }

  # Time To Live (TTL) para expiración automática de ítems
  ttl {
    attribute_name = var.enable_ttl ? var.ttl_attribute : ""
    enabled        = var.enable_ttl
  }

  # Point-in-Time Recovery: permite restaurar la tabla a cualquier punto en el tiempo
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Cifrado en reposo con AWS KMS gestionado
  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}
