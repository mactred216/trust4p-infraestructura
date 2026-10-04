output "url_frontend" {
  description = "URL pública de la aplicación (frontend). Es la única que usan las personas."
  value       = google_cloud_run_v2_service.frontend.uri
}

output "url_api_negocio" {
  description = "URL de trust4p-api-negocio en Cloud Run (el navegador entra por el frontend)."
  value       = google_cloud_run_v2_service.api_negocio.uri
}

output "url_servicio_agente" {
  description = "URL de trust4p-servicio-agente en Cloud Run (el navegador entra por el frontend)."
  value       = google_cloud_run_v2_service.servicio_agente.uri
}

output "artifact_registry_repositorio" {
  description = "Ruta del repositorio de Artifact Registry para hacer push de las imágenes."
  value       = "${google_artifact_registry_repository.trust4p.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.trust4p.repository_id}"
}

output "github_workload_identity_provider" {
  description = "Valor del secreto/variable GCP_WORKLOAD_IDENTITY_PROVIDER en los repositorios de GitHub."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_cuenta_de_despliegue" {
  description = "Valor del secreto/variable GCP_SERVICE_ACCOUNT en los repositorios de GitHub."
  value       = google_service_account.despliegue.email
}
