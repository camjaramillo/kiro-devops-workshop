# Módulo Terraform: WebApp (S3 + CloudFront)

Este módulo Terraform crea una infraestructura completa para alojar una aplicación web estática en AWS, incluyendo:

- **S3 Bucket** con versionado habilitado para almacenar assets estáticos
- **CloudFront Distribution** para entrega rápida de contenido con CDN
- **Bucket Policy** que restringe el acceso al bucket S3 solo desde CloudFront

## Requisitos

- Terraform >= 1.5.0
- AWS Provider >= 5.0
- Cuenta de AWS con permisos para crear S3, CloudFront y ACM

## Uso

```hcl
module "webapp" {
  source = "./modules/webapp"

  project_name  = "mi-webapp"
  environment   = "production"
  bucket_name   = "mi-webapp-bucket" # Opcional
  custom_domain = "www.midominio.com" # Opcional
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx" # Opcional
  tags = {
    Team = "devops"
  }
}
```

## Variables

| Nombre | Descripción | Tipo | Default | Requerido |
|--------|-------------|------|---------|:---------:|
| `project_name` | Nombre del proyecto para etiquetar recursos | `string` | `"webapp"` | No |
| `environment` | Entorno de despliegue (dev, staging, production) | `string` | `"development"` | No |
| `tags` | Etiquetas adicionales para los recursos | `map(string)` | `{}` | No |
| `bucket_name` | Nombre personalizado del bucket S3 | `string` | `""` | No |
| `enable_logging` | Habilitar logging de accesos al bucket S3 | `bool` | `false` | No |
| `logging_bucket_name` | Nombre del bucket para logs | `string` | `""` | No |
| `certificate_arn` | ARN del certificado ACM para HTTPS | `string` | `""` | No |
| `custom_domain` | Dominio personalizado para CloudFront | `string` | `""` | No |

## Salidas

| Nombre | Descripción |
|--------|-------------|
| `s3_bucket_id` | ID del bucket S3 creado |
| `s3_bucket_arn` | ARN del bucket S3 creado |
| `s3_bucket_domain_name` | Nombre de dominio del bucket S3 |
| `cloudfront_distribution_id` | ID de la distribución CloudFront |
| `cloudfront_distribution_domain` | Nombre de dominio de la distribución CloudFront |
| `cloudfront_distribution_arn` | ARN de la distribución CloudFront |
| `cloudfront_origin_access_identity_arn` | ARN de la OAI de CloudFront |
| `cloudfront_origin_access_identity_canonical_user_id` | Canonical User ID de la OAI |
| `cloudfront_distribution_url` | URL base de la distribución CloudFront |

## Estructura de Recursos

```
S3 Bucket (assets estáticos)
├── Versionado habilitado
└── Policy restringido a CloudFront

CloudFront Distribution
├── Origin: S3 Bucket (privado)
├── OAI: Origin Access Identity
└── Cache behaviors configurados
```

## Seguridad

- El bucket S3 es **privado** y solo accesible mediante CloudFront
- Se utiliza **Origin Access Identity (OAI)** para autorización
- Se requiere HTTPS para todas las conexiones
- Los logs pueden configurarse en un bucket separado

## Costos

Los costos típicos incluyen:
- S3: Almacenamiento y peticiones GET/PUT
- CloudFront: Transferencia de datos y peticiones
- ACM: Certificados (si no usas uno existente)

Ver [precios de S3](https://aws.amazon.com/s3/pricing/) y [precios de CloudFront](https://aws.amazon.com/cloudfront/pricing/) para detalles.

## Notas

- Si no se especifica `bucket_name`, se genera automáticamente usando el formato: `{project_name}-{environment}-assets`
- El bucket tiene versionado habilitado por defecto
- La distribución CloudFront redirige HTTP a HTTPS automáticamente