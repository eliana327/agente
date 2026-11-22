variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Prefijo para nombrar los recursos"
  type        = string
  default     = "citas-escolares"
}

variable "school_name" {
  description = "Nombre de la institución educativa"
  type        = string
  default     = "Colegio San Martin"
}
