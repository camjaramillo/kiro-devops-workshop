# outputs.tf - Salidas del módulo Terraform para WebApp
# Este archivo define los valores que se exponen al usar este módulo

output "s3_bucket_id" {
  description = "ID del bucket S3 creado"
  value       = aws_s3_bucket.webapp.id
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3 creado"
  value       = aws_s3_bucket.webapp.arn
}

output "s3_bucket_domain_name" {
  description = "Nombre de dominio del bucket S3"
  value       = aws_s3_bucket.webapp.bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución CloudFront"
  value       = aws_cloudfront_distribution.webapp.id
}

output "cloudfront_distribution_domain" {
  description = "Nombre de dominio de la distribución CloudFront"
  value       = aws_cloudfront_distribution.webapp.domain_name
}

output "cloudfront_distribution_arn" {
  description = "ARN de la distribución CloudFront"
  value       = aws_cloudfront_distribution.webapp.arn
}

output "cloudfront_origin_access_identity_arn" {
  description = "ARN de la Identity Access Management (OAI) de CloudFront"
  value       = aws_cloudfront_origin_access_identity.webapp.arn
}

output "cloudfront_origin_access_identity_canonical_user_id" {
  description = "Canonical User ID de la OAI (para usar en policies)"
  value       = aws_cloudfront_origin_access_identity.webapp.canonical_user_id
}

output "cloudfront_distribution_url" {
  description = "URL base de la distribución CloudFront"
  value       = "https://${aws_cloudfront_distribution.webapp.domain_name}"
}