# ==============================================================================
# CONFIGURACIÓN DEL BACKEND REMOTO EN S3 CON BLOQUEO DYNAMODB
# ==============================================================================
# Una vez ejecutado el bootstrap, este bloque asegura que el estado de Terraform
# no se guarde localmente, sino de forma segura y colaborativa en AWS.

terraform {
  backend "s3" {
    bucket         = "citas-escolares-tf-state-us-east-1"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "citas-escolares-tf-locks"
    encrypt        = true
  }
}
