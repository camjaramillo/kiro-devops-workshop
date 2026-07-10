# main.tf - Recursos principales del módulo Terraform para WebApp
# Este archivo crea S3 bucket con versionado, CloudFront distribution y bucket policy

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 Bucket para assets estáticos
# El bucket tiene versionado habilitado para recuperar versiones anteriores
resource "aws_s3_bucket" "webapp" {
  count = var.bucket_name == "" ? 1 : 0

  bucket = "${lower(var.project_name)}-${lower(var.environment)}-assets"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-assets"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# S3 Bucket para assets estáticos (cuando se especifica nombre personalizado)
resource "aws_s3_bucket" "webapp_custom" {
  count = var.bucket_name != "" ? 1 : 0

  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name        = var.bucket_name
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Habilitar versionado del bucket S3
resource "aws_s3_bucket_versioning" "webapp" {
  bucket = var.bucket_name == "" ? aws_s3_bucket.webapp[0].id : aws_s3_bucket.webapp_custom[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket versioning en bucket personalizado
resource "aws_s3_bucket_versioning" "webapp_custom" {
  count = var.bucket_name != "" ? 1 : 0

  bucket = aws_s3_bucket.webapp_custom[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket de logging (opcional)
resource "aws_s3_bucket" "logging" {
  count = var.enable_logging ? 1 : 0

  bucket = "${lower(var.project_name)}-${lower(var.environment)}-logging"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-logging"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# OAI (Origin Access Identity) de CloudFront
# Permite que CloudFront acceda al bucket S3 sin exponerlo públicamente
resource "aws_cloudfront_origin_access_identity" "webapp" {
  comment = "${var.project_name}-${var.environment} OAI"
}

# Bucket policy que solo permite acceso desde CloudFront
# El bucket S3 se mantiene privado y solo accesible mediante CloudFront
resource "aws_s3_bucket_policy" "webapp" {
  bucket = var.bucket_name == "" ? aws_s3_bucket.webapp[0].id : aws_s3_bucket.webapp_custom[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.webapp.arn}"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.bucket_name == "" ? aws_s3_bucket.webapp[0].arn : aws_s3_bucket.webapp_custom[0].arn}",
          "${var.bucket_name == "" ? aws_s3_bucket.webapp[0].arn }/*" : "${aws_s3_bucket.webapp_custom[0].arn }/*"
        ]
      }
    ]
  })

  # Asegurar que el bucket exista antes de aplicar el policy
  depends_on = [aws_s3_bucket.webapp, aws_s3_bucket.webapp_custom]
}

# CloudFront Distribution para entrega de contenido
resource "aws_cloudfront_distribution" "webapp" {
  origin {
    domain_name = var.bucket_name == "" ? aws_s3_bucket.webapp[0].bucket_regional_domain_name : aws_s3_bucket.webapp_custom[0].bucket_regional_domain_name
    origin_id   = "s3-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.webapp.arn
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name}-${var.environment} Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
      headers      = []
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Configuración de cache para otros objetos
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
      headers      = []
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 604800
    compress               = true
  }

  # Configuración de dominio personalizado si se especifica
  dynamic "custom_domain" {
    for_each = var.custom_domain != "" ? [1] : []
    content {
      domain_name              = var.custom_domain
      ssl_support_method       = "sni-only"
      security_policy          = "TLSv1.2_2021"
      certificate              = var.certificate_arn != "" ? var.certificate_arn : null
      certificate_chain        = var.certificate_arn != "" ? var.certificate_arn : null
    }
  }

  # Configuración de logging de accesos (opcional)
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = var.logging_bucket_name != "" ? var.logging_bucket_name : aws_s3_bucket.logging[0].bucket
      prefix          = "cloudfront/"
    }
  }

  # Etiquetas
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-distribution"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}