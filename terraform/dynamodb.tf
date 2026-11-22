# ==============================================================================
# TABLA PRINCIPAL DE CITAS (CON MECÁNICA ANTI-COLISIÓN ATÓMICA)
# ==============================================================================
resource "aws_dynamodb_table" "citas" {
  name         = "${var.project_name}-citas-${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # On-Demand (Free Tier amigable, $0 fijos)

  # Clave compuesta que garantiza que una fecha/hora no se repita para un docente
  hash_key  = "ProfesorID"
  range_key = "FechaHora"

  attribute {
    name = "ProfesorID"
    type = "S"
  }

  attribute {
    name = "FechaHora"
    type = "S"
  }

  attribute {
    name = "Estado"
    type = "S"
  }

  # Índice Secundario Global (GSI) para consultar citas por Estado (Confirmada, Cancelada)
  global_secondary_index {
    name            = "EstadoIndex"
    hash_key        = "ProfesorID"
    range_key       = "Estado"
    projection_type = "ALL"
  }

  # ----------------------------------------------------------------------------
  # SEGURIDAD EN REPOSO: Cifrado con AWS KMS (AES-256) nativo sin costo adicional
  # ----------------------------------------------------------------------------
  server_side_encryption {
    enabled = true # Utiliza la llave administrada de AWS DynamoDB (AES-256)
  }

  # Respaldos continuos punto en el tiempo
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Nombre = "Tabla-Citas-AntiCruce"
  }
}

# ==============================================================================
# TABLA DE PROFESORES Y HORARIOS DE ATENCIÓN
# ==============================================================================
resource "aws_dynamodb_table" "profesores" {
  name         = "${var.project_name}-profesores-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "ProfesorID"

  attribute {
    name = "ProfesorID"
    type = "S"
  }

  # Seguridad en reposo: Cifrado AES-256
  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Nombre = "Tabla-Profesores-Horarios"
  }
}
