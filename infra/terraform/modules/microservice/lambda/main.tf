# main.tf - Módulo Lambda + API Gateway
# Crea la función Lambda, el rol IAM asociado y API Gateway HTTP API

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
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# ------------------------------------------------------------------
# IAM: Rol de ejecución para la Lambda
# ------------------------------------------------------------------

# Política de confianza: permite a Lambda asumir el rol
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Rol IAM de ejecución
resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

# Política con permisos necesarios para Lambda
data "aws_iam_policy_document" "lambda_permissions" {
  # Permisos de logs en CloudWatch
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  # Permisos de DynamoDB (si se proporciona ARN)
  dynamic "statement" {
    for_each = var.dynamodb_table_arn != "" ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      resources = [var.dynamodb_table_arn, "${var.dynamodb_table_arn}/index/*"]
    }
  }

  # Permisos de SQS (si se proporciona ARN)
  dynamic "statement" {
    for_each = var.sqs_queue_arn != "" ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      resources = [var.sqs_queue_arn]
    }
  }
}

# Adjuntar política al rol
resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${local.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# ------------------------------------------------------------------
# Lambda: Función principal del microservicio
# ------------------------------------------------------------------

resource "aws_lambda_function" "microservice" {
  function_name = "${local.name_prefix}-microservice"
  description   = "Función Lambda del microservicio ${var.project_name} (${var.environment})"

  filename         = var.lambda_filename
  source_code_hash = filebase64sha256(var.lambda_filename)
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_exec.arn

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  # Variables de entorno: se inyectan las URLs de DynamoDB/SQS automáticamente
  environment {
    variables = merge(
      var.environment_variables,
      var.sqs_queue_url != "" ? { SQS_QUEUE_URL = var.sqs_queue_url } : {}
    )
  }

  tags = local.common_tags
}

# Grupo de logs de CloudWatch para la Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.microservice.function_name}"
  retention_in_days = 30
  tags              = local.common_tags
}

# ------------------------------------------------------------------
# API Gateway: HTTP API (versión v2, más económica y simple)
# ------------------------------------------------------------------

# HTTP API
resource "aws_apigatewayv2_api" "microservice" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "API Gateway para el microservicio ${var.project_name} (${var.environment})"
  tags          = local.common_tags
}

# Stage de despliegue con auto-deploy activado
resource "aws_apigatewayv2_stage" "microservice" {
  api_id      = aws_apigatewayv2_api.microservice.id
  name        = var.api_stage_name
  auto_deploy = true

  # Logs de acceso en CloudWatch
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
  }

  tags = local.common_tags
}

# Grupo de logs de CloudWatch para API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}-api"
  retention_in_days = 30
  tags              = local.common_tags
}

# Integración entre API Gateway y Lambda
resource "aws_apigatewayv2_integration" "microservice" {
  api_id             = aws_apigatewayv2_api.microservice.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.microservice.invoke_arn
  payload_format_version = "2.0"
}

# Ruta: cualquier método y path (proxy)
resource "aws_apigatewayv2_route" "microservice" {
  api_id    = aws_apigatewayv2_api.microservice.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.microservice.id}"
}

# Permiso para que API Gateway invoque la Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.microservice.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.microservice.execution_arn}/*/*"
}
