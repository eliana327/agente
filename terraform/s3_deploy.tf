# ==============================================================================
# DESPLIEGUE AUTOMÁTICO DEL FRONTEND AL BUCKET S3
# ==============================================================================

# Subir index.html
resource "aws_s3_object" "frontend_html" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${path.module}/../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../frontend/index.html")
}

# Subir app.js
resource "aws_s3_object" "frontend_js" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "app.js"
  source       = "${path.module}/../frontend/app.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/../frontend/app.js")
}

# Subir styles.css
resource "aws_s3_object" "frontend_css" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "styles.css"
  source       = "${path.module}/../frontend/styles.css"
  content_type = "text/css"
  etag         = filemd5("${path.module}/../frontend/styles.css")
}

# Generar y subir config.js inyectando dinámicamente las URLs de la infraestructura AWS
resource "aws_s3_object" "frontend_config" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "config.js"
  content_type = "application/javascript"

  content = <<-EOT
    window.APP_CONFIG = {
      API_BASE_URL: "${aws_apigatewayv2_stage.default.invoke_url}",
      COGNITO_USER_POOL_ID: "${aws_cognito_user_pool.profesores_pool.id}",
      COGNITO_CLIENT_ID: "${aws_cognito_user_pool_client.web_client.id}",
      AWS_REGION: "${var.aws_region}",
      SCHOOL_NAME: "${var.school_name}",
      TEACHERS: [
        { id: "prof_garcia", name: "Prof. Carlos García", subject: "Matemáticas", email: "cgarcia@colegio.edu" },
        { id: "prof_rodriguez", name: "Prof. Elena Rodríguez", subject: "Ciencias Naturales", email: "erodriguez@colegio.edu" },
        { id: "prof_martinez", name: "Prof. Andrés Martínez", subject: "Español y Literatura", email: "amartinez@colegio.edu" },
        { id: "prof_lopez", name: "Prof. Sofía López", subject: "Inglés", email: "slopez@colegio.edu" }
      ]
    };
  EOT
}
