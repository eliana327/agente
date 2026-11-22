# ==============================================================================
# EMPAQUETADO Y DESPLIEGUE DE FUNCIONES LAMBDA (APUNTANDO A /backend)
# ==============================================================================

# 1. Zip para get_disponibilidad
data "archive_file" "zip_get_disponibilidad" {
  type        = "zip"
  source_file = "${path.module}/../backend/get_disponibilidad/lambda_function.py"
  output_path = "${path.module}/build/get_disponibilidad.zip"
}

# 2. Zip para reservar_cita
data "archive_file" "zip_reservar_cita" {
  type        = "zip"
  source_file = "${path.module}/../backend/reservar_cita/lambda_function.py"
  output_path = "${path.module}/build/reservar_cita.zip"
}

# 3. Zip para citas_profesor
data "archive_file" "zip_citas_profesor" {
  type        = "zip"
  source_file = "${path.module}/../backend/citas_profesor/lambda_function.py"
  output_path = "${path.module}/build/citas_profesor.zip"
}

# 4. Zip para bloquear_horario
data "archive_file" "zip_bloquear_horario" {
  type        = "zip"
  source_file = "${path.module}/../backend/bloquear_horario/lambda_function.py"
  output_path = "${path.module}/build/bloquear_horario.zip"
}

# ------------------------------------------------------------------------------
# 1. LAMBDA: GET DISPONIBILIDAD
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "get_disponibilidad" {
  filename         = data.archive_file.zip_get_disponibilidad.output_path
  source_code_hash = data.archive_file.zip_get_disponibilidad.output_base64sha256
  function_name    = "${var.project_name}-get-disponibilidad-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      TABLA_CITAS      = aws_dynamodb_table.citas.name
      TABLA_PROFESORES = aws_dynamodb_table.profesores.name
    }
  }

  tags = {
    Funcion = "Disponibilidad-Acudientes"
  }
}

# ------------------------------------------------------------------------------
# 2. LAMBDA: RESERVAR CITA (CON ESCRITURA CONDICIONAL ANTI-CRUCE)
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "reservar_cita" {
  filename         = data.archive_file.zip_reservar_cita.output_path
  source_code_hash = data.archive_file.zip_reservar_cita.output_base64sha256
  function_name    = "${var.project_name}-reservar-cita-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      TABLA_CITAS      = aws_dynamodb_table.citas.name
      TABLA_PROFESORES = aws_dynamodb_table.profesores.name
    }
  }

  tags = {
    Funcion = "Reserva-AntiCruce"
  }
}

# ------------------------------------------------------------------------------
# 3. LAMBDA: CITAS DEL PROFESOR (FILTRO AISLADO POR JWT)
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "citas_profesor" {
  filename         = data.archive_file.zip_citas_profesor.output_path
  source_code_hash = data.archive_file.zip_citas_profesor.output_base64sha256
  function_name    = "${var.project_name}-citas-profesor-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      TABLA_CITAS = aws_dynamodb_table.citas.name
    }
  }

  tags = {
    Funcion = "Agenda-Privada-Docente"
  }
}

# ------------------------------------------------------------------------------
# 4. LAMBDA: BLOQUEO DE HORARIO PERSONAL DOCENTE
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "bloquear_horario" {
  filename         = data.archive_file.zip_bloquear_horario.output_path
  source_code_hash = data.archive_file.zip_bloquear_horario.output_base64sha256
  function_name    = "${var.project_name}-bloquear-horario-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      TABLA_CITAS = aws_dynamodb_table.citas.name
    }
  }

  tags = {
    Funcion = "Bloqueo-Horario-Docente"
  }
}
