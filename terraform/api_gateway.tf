# ==============================================================================
# AMAZON API GATEWAY (HTTP API v2) CON AUTHORIZER JWT DE COGNITO
# ==============================================================================

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "API Serverless para agendamiento escolar con cifrado TLS 1.2+"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# ------------------------------------------------------------------------------
# AUTHORIZER JWT: VALIDA EL TOKEN CRIPTOGRÁFICO DE COGNITO
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-docentes-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web_client.id]
    issuer   = "https://${aws_cognito_user_pool.profesores_pool.endpoint}"
  }
}

# ------------------------------------------------------------------------------
# INTEGRACIONES CON AWS LAMBDA
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "int_disponibilidad" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_disponibilidad.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "int_reservar" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.reservar_cita.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "int_profesor" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.citas_profesor.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "int_bloquear" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.bloquear_horario.invoke_arn
  payload_format_version = "2.0"
}

# ------------------------------------------------------------------------------
# RUTAS PÚBLICAS (Para Acudientes)
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_route" "route_disponibilidad" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /disponibilidad/{profesor_id}"
  target    = "integrations/${aws_apigatewayv2_integration.int_disponibilidad.id}"
}

resource "aws_apigatewayv2_route" "route_reservar" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /reservar"
  target    = "integrations/${aws_apigatewayv2_integration.int_reservar.id}"
}

# ------------------------------------------------------------------------------
# RUTAS PROTEGIDAS (Solo para Profesores Autenticados con JWT)
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_route" "route_profesor_citas" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "GET /profesor/citas"
  target             = "integrations/${aws_apigatewayv2_integration.int_profesor.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "route_profesor_bloquear" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "POST /profesor/bloquear"
  target             = "integrations/${aws_apigatewayv2_integration.int_bloquear.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

# ------------------------------------------------------------------------------
# PERMISOS PARA QUE API GATEWAY INVOQUE A LAMBDA
# ------------------------------------------------------------------------------
resource "aws_lambda_permission" "apigw_disponibilidad" {
  statement_id  = "AllowExecutionFromAPIGatewayDisponibilidad"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_disponibilidad.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_reservar" {
  statement_id  = "AllowExecutionFromAPIGatewayReservar"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reservar_cita.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_profesor" {
  statement_id  = "AllowExecutionFromAPIGatewayProfesor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.citas_profesor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_bloquear" {
  statement_id  = "AllowExecutionFromAPIGatewayBloquear"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bloquear_horario.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
