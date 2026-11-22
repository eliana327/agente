# Despliegue de Infraestructura Serverless AWS con Terraform

Este directorio contiene la infraestructura como código (IaC) en **Terraform** para desplegar el **Sistema Escolar Anti-Colisión de Citas**, 100% Serverless con **costo operativo $0.00 USD (Free Tier)** y **cifrado en tránsito y en reposo**.

---

## 📁 Estructura de Archivos

```
terraform/
├── providers.tf        # Configuración de AWS Provider (~> 5.0) y tags automáticos
├── variables.tf        # Variables configurables (región, ambiente, nombre del colegio)
├── dynamodb.tf         # Tablas DynamoDB con bloqueo atómico y cifrado KMS (AES-256)
├── cognito.tf          # Amazon Cognito User Pool para el login privado de profesores
├── s3_cloudfront.tf    # S3 Web Hosting + CloudFront CDN con HTTPS (TLS 1.3) y OAC
├── iam.tf              # Roles y políticas IAM con principio de mínimo privilegio
├── lambda.tf           # Funciones AWS Lambda para acudientes y profesores
├── api_gateway.tf      # HTTP API v2 con JWT Authorizer conectado a Cognito
├── outputs.tf          # URLs y datos de salida una vez desplegada la infraestructura
└── lambda_src/         # Código fuente de las funciones Lambda (Python 3.11)
    ├── get_disponibilidad.py  # Consulta de horarios libres para acudientes
    ├── reservar_cita.py       # Reserva con ConditionExpression anti-cruce
    └── citas_profesor.py      # Panel privado del profesor filtrado por su JWT
```

---

## 🛡️ Seguridad Incorporada

1. **En Tránsito:**
   - CloudFront obliga la redirección de `HTTP` a `HTTPS` con **TLS 1.2+ / TLS 1.3**.
   - Cabecera **HSTS** (Strict Transport Security) preconfigurada.
   - Acceso al bucket S3 restringido con **Origin Access Control (OAC)** firmado con SigV4.
   - API Gateway protegido mediante **JWT Authorizer** asimétrico (RS256) de Cognito.

2. **En Reposo:**
   - Tablas de DynamoDB con **cifrado nativo AES-256 (KMS)** activado.
   - Bucket S3 con **SSE-S3 (AES-256)** y bloqueo público total.
   - Contraseñas de docentes en Cognito hasheadas con salt mediante PBKDF2/SHA-256.

---

## 🚀 Cómo Desplegar en AWS

### Requisitos Previos:
1. Tener instalada la herramienta [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0).
2. Tener configuradas las credenciales de AWS en tu equipo (`aws configure` o variables de entorno `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY`).

### Pasos de Ejecución:

```bash
# 1. Ingresar a la carpeta de Terraform
cd terraform

# 2. Inicializar los proveedores de Terraform
terraform init

# 3. Validar el plan de ejecución (muestra los recursos a crear sin costo)
terraform plan

# 4. Desplegar en tu cuenta de AWS
terraform apply -auto-approve
```

---

## 📤 Resultados del Despliegue (Outputs)

Al finalizar `terraform apply`, la consola mostrará:
* `cloudfront_url`: Enlace público seguro para compartir en WhatsApp con los acudientes.
* `api_gateway_url`: Endpoint de la API REST para el frontend.
* `s3_bucket_name`: Nombre del bucket para subir la página web.
* `cognito_user_pool_id` y `cognito_client_id`: Identificadores para el inicio de sesión de profesores.
