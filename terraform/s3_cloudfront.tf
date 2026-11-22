# ==============================================================================
# ALMACENAMIENTO WEB ESTÁTICO (S3) + CDN & SSL (CLOUDFRONT)
# ==============================================================================

# Bucket S3 para la Web Móvil de Citas
resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-frontend-${var.environment}"
  force_destroy = true
}

# ------------------------------------------------------------------------------
# SEGURIDAD EN REPOSO: Cifrado SSE-S3 (AES-256) obligatorio
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_crypto" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ------------------------------------------------------------------------------
# SEGURIDAD: Bloqueo de Acceso Público al 100% (Solo accesible por CloudFront)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin Access Control (OAC) para que CloudFront sea el único que lea de S3
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac-${var.environment}"
  description                       = "Control de acceso seguro para S3 desde CloudFront con SigV4"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Política en S3 permitiendo acceso exclusivo a la distribución de CloudFront
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# Política de cabeceras de seguridad para CloudFront (HSTS, Anti-Clickjacking)
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "${var.project_name}-security-headers-${var.environment}"

  security_headers_config {
    # --------------------------------------------------------------------------
    # SEGURIDAD EN TRÁNSITO: Strict Transport Security (HSTS)
    # --------------------------------------------------------------------------
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }
  }
}

# Distribución Global CloudFront (CDN + HTTPS)
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Portal Web de Citas Escolares - ${var.school_name}"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    # Redirección obligatoria HTTP -> HTTPS
    viewer_protocol_policy = "redirect-to-https"

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Soporte para Single Page Application (SPA): redirige 404 a index.html
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificado SSL gratuito de CloudFront (HTTPS predeterminado)
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021" # Obliga TLS 1.2 o superior
  }

  tags = {
    Modulo = "Frontend-CDN"
  }
}
