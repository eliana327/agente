# ==============================================================================
# 1. BUCKET S3 PARA EL TERRAFORM STATE REMOTO
# ==============================================================================
resource "aws_s3_bucket" "tf_state" {
  bucket        = "${var.project_name}-tf-state-${var.aws_region}"
  force_destroy = false # Evita borrado accidental del estado

  lifecycle {
    prevent_destroy = true
  }
}

# Versionamiento del estado para poder revertir en caso de fallos
resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado en reposo obligatorio para el archivo .tfstate (puede contener secretos)
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_crypto" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueo total de acceso público
resource "aws_s3_bucket_public_access_block" "tf_state_block_public" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# 2. TABLA DYNAMODB PARA EL BLOQUEO DEL ESTADO (STATE LOCKING)
# ==============================================================================
resource "aws_dynamodb_table" "tf_locks" {
  name         = "${var.project_name}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

# ==============================================================================
# 3. PROVEEDOR DE IDENTIDAD OPENID CONNECT (OIDC) PARA GITHUB ACTIONS
# ==============================================================================
# Certificado SSL thumbprint oficial de GitHub Actions
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# Importación para asociar el proveedor OIDC existente en la cuenta AWS
import {
  to = aws_iam_openid_connect_provider.github_oidc
  id = "arn:aws:iam::079301214534:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# ==============================================================================
# 4. ROL IAM PARA GITHUB ACTIONS (ASUME ROL SIN CREDENCIALES ESTÁTICAS)
# ==============================================================================
resource "aws_iam_role" "github_ci_cd_role" {
  name        = "${var.project_name}-github-oidc-role"
  description = "Rol asumido por GitHub Actions mediante OIDC para CI/CD multirrepositorio sin Access Keys"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            # Permite a cualquier repositorio de la cuenta de GitHub asumir este rol
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org_or_user}/*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Política con los permisos necesarios para gestionar la infraestructura
resource "aws_iam_policy" "ci_cd_permissions" {
  name        = "${var.project_name}-ci-cd-policy"
  description = "Permisos necesarios para desplegar soluciones serverless, autoscaling y balanceo"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateManagement"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_s3_bucket.tf_state.arn,
          "${aws_s3_bucket.tf_state.arn}/*",
          aws_dynamodb_table.tf_locks.arn
        ]
      },
      {
        Sid    = "FullInfrastructureManagement"
        Effect = "Allow"
        Action = [
          "s3:*",
          "cloudfront:*",
          "lambda:*",
          "apigateway:*",
          "cognito-idp:*",
          "dynamodb:*",
          "iam:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ci_cd" {
  role       = aws_iam_role.github_ci_cd_role.name
  policy_arn = aws_iam_policy.ci_cd_permissions.arn
}
