terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # El estado vive en un bucket de GCS (versionado) para que cualquier persona
  # del equipo trabaje sobre el mismo estado. El bucket se crea una sola vez a
  # mano, antes del primer `terraform init` (ver README).
  backend "gcs" {
    bucket = "trust-4p-tfstate"
    prefix = "trust4p"
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

# URLs deterministas de Cloud Run (https://SERVICIO-NUMERODELPROYECTO.REGION.run.app).
# Se calculan en vez de leer el atributo `uri` de cada servicio para evitar un
# ciclo: el frontend necesita las URLs de las APIs y las APIs la del frontend
# (enlaces de los correos y CORS).
locals {
  numero_proyecto     = data.google_project.trust4p.number
  url_api_negocio     = "https://trust4p-api-negocio-${local.numero_proyecto}.${var.region}.run.app"
  url_servicio_agente = "https://trust4p-servicio-agente-${local.numero_proyecto}.${var.region}.run.app"
  url_frontend        = var.url_frontend != "" ? var.url_frontend : "https://trust4p-frontend-${local.numero_proyecto}.${var.region}.run.app"
}

# ---------- APIs habilitadas ----------
resource "google_project_service" "apis" {
  for_each = toset([
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
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

  # Cada despliegue sube una imagen etiquetada con el SHA del commit: se
  # conservan las más recientes y se limpian las antiguas.
  cleanup_policies {
    id     = "conservar-recientes"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
  cleanup_policies {
    id     = "borrar-antiguas"
    action = "DELETE"
    condition {
      older_than = "2592000s" # 30 días
    }
  }
}
