# trust4p-infraestructura

Infraestructura como código (Terraform) del sistema Trust 4P: prepara el proyecto de GCP ya existente (`trust-4p`) para desplegar [`trust4p-api-negocio`](https://github.com/mactred216/trust4p-api-negocio) y [`trust4p-servicio-agente`](https://github.com/mactred216/trust4p-servicio-agente) en Cloud Run.

## Qué crea

- Habilita las APIs necesarias (Secret Manager, Cloud Run, Vertex AI, Artifact Registry).
- Un repositorio de Artifact Registry (`trust4p-imagenes`) para las imágenes Docker de ambos servicios.
- Los secretos `MONGO_URI`, `SMTP_USUARIO`, `SMTP_CLAVE` en Secret Manager.
- Una cuenta de servicio por servicio (no la cuenta por defecto del proyecto), con permiso mínimo: cada una solo lee los secretos que su servicio necesita; `trust4p-servicio-agente` además tiene `roles/aiplatform.user` para invocar Vertex AI.
- Los dos servicios de Cloud Run, con las variables de entorno y secretos ya montados.

**No crea el proyecto de GCP** — `trust-4p` ya existe (creado manualmente, con facturación y Vertex AI habilitados) y se referencia con un `data source`, nunca con `resource`.

## Primer despliegue — orden importante

Los recursos de Cloud Run (`cloud_run.tf`) apuntan a una imagen en Artifact Registry que **todavía no existe** la primera vez. `terraform apply` fallará en esos dos recursos si el repositorio de imágenes está vacío. Por eso el primer despliegue va en dos pasos:

```bash
cp terraform.tfvars.example terraform.tfvars
# completar terraform.tfvars con los valores reales

terraform init
terraform apply -target=google_project_service.apis \
                 -target=google_artifact_registry_repository.trust4p \
                 -target=google_secret_manager_secret.mongo_uri \
                 -target=google_secret_manager_secret.smtp_usuario \
                 -target=google_secret_manager_secret.smtp_clave
```

Esto habilita las APIs, crea el repositorio de imágenes y los secretos, sin tocar Cloud Run todavía. Con el repositorio ya creado, construye y sube al menos una imagen de cada servicio (desde cada repo, con Docker configurado contra Artifact Registry):

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t us-central1-docker.pkg.dev/trust-4p/trust4p-imagenes/api-negocio:latest .
docker push us-central1-docker.pkg.dev/trust-4p/trust4p-imagenes/api-negocio:latest
```

(y lo mismo para `trust4p-servicio-agente`, con el tag `servicio-agente:latest`, desde su propio repo)

Y ya con las imágenes existentes, el resto:

```bash
terraform apply
```

Despliegues posteriores (una vez ya existe todo) son un solo `terraform apply` normal — este rodeo es únicamente para el arranque en frío.

## Variables sensibles

`terraform.tfvars` nunca se sube al repositorio (está en `.gitignore`) — contiene la cadena de conexión real a MongoDB y la contraseña de aplicación de SMTP. `*.tfstate` tampoco se sube: el estado de Terraform puede contener valores sensibles en texto plano.
