terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------- Proyecto ----------
# El proyecto ya existe (se creó manualmente en la consola de GCP, con
# facturación y Vertex AI habilitados — ver ADR-007 de trust4p-api-negocio).
# Se referencia con 'data', nunca con 'resource': declararlo como resource
# haría que Terraform intentara CREAR un proyecto nuevo con este ID, lo que
# falla (el ID ya está tomado) o, si el ID no coincidiera exacto, crearía un
# segundo proyecto vacío sin nada de lo ya configurado.
data "google_project" "trust4p" {
  project_id = var.project_id
}

# ---------- APIs habilitadas ----------
resource "google_project_service" "apis" {
  for_each = toset([
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# ---------- Repositorio de contenedores ----------
resource "google_artifact_registry_repository" "trust4p" {
  repository_id = "trust4p-imagenes"
  location      = var.region
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}
