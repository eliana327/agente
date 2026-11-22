variable "aws_region" {
  description = "Región de AWS para el despliegue del bootstrap"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre base del proyecto"
  type        = string
  default     = "citas-escolares"
}

variable "github_org_or_user" {
  description = "Nombre de usuario u organización de GitHub donde reside el repositorio"
  type        = string
  default     = "eliana327"
}

variable "github_repo_name" {
  description = "Nombre del repositorio en GitHub"
  type        = string
  default     = "agente"
}
