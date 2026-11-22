# Guía de Bootstrap, OIDC y Pipeline de CI/CD

Esta arquitectura implementa las mejores prácticas recomendadas por el **AWS Well-Architected Framework**:
1. **Fase de Bootstrap:** Creación previa del almacenamiento del estado remoto de Terraform (S3 + DynamoDB) y configuración del proveedor de identidad OIDC.
2. **Autenticación sin Claves Estáticas (OIDC):** GitHub Actions asume un rol IAM mediante tokens criptográficos temporales (`sts:AssumeRoleWithWebIdentity`). **Cero riesgo de filtración de `AWS_ACCESS_KEY_ID` o `AWS_SECRET_ACCESS_KEY`**.
3. **Pipeline Escalonado en 3 Fases:** Despliega primero la infraestructura (bases de datos, auth, CDN), luego actualiza el backend (Lambdas) y finalmente inyecta las URLs y despliega el frontend web invalidando la caché de CloudFront.

---

## 🛠️ Paso 1: Ejecutar la Fase de Bootstrap (Una sola vez)

Antes de ejecutar el pipeline, se deben crear los recursos de arranque ejecutando Terraform dentro de la carpeta `bootstrap/`:

```bash
cd bootstrap
terraform init
terraform apply -auto-approve
```

Este comando creará:
* **Bucket S3 del Estado:** `citas-escolares-tf-state-us-east-1` (versionado y cifrado AES-256).
* **Tabla DynamoDB de Bloqueos:** `citas-escolares-tf-locks` (evita corrupción del estado).
* **Proveedor OIDC de GitHub Actions:** `token.actions.githubusercontent.com`.
* **Rol IAM de Despliegue:** `arn:aws:iam::<TU_ACCOUNT_ID>:role/citas-escolares-github-oidc-role`.

Copia el ARN del rol resultante que se mostrará en los outputs.

---

## 🔐 Paso 2: Configurar el Repositorio de GitHub

En tu repositorio de GitHub ve a:
**Settings > Secrets and variables > Actions > Variables (o Secrets)**

Crea una variable o secreto con:
* **Nombre:** `AWS_OIDC_ROLE_ARN`
* **Valor:** El ARN del rol obtenido en el Paso 1 (ej: `arn:aws:iam::123456789012:role/citas-escolares-github-oidc-role`).

---

## 🚀 Paso 3: Flujo del Pipeline (`.github/workflows/deploy.yml`)

Cada vez que hagas `git push` a la rama `main`, GitHub Actions ejecutará automáticamente:

```
┌──────────────────────────────────────────────────────────┐
│ FASE 1: INFRAESTRUCTURA (TERRAFORM)                      │
│ • Asume rol OIDC                                         │
│ • Inicializa backend remoto en S3                        │
│ • Crea/Actualiza DynamoDB, Cognito, API Gateway, S3, CDN │
│ • Exporta URLs dinámicas hacia las siguientes fases      │
└────────────────────────────┬─────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────┐
│ FASE 2: BACKEND (AWS LAMBDA)                             │
│ • Empaqueta /backend/*.py en archivos ZIP                │
│ • Actualiza el código de las 4 funciones Lambda          │
└────────────────────────────┬─────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────┐
│ FASE 3: FRONTEND (S3 WEB HOSTING + CLOUDFRONT)           │
│ • Inyecta URLs de API Gateway y Cognito en config.js     │
│ • Sube /frontend al bucket S3                            │
│ • Invalida caché de CloudFront (create-invalidation)     │
│ • ¡Cambios visibles de inmediato en celulares!           │
└──────────────────────────────────────────────────────────┘
```
