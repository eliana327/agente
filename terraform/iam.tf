# ==============================================================================
# ROLES Y POLÍTICAS IAM (PRINCIPIO DE MÍNIMO PRIVILEGIO)
# ==============================================================================

# Rol de ejecución para las funciones Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Permisos para registrar logs en CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Política restrictiva sobre las tablas DynamoDB
resource "aws_iam_policy" "dynamodb_access" {
  name        = "${var.project_name}-dynamodb-policy-${var.environment}"
  description = "Permite a Lambda operar únicamente las tablas del colegio con firmas seguras"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OperacionesCitas"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.citas.arn,
          "${aws_dynamodb_table.citas.arn}/index/*",
          aws_dynamodb_table.profesores.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}
