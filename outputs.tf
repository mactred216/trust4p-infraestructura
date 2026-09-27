output "url_api_negocio" {
  description = "URL pública de trust4p-api-negocio en Cloud Run."
  value       = google_cloud_run_v2_service.api_negocio.uri
}

output "url_servicio_agente" {
  description = "URL pública de trust4p-servicio-agente en Cloud Run."
  value       = google_cloud_run_v2_service.servicio_agente.uri
}

output "artifact_registry_repositorio" {
  description = "Ruta del repositorio de Artifact Registry para hacer push de las imágenes."
  value       = "${google_artifact_registry_repository.trust4p.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.trust4p.repository_id}"
}
