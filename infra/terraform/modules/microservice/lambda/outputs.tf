# outputs.tf - Salidas del módulo Lambda + API Gateway

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.microservice.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.microservice.arn
}

output "lambda_invoke_arn" {
  description = "ARN de invocación de la función Lambda"
  value       = aws_lambda_function.microservice.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN del rol IAM de ejecución de la Lambda"
  value       = aws_iam_role.lambda_exec.arn
}

output "api_gateway_id" {
  description = "ID del API Gateway HTTP API"
  value       = aws_apigatewayv2_api.microservice.id
}

output "api_gateway_endpoint" {
  description = "URL base del API Gateway"
  value       = aws_apigatewayv2_stage.microservice.invoke_url
}

output "api_gateway_execution_arn" {
  description = "ARN de ejecución del API Gateway"
  value       = aws_apigatewayv2_api.microservice.execution_arn
}

output "cloudwatch_log_group_lambda" {
  description = "Nombre del grupo de logs de CloudWatch para la Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}
