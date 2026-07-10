# Estándares de Infraestructura como Código (IaC)

Este documento define los estándares para escribir y mantener código Terraform en el proyecto.

## Versiones

- **Terraform**: >= 1.5.0
- **Provider AWS**: ~> 5.0
- Siempre declarar versiones en el bloque `terraform {}` de cada módulo:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## Tags Obligatorios

**Todos los recursos AWS deben incluir los siguientes tags:**

- `Environment` — ambiente de despliegue (`dev`, `staging`, `production`)
- `ManagedBy` — siempre `"Terraform"`
- `Team` — nombre del equipo responsable

Usar el bloque `default_tags` en el provider para aplicarlos globalmente:

```hcl
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Team        = var.team
    }
  }
}
```

O usar `merge` dentro de cada recurso cuando se necesiten tags adicionales:

```hcl
tags = merge(var.tags, {
  Environment = var.environment
  ManagedBy   = "Terraform"
  Team        = var.team
})
```

## Convención de Nombres de Recursos

**Patrón obligatorio:** `{proyecto}-{ambiente}-{recurso}`

- Usar **lowercase** y guiones (`-`), nunca guiones bajos ni mayúsculas
- Ejemplos:
  - S3 Bucket: `kiro-workshop-dev-assets`
  - Lambda: `kiro-workshop-prod-microservice`
  - DynamoDB: `kiro-workshop-staging-table`
  - SQS Queue: `kiro-workshop-dev-queue`
  - IAM Role: `kiro-workshop-dev-lambda-exec-role`

Usar `locals` para construir el prefijo y reutilizarlo:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_s3_bucket" "example" {
  bucket = "${local.name_prefix}-assets"
}
```

## Variables

**Todas las variables deben tener `description` y `validation` cuando aplique:**

```hcl
variable "environment" {
  description = "Ambiente de despliegue (dev, staging, production)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "El ambiente debe ser dev, staging o production."
  }
}

variable "project_name" {
  description = "Nombre del proyecto (max 32 caracteres)"
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "El nombre del proyecto debe tener máximo 32 caracteres."
  }
}
```

- Las variables sin default son **requeridas** — documentarlas claramente
- Las variables con default son **opcionales** — el default debe ser el valor más seguro

## Módulos

**Cada módulo debe incluir un `README.md`** con:

1. Descripción del módulo
2. Recursos que crea
3. Tabla de variables (requeridas y opcionales)
4. Tabla de outputs
5. Ejemplo de uso completo

Ejemplo mínimo de uso en el README:

```hcl
module "mi_modulo" {
  source = "../../modules/mi-modulo"

  project_name = "mi-proyecto"
  environment  = "dev"
  tags = {
    Team = "devops"
  }
}
```

## State Remoto

**El state de Terraform debe almacenarse en S3 con locking en DynamoDB.**

Configurar en el bloque `backend` de cada entorno:

```hcl
terraform {
  backend "s3" {
    bucket         = "carvajal-terraform-state"
    key            = "{proyecto}/{ambiente}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "carvajal-terraform-state-lock"
  }
}
```

Requisitos del bucket S3:
- Versionado habilitado
- Cifrado en reposo (SSE-S3 o SSE-KMS)
- Acceso público bloqueado

Requisitos de la tabla DynamoDB:
- Partition key: `LockID` (tipo String)
- Billing mode: `PAY_PER_REQUEST`

## Buenas Prácticas Generales

- Ejecutar `terraform fmt` antes de cada commit
- Ejecutar `terraform validate` en el pipeline CI con `./scripts/validate-terraform.sh`
- No hardcodear ARNs, IDs de cuenta ni credenciales
- Usar `sensitive = true` en outputs que contengan información sensible
- Preferir `count` y `for_each` sobre recursos duplicados
- Documentar con comentarios en español las decisiones no obvias
