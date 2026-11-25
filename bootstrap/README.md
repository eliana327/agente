# Guía de Bootstrap, OIDC Multirrepositorio y Pipeline de CI/CD

Esta arquitectura implementa las mejores prácticas recomendadas por el **AWS Well-Architected Framework**:
1. **Fase de Bootstrap Centralizada (Multirrepositorio):** Creación del almacenamiento central del estado remoto de Terraform (S3 + DynamoDB) y configuración del proveedor de identidad OIDC (`token.actions.githubusercontent.com`).
2. **Autenticación sin Claves Estáticas (OIDC):** GitHub Actions asume un rol IAM mediante tokens criptográficos temporales (`sts:AssumeRoleWithWebIdentity`). La política de confianza está configurada para admitir cualquier repositorio del usuario/organización (`repo:eliana327/*`).
3. **Reutilización entre Proyectos:** El backend remoto (S3 y DynamoDB) y el rol IAM OIDC (`arn:aws:iam::079301214534:role/citas-escolares-github-oidc-role`) son compartidos por todos los proyectos (como `agente` y `autoscaling`) usando diferentes prefijos de estado (keys).

---

## 🛠️ Recursos Creados en AWS

* **Bucket S3 del Estado:** `citas-escolares-tf-state-us-east-1` (versionado y cifrado AES-256).
* **Tabla DynamoDB de Bloqueos:** `citas-escolares-tf-locks` (evita corrupción del estado).
* **Proveedor OIDC de GitHub Actions:** `arn:aws:iam::079301214534:oidc-provider/token.actions.githubusercontent.com`.
* **Rol IAM de Despliegue:** `arn:aws:iam::079301214534:role/citas-escolares-github-oidc-role`.

---

## 🔐 Configuración en GitHub Actions

En cualquier repositorio de tu cuenta de GitHub (ej. `agente` o `autoscaling`), ve a:
**Settings > Secrets and variables > Actions > Variables** (o Secrets)

Crea una variable:
* **Nombre:** `AWS_OIDC_ROLE_ARN`
* **Valor:** `arn:aws:iam::079301214534:role/citas-escolares-github-oidc-role`
*(Si no se define la variable, los pipelines ya incluyen este valor por defecto)*.

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
