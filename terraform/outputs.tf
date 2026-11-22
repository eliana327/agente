output "cloudfront_url" {
  description = "URL segura (HTTPS) del Portal Web para acudientes y profesores"
  value       = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "api_gateway_url" {
  description = "URL base de la API HTTP Serverless"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 para cargar los archivos web (HTML/JS/CSS)"
  value       = aws_s3_bucket.frontend.id
}

output "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito para registrar a los profesores"
  value       = aws_cognito_user_pool.profesores_pool.id
}

output "cognito_client_id" {
  description = "ID del Cliente de Cognito para configurar en el Frontend Web"
  value       = aws_cognito_user_pool_client.web_client.id
}

output "dynamodb_citas_table" {
  description = "Nombre de la tabla DynamoDB con bloqueo atómico anti-colisión"
  value       = aws_dynamodb_table.citas.name
}
