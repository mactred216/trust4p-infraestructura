# Los tres servicios se despliegan como contenedores en instancias
# independientes, cada uno con su propia cuenta de servicio y política de
# escalamiento (ADR-001, ASR-18). La autorización real ocurre a nivel de
# aplicación (cookie de sesión contra la colección `sesiones`), no a nivel
# de IAM de Cloud Run — por eso los tres permiten invocación pública HTTP.
#
# Topología: el navegador solo habla con el frontend. Su nginx sirve la SPA y
# reenvía /api/negocio y /api/agente a cada backend, de modo que la cookie de
# sesión (HttpOnly, Secure, SameSite=Strict) pertenece a un único origen y no
# se necesita CORS. (Las URLs *.run.app están en la lista de sufijos públicos:
# la cookie de un backend no se compartiría con el frontend directamente.)
#
# Las imágenes las actualiza el pipeline de CI con el SHA del commit; por eso
# Terraform ignora el cambio de `image` (no lo revierte a :latest).

resource "google_cloud_run_v2_service" "api_negocio" {
  name     = "trust4p-api-negocio"
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"

  # Cloud Run valida el acceso a los secretos al crear la revisión: los
  # permisos deben existir antes.
  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.api_negocio_lee_mongo,
    google_secret_manager_secret_iam_member.api_negocio_lee_smtp_usuario,
    google_secret_manager_secret_iam_member.api_negocio_lee_smtp_clave,
    google_secret_manager_secret_iam_member.api_negocio_lee_api_key,
    google_secret_manager_secret_version.mongo_uri_valor,
    google_secret_manager_secret_version.smtp_usuario_valor,
    google_secret_manager_secret_version.smtp_clave_valor,
    google_secret_manager_secret_version.api_key_servicios_valor,
  ]

  template {
    service_account = google_service_account.api_negocio.email
    timeout         = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    containers {
      image = var.imagen_api_negocio

      # La evaluación del diagnóstico corre como tarea en segundo plano DESPUÉS
      # de responder (ASR-02: el resultado ya está guardado y el agente solo
      # redacta la narrativa). Con CPU solo durante la petición esa tarea se
      # congelaría: se mantiene la CPU asignada mientras la instancia vive.
      resources {
        cpu_idle = false
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

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
        name = "API_KEY_SERVICIOS"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key_servicios.secret_id
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
        name  = "SMTP_REMITENTE"
        value = var.smtp_remitente
      }
      env {
        name  = "SERVICIO_AGENTE_URL"
        value = local.url_servicio_agente
      }
      env {
        name  = "URL_FRONTEND"
        value = local.url_frontend
      }
      env {
        name  = "CORS_ORIGENES"
        value = local.url_frontend
      }
      # Saltos de proxy delante de la API (frontend/nginx + frontend de Google):
      # el límite de peticiones por origen usa la IP real de la persona.
      env {
        name  = "SALTOS_PROXY"
        value = "2"
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
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
  name     = "trust4p-servicio-agente"
  location = var.region
  project  = var.project_id

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.servicio_agente_lee_mongo,
    google_secret_manager_secret_iam_member.servicio_agente_lee_api_key,
    google_secret_manager_secret_version.mongo_uri_valor,
    google_secret_manager_secret_version.api_key_servicios_valor,
  ]

  template {
    service_account = google_service_account.servicio_agente.email
    # Una evaluación con Vertex AI (con reintentos y espera exponencial) puede
    # tardar más de un minuto.
    timeout = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = var.imagen_servicio_agente

      resources {
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

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
        name = "API_KEY_SERVICIOS"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key_servicios.secret_id
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
      # Qwen3-Next-80B solo se ofrece por el endpoint 'global'.
      env {
        name  = "GCP_INFERENCIA_REGION"
        value = "global"
      }
      env {
        name  = "CORS_ORIGENES"
        value = local.url_frontend
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }
}

resource "google_cloud_run_v2_service_iam_member" "servicio_agente_publico" {
  name     = google_cloud_run_v2_service.servicio_agente.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service" "frontend" {
  name       = "trust4p-frontend"
  location   = var.region
  project    = var.project_id
  depends_on = [google_project_service.apis]

  template {
    service_account = google_service_account.frontend.email

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = var.imagen_frontend

      resources {
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      # El nginx de la imagen reenvía a estas URLs (plantilla de nginx).
      env {
        name  = "API_NEGOCIO_URL"
        value = local.url_api_negocio
      }
      env {
        name  = "API_AGENTE_URL"
        value = local.url_servicio_agente
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }
}

resource "google_cloud_run_v2_service_iam_member" "frontend_publico" {
  name     = google_cloud_run_v2_service.frontend.name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}
