# Ambos servicios se despliegan como contenedores en instancias
# independientes, cada uno con su propia cuenta de servicio y política de
# escalamiento (ADR-001, ASR-18). La autorización real ocurre a nivel de
# aplicación (cookie de sesión contra la colección `sesiones`), no a nivel
# de IAM de Cloud Run — por eso ambos permiten invocación pública HTTP,
# igual que hoy en desarrollo local.

resource "google_cloud_run_v2_service" "api_negocio" {
  name       = "trust4p-api-negocio"
  location   = var.region
  project    = var.project_id
  depends_on = [google_project_service.apis]

  template {
    service_account = google_service_account.api_negocio.email

    containers {
      image = var.imagen_api_negocio

      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongo_uri.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "SMTP_USUARIO"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.smtp_usuario.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "SMTP_CLAVE"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.smtp_clave.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "SMTP_HOST"
        value = "smtp.gmail.com"
      }
      env {
        name  = "SMTP_PUERTO"
        value = "587"
      }
      env {
        name  = "SERVICIO_AGENTE_URL"
        value = google_cloud_run_v2_service.servicio_agente.uri
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "api_negocio_publico" {
  name     = google_cloud_run_v2_service.api_negocio.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service" "servicio_agente" {
  name       = "trust4p-servicio-agente"
  location   = var.region
  project    = var.project_id
  depends_on = [google_project_service.apis]

  template {
    service_account = google_service_account.servicio_agente.email

    containers {
      image = var.imagen_servicio_agente

      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongo_uri.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_REGION"
        value = var.region
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "servicio_agente_publico" {
  name     = google_cloud_run_v2_service.servicio_agente.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}
