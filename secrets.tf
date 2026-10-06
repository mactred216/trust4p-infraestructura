# RNF-08: las credenciales del servicio de inferencia y la cadena de
# conexión de la base de datos se obtienen del gestor de secretos en el
# arranque de cada servicio, nunca se incorporan al artefacto desplegable.

resource "google_secret_manager_secret" "mongo_uri" {
  secret_id = "MONGO_URI"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "mongo_uri_valor" {
  secret      = google_secret_manager_secret.mongo_uri.id
  secret_data = var.mongo_uri
}

resource "google_secret_manager_secret" "smtp_usuario" {
  secret_id = "SMTP_USUARIO"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "smtp_usuario_valor" {
  secret      = google_secret_manager_secret.smtp_usuario.id
  secret_data = var.smtp_usuario
}

resource "google_secret_manager_secret" "smtp_clave" {
  secret_id = "SMTP_CLAVE"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "smtp_clave_valor" {
  secret      = google_secret_manager_secret.smtp_clave.id
  secret_data = var.smtp_clave
}

# ADR-001: secreto compartido entre los dos backends para autenticar las
# llamadas de servicio a servicio (no es una sesión de usuario). Se genera aquí
# y se monta en ambos servicios, de modo que nunca se escribe a mano.
resource "random_password" "api_key_servicios" {
  length  = 48
  special = false
}

resource "google_secret_manager_secret" "api_key_servicios" {
  secret_id = "API_KEY_SERVICIOS"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "api_key_servicios_valor" {
  secret      = google_secret_manager_secret.api_key_servicios.id
  secret_data = random_password.api_key_servicios.result
}
