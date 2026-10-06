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

variable "smtp_remitente" {
  description = "Remitente visible de los correos (por defecto, el usuario SMTP)."
  type        = string
  default     = ""
}

variable "url_frontend" {
  description = "URL pública del frontend si se usa un dominio propio (con https://). Vacío = la URL por defecto de Cloud Run."
  type        = string
  default     = ""
}

variable "imagen_api_negocio" {
  description = "Imagen inicial de trust4p-api-negocio: una imagen de ejemplo de Google que permite crear el servicio antes de que exista la real. Los despliegues los hace el pipeline de CI con el SHA del commit; Terraform no revierte ese cambio."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "imagen_servicio_agente" {
  description = "Imagen inicial de trust4p-servicio-agente (ver imagen_api_negocio)."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "imagen_frontend" {
  description = "Imagen inicial de trust4p-frontend (ver imagen_api_negocio)."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "repositorios_github" {
  description = "Repositorios de GitHub (propietario/nombre) autorizados a desplegar mediante Workload Identity Federation, sin llaves de servicio."
  type        = list(string)
  default = [
    "mactred216/trust4p-api-negocio",
    "mactred216/trust4p-servicio-agente",
    "sroa544/trust4p-frontend",
  ]
}

variable "rama_despliegue" {
  description = "Única rama desde la que el pipeline puede autenticarse en GCP y desplegar."
  type        = string
  default     = "main"
}

variable "servicios_encendidos" {
  description = "true = los tres servicios atienden al público. false = se retira la invocación pública: nadie puede usarlos y, como escalan a cero, no generan costo. Se vuelve a encender con true; nada se borra (datos, secretos, imágenes)."
  type        = bool
  default     = true
}
