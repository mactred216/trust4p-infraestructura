variable "project_id" {
  description = "ID del proyecto de GCP ya existente (creado manualmente, con facturación y Vertex AI habilitados). No se crea por Terraform."
  type        = string
  default     = "trust-4p"
}

variable "region" {
  description = "Región donde se despliegan los servicios y donde está disponible Qwen3-Next-80B-Instruct como Model as a Service."
  type        = string
  default     = "us-central1"
}

variable "mongo_uri" {
  description = "Cadena de conexión a MongoDB Atlas (con credenciales). Nunca hardcodear: viene de terraform.tfvars, que está en .gitignore."
  type        = string
  sensitive   = true
}

variable "smtp_usuario" {
  description = "Cuenta de Gmail usada para enviar notificaciones (RF-45)."
  type        = string
  sensitive   = true
}

variable "smtp_clave" {
  description = "Contraseña de aplicación de Gmail para SMTP."
  type        = string
  sensitive   = true
}

variable "imagen_api_negocio" {
  description = "Imagen de trust4p-api-negocio en Artifact Registry (tag actualizado por el pipeline de CI, no por Terraform)."
  type        = string
  default     = "us-central1-docker.pkg.dev/trust-4p/trust4p-imagenes/api-negocio:latest"
}

variable "imagen_servicio_agente" {
  description = "Imagen de trust4p-servicio-agente en Artifact Registry (tag actualizado por el pipeline de CI, no por Terraform)."
  type        = string
  default     = "us-central1-docker.pkg.dev/trust-4p/trust4p-imagenes/servicio-agente:latest"
}
