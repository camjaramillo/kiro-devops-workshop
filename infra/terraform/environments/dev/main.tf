# main.tf - Entorno de Desarrollo (dev)
# Este archivo configura la infraestructura para el ambiente de desarrollo
# usando el módulo webapp

terraform {
  # Configuración del provider AWS
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend S3 para el state (comentado - descomentar cuando tengas el bucket S3 creado)
  # Esto permite almacenar el state de forma remota y compartida
  /*
  backend "s3" {
    bucket         = "mi-terraform-state-bucket"
    key            = "webapp/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "mi-terraform-state-lock"
  }
  */
}

# Configuración del provider AWS
# Puntos de entrada para autenticación:
# - Variables de entorno: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
# - Perfil AWS en ~/.aws/credentials
# - IAM Role para EC2/ECS/Lambda
provider "aws" {
  region = "us-east-1"

  # Opcional: tags por defecto para todos los recursos
  default_tags {
    tags = {
      Project     = "webapp"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

# Uso del módulo webapp para el entorno dev
module "webapp" {
  source = "../../modules/webapp"

  project_name  = "webapp"
  environment   = "dev"
  bucket_name   = "" # Dejar vacío para generar automáticamente
  custom_domain = ""

  # Etiquetas adicionales
  tags = {
    Team = "devops"
    CostCenter = "development"
  }
}

# Outputs del módulo
output "s3_bucket_id" {
  value = module.webapp.s3_bucket_id
}

output "s3_bucket_arn" {
  value = module.webapp.s3_bucket_arn
}

output "cloudfront_distribution_id" {
  value = module.webapp.cloudfront_distribution_id
}

output "cloudfront_distribution_domain" {
  value = module.webapp.cloudfront_distribution_domain
}

output "cloudfront_distribution_url" {
  value = module.webapp.cloudfront_distribution_url
}