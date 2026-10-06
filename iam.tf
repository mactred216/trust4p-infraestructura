# Una cuenta de servicio por Cloud Run, con el mínimo permiso necesario
# (nunca la cuenta de servicio por defecto del proyecto, que trae permisos
# amplios que ninguno de los servicios necesita).

resource "google_service_account" "api_negocio" {
  account_id   = "trust4p-api-negocio"
  display_name = "trust4p-api-negocio (Cloud Run)"
  project      = var.project_id
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "servicio_agente" {
  account_id   = "trust4p-servicio-agente"
  display_name = "trust4p-servicio-agente (Cloud Run)"
  project      = var.project_id
  depends_on   = [google_project_service.apis]
}

# El frontend (nginx) solo sirve archivos estáticos y reenvía peticiones: no lee
# ningún secreto ni llama a otros servicios de GCP.
resource "google_service_account" "frontend" {
  account_id   = "trust4p-frontend"
  display_name = "trust4p-frontend (Cloud Run)"
  project      = var.project_id
  depends_on   = [google_project_service.apis]
}

# ---------- trust4p-api-negocio: MONGO_URI, SMTP y secreto entre servicios ----------
resource "google_secret_manager_secret_iam_member" "api_negocio_lee_mongo" {
  secret_id = google_secret_manager_secret.mongo_uri.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api_negocio.email}"
}

resource "google_secret_manager_secret_iam_member" "api_negocio_lee_smtp_usuario" {
  secret_id = google_secret_manager_secret.smtp_usuario.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api_negocio.email}"
}

resource "google_secret_manager_secret_iam_member" "api_negocio_lee_smtp_clave" {
  secret_id = google_secret_manager_secret.smtp_clave.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api_negocio.email}"
}

resource "google_secret_manager_secret_iam_member" "api_negocio_lee_api_key" {
  secret_id = google_secret_manager_secret.api_key_servicios.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api_negocio.email}"
}

# ---------- trust4p-servicio-agente: MONGO_URI, secreto entre servicios y Vertex AI ----------
resource "google_secret_manager_secret_iam_member" "servicio_agente_lee_mongo" {
  secret_id = google_secret_manager_secret.mongo_uri.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.servicio_agente.email}"
}

resource "google_secret_manager_secret_iam_member" "servicio_agente_lee_api_key" {
  secret_id = google_secret_manager_secret.api_key_servicios.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.servicio_agente.email}"
}

resource "google_project_iam_member" "servicio_agente_usa_vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.servicio_agente.email}"
}
