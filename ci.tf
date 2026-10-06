# CI/CD sin llaves de servicio: GitHub Actions se autentica con OIDC mediante
# Workload Identity Federation y actúa como una cuenta de servicio de
# despliegue con permisos mínimos. Solo los repositorios del proyecto, y solo
# desde la rama de despliegue, pueden obtener credenciales.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  project                   = var.project_id
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Sin esta condición cualquier repositorio de GitHub podría intentar
  # autenticarse; aquí se limita a los del proyecto y a la rama de despliegue.
  attribute_condition = "assertion.ref == \"refs/heads/${var.rama_despliegue}\" && assertion.repository in [${join(", ", [for r in var.repositorios_github : "\"${r}\""])}]"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "despliegue" {
  account_id   = "trust4p-despliegue"
  display_name = "Despliegue desde GitHub Actions"
  project      = var.project_id
  depends_on   = [google_project_service.apis]
}

resource "google_service_account_iam_member" "github_usa_despliegue" {
  for_each           = toset(var.repositorios_github)
  service_account_id = google_service_account.despliegue.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${each.value}"
}

# Subir imágenes al repositorio de contenedores.
resource "google_artifact_registry_repository_iam_member" "despliegue_publica_imagenes" {
  project    = var.project_id
  location   = google_artifact_registry_repository.trust4p.location
  repository = google_artifact_registry_repository.trust4p.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.despliegue.email}"
}

# Desplegar nuevas revisiones de Cloud Run.
resource "google_project_iam_member" "despliegue_actualiza_cloud_run" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.despliegue.email}"
}

# Para desplegar una revisión que corre como una cuenta de servicio, quien
# despliega debe poder "actuar como" ella (solo las tres de este proyecto).
resource "google_service_account_iam_member" "despliegue_actua_como_runtime" {
  for_each = {
    api_negocio     = google_service_account.api_negocio.name
    servicio_agente = google_service_account.servicio_agente.name
    frontend        = google_service_account.frontend.name
  }
  service_account_id = each.value
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.despliegue.email}"
}
