# microservice.tf - Composición del microservicio para el ambiente dev
# Orquesta los módulos: lambda, dynamodb, sqs y alarmas
#
# Orden de dependencias:
#   dynamodb y sqs se crean primero (sin dependencias entre sí)
#   lambda recibe los outputs de dynamodb y sqs
#   alarmas recibe los outputs de lambda, sqs y api gateway

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend S3 para el state (comentado - descomentar cuando tengas el bucket creado)
  /*
  backend "s3" {
    bucket         = "mi-terraform-state-bucket"
    key            = "microservice/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "mi-terraform-state-lock"
  }
  */
}

# Configuración del provider AWS apuntando a us-east-1
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = local.project_name
      Environment = local.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  project_name = "kiro-workshop"
  environment  = "dev"

  common_tags = {
    Team      = "devops"
    CostCenter = "development"
  }
}

# ------------------------------------------------------------------
# Módulo 1: DynamoDB
# Se crea primero ya que Lambda necesita su ARN
# ------------------------------------------------------------------

module "dynamodb" {
  source = "../../modules/microservice/dynamodb"

  project_name = local.project_name
  environment  = local.environment

  # Partition key principal
  hash_key      = "id"
  hash_key_type = "S"

  # Sort key para ordenar por fecha de creación
  range_key      = "created_at"
  range_key_type = "S"

  # On-demand en dev para no pagar capacidad ociosa
  billing_mode = "PAY_PER_REQUEST"

  # TTL habilitado para limpiar registros expirados automáticamente
  enable_ttl    = true
  ttl_attribute = "expires_at"

  # PITR habilitado para recuperación ante desastres
  enable_point_in_time_recovery = true

  # GSI para consultas por status
  global_secondary_indexes = [
    {
      name            = "status-index"
      hash_key        = "status"
      hash_key_type   = "S"
      range_key       = "created_at"
      range_key_type  = "S"
      projection_type = "ALL"
    }
  ]

  tags = local.common_tags
}

# ------------------------------------------------------------------
# Módulo 2: SQS + DLQ
# Se crea antes de Lambda para pasar su ARN y URL al módulo lambda
# El event source mapping se configura luego con lambda_function_arn
# ------------------------------------------------------------------

module "sqs" {
  source = "../../modules/microservice/sqs"

  project_name = local.project_name
  environment  = local.environment

  # Visibility timeout mayor que el timeout de Lambda (30s) para evitar re-entregas prematuras
  visibility_timeout_seconds = 60

  # Retener mensajes 1 día en la cola principal
  message_retention_seconds = 86400

  # Long polling para reducir costos
  receive_wait_time_seconds = 10

  # Reintentar 3 veces antes de enviar a DLQ
  max_receive_count = 3

  # Retener mensajes en DLQ 7 días para investigación
  dlq_message_retention_seconds = 604800

  # El event source mapping se conecta a Lambda después de crearla
  lambda_function_arn = module.lambda.lambda_function_arn
  lambda_batch_size   = 10

  tags = local.common_tags
}

# ------------------------------------------------------------------
# Módulo 3: Lambda + API Gateway
# Recibe ARNs de DynamoDB y SQS para configurar permisos IAM
# ------------------------------------------------------------------

module "lambda" {
  source = "../../modules/microservice/lambda"

  project_name = local.project_name
  environment  = local.environment

  # Archivo ZIP del código (debe existir antes del apply)
  lambda_filename = "${path.module}/lambda.zip"
  lambda_handler  = "index.handler"
  lambda_runtime  = "nodejs20.x"

  # Recursos en dev: suficiente para desarrollo y pruebas
  lambda_memory_mb       = 256
  lambda_timeout_seconds = 30

  # Variables de entorno inyectadas automáticamente
  environment_variables = {
    NODE_ENV      = "development"
    TABLE_NAME    = module.dynamodb.table_name
    LOG_LEVEL     = "debug"
  }

  # ARNs para que el módulo genere los permisos IAM correctos
  dynamodb_table_arn = module.dynamodb.table_arn
  sqs_queue_arn      = module.sqs.queue_arn
  sqs_queue_url      = module.sqs.queue_url

  api_stage_name = "v1"

  tags = local.common_tags
}

# ------------------------------------------------------------------
# Módulo 4: Alarmas de CloudWatch
# Depende de los outputs de lambda, sqs y api gateway
# ------------------------------------------------------------------

module "alarmas" {
  source = "../../modules/microservice/alarmas"

  project_name = local.project_name
  environment  = local.environment

  # Función Lambda a monitorear
  lambda_function_name = module.lambda.lambda_function_name

  # API Gateway a monitorear
  api_gateway_id    = module.lambda.api_gateway_id
  api_gateway_stage = "v1"

  # Colas SQS a monitorear
  sqs_queue_name = module.sqs.queue_name
  dlq_queue_name = module.sqs.dlq_name

  # Umbrales de dev: más permisivos que producción
  lambda_error_threshold       = 5
  lambda_duration_threshold_ms = 10000   # 10s en dev
  lambda_throttle_threshold    = 10
  api_5xx_threshold            = 10
  api_latency_threshold_ms     = 5000    # 5s en dev
  dlq_messages_threshold       = 1       # Cualquier mensaje en DLQ es una alerta
  queue_age_threshold_seconds  = 600     # 10 minutos

  # Crear SNS topic propio para dev
  create_sns_topic = true

  tags = local.common_tags
}

# ------------------------------------------------------------------
# Outputs finales del ambiente dev
# ------------------------------------------------------------------

output "api_endpoint" {
  description = "URL del API Gateway para el microservicio"
  value       = module.lambda.api_gateway_endpoint
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = module.lambda.lambda_function_name
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
  value       = module.dynamodb.table_name
}

output "sqs_queue_url" {
  description = "URL de la cola SQS principal"
  value       = module.sqs.queue_url
}

output "dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = module.sqs.dlq_url
}

output "cloudwatch_dashboard" {
  description = "Nombre del dashboard de CloudWatch"
  value       = module.alarmas.dashboard_name
}

output "sns_topic_arn" {
  description = "ARN del SNS topic de notificaciones"
  value       = module.alarmas.sns_topic_arn
}
