# ==============================================================================
# AMAZON COGNITO: AUTENTICACIÓN SEGURA Y PRIVADA PARA PROFESORES
# ==============================================================================

# User Pool para profesores
resource "aws_cognito_user_pool" "profesores_pool" {
  name = "${var.project_name}-profesores-pool-${var.environment}"

  # Iniciar sesión con Correo Electrónico
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Políticas de contraseñas seguras
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Verificación de cuenta por email automático
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Código de acceso - Sistema de Citas ${var.school_name}"
    email_message        = "Su código de verificación para ingresar a su panel docente es {####}"
  }

  # Seguridad en reposo de datos y atributos de docentes
  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = {
    Modulo = "Autenticacion-Docente"
  }
}

# Cliente de la aplicación para el Frontend Web SPA (sin secret público)
resource "aws_cognito_user_pool_client" "web_client" {
  name         = "${var.project_name}-web-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.profesores_pool.id

  generate_secret = false # Obligatorio para Single Page Apps públicas

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  # Vigencia de tokens seguros
  id_token_validity      = 60
  access_token_validity  = 60
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
