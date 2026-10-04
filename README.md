# trust4p-infraestructura

Infraestructura como código (Terraform) del sistema Trust 4P: prepara el proyecto de GCP ya existente (`trust-4p`) para desplegar en Cloud Run el frontend ([`trust4p-frontend`](https://github.com/sroa544/trust4p-frontend)), la API de negocio ([`trust4p-api-negocio`](https://github.com/mactred216/trust4p-api-negocio)) y el servicio del agente ([`trust4p-servicio-agente`](https://github.com/mactred216/trust4p-servicio-agente)), con despliegue continuo desde GitHub Actions.

## Arquitectura de despliegue

```
Navegador ──HTTPS──▶ trust4p-frontend (Cloud Run, nginx)
                       ├─ /                 → aplicación (SPA)
                       ├─ /api/negocio/...  → trust4p-api-negocio     (Cloud Run) ──▶ MongoDB Atlas
                       └─ /api/agente/...   → trust4p-servicio-agente (Cloud Run) ──▶ MongoDB Atlas, Vertex AI
trust4p-api-negocio ──(X-API-Key)──▶ trust4p-servicio-agente
```

- **Un solo origen para el navegador.** El nginx del frontend reenvía las dos APIs. La cookie de sesión (`HttpOnly`, `Secure`, `SameSite=Strict`) pertenece al frontend y no hace falta CORS. (Las URLs `*.run.app` están en la lista de sufijos públicos: si el navegador hablara directo con cada backend, la cookie de uno no llegaría al otro.)
- **Autorización a nivel de aplicación** (cookie de sesión contra `sesiones`, permisos por rol), no con IAM de Cloud Run: los tres servicios admiten invocación pública, igual que en desarrollo.
- **Servicio a servicio**: la API de negocio llama al agente con `X-API-Key` (`API_KEY_SERVICIOS`, secreto generado por Terraform y montado en ambos).
- **CPU siempre asignada** en la API de negocio: la evaluación del diagnóstico corre en segundo plano *después* de responder (ASR-02); con CPU solo durante la petición esa tarea se congelaría.
- **Límite de peticiones por IP real**: la API toma la IP de `X-Forwarded-For` según `SALTOS_PROXY=2` (frontend de Google + nginx); sin eso todas las personas compartirían un único cupo.

## Qué crea

- Habilita las APIs necesarias (Secret Manager, Cloud Run, Vertex AI, Artifact Registry, IAM, STS).
- Repositorio de Artifact Registry `trust4p-imagenes` (conserva las 10 imágenes más recientes y borra las de más de 30 días).
- Secretos `MONGO_URI`, `SMTP_USUARIO`, `SMTP_CLAVE` y `API_KEY_SERVICIOS` en Secret Manager.
- Una cuenta de servicio por servicio, con el permiso mínimo: cada una solo lee los secretos que necesita; el agente además tiene `roles/aiplatform.user`; el frontend no lee ninguno.
- Los tres servicios de Cloud Run con sus variables y secretos montados.
- **CI/CD sin llaves**: Workload Identity Federation para GitHub Actions y la cuenta `trust4p-despliegue` (solo sube imágenes, actualiza Cloud Run y actúa como las tres cuentas de servicio). Solo los tres repositorios del proyecto, y solo desde `main`, pueden autenticarse.

**No crea el proyecto de GCP** — `trust-4p` ya existe (creado manualmente, con facturación y Vertex AI habilitados) y se referencia con un `data source`, nunca con `resource`.

## Primer despliegue

Requiere `gcloud` autenticado con permisos de propietario sobre `trust-4p` y Terraform ≥ 1.6.

1. **Bucket del estado** (una sola vez; el estado de Terraform puede contener valores sensibles):

   ```bash
   gcloud storage buckets create gs://trust-4p-tfstate --project=trust-4p --location=us-central1 --uniform-bucket-level-access
   gcloud storage buckets update gs://trust-4p-tfstate --versioning
   ```

2. **Variables** (`terraform.tfvars` está en `.gitignore`):

   ```bash
   cp terraform.tfvars.example terraform.tfvars   # completar MONGO_URI y SMTP
   terraform init
   terraform plan
   terraform apply
   ```

   Los servicios de Cloud Run nacen con una imagen de ejemplo de Google (`hello`), de modo que `apply` funciona antes de que existan las imágenes reales y no hay que hacerlo en dos pasos.

3. **Conectar GitHub** — en cada repositorio (api-negocio, servicio-agente, frontend) crear estas *variables* (Settings → Secrets and variables → Actions → Variables) con los valores de `terraform output`:

   | Variable | Valor |
   |---|---|
   | `GCP_WORKLOAD_IDENTITY_PROVIDER` | `terraform output github_workload_identity_provider` |
   | `GCP_SERVICE_ACCOUNT` | `terraform output github_cuenta_de_despliegue` |
   | `VITE_BOTPRESS_CLIENT_ID` | (solo frontend) identificador público del asistente |

   Opcional en api-negocio y servicio-agente: el *secreto* `MONGO_URI_PRUEBAS` (una base de pruebas, nunca la real) activa las pruebas de integración en CI.

4. **Primer despliegue real**: ejecutar el workflow *Despliegue* de cada repositorio (Actions → Despliegue → Run workflow), o integrar a `main`. Orden recomendado: servicio-agente, api-negocio, frontend. Después, `terraform output url_frontend` es la dirección de la aplicación.

5. **Datos iniciales** (solo si la base es nueva; si se reutiliza la de desarrollo ya existen): el arranque de la API crea índices, permisos y sectores. El modelo de madurez 4P versión 2026.1 se siembra con el script idempotente, y la primera cuenta de administrador debe crearse aparte en la base (no hay registro público de administradores):

   ```bash
   python -m scripts.sembrar_modelo_4p        # desde trust4p-api-negocio, con MONGO_URI de producción
   ```

6. **MongoDB Atlas**: Cloud Run no tiene IP de salida fija. En *Network Access* de Atlas hay que permitir `0.0.0.0/0` (la protección es la credencial y TLS) o configurar una salida con IP estática (Cloud NAT + conector VPC) y permitir solo esa IP.

## Despliegues posteriores

- **Aplicación**: integrar a `main` en cualquiera de los tres repositorios. El workflow verifica (lint, pruebas), construye la imagen con el SHA del commit, la sube y despliega la revisión nueva; luego comprueba que responde. Para volver atrás: `gcloud run services update-traffic SERVICIO --to-revisions=REVISION=100`.
- **Infraestructura**: cambios por pull request (el CI ejecuta `fmt` y `validate`); el `apply` se ejecuta a mano tras revisar el `plan`. Terraform ignora el cambio de imagen de cada servicio (lo gestiona el pipeline).

## Respaldos y operación

Ver [docs/runbook-respaldo.md](docs/runbook-respaldo.md): respaldo y restauración de MongoDB, rotación de secretos y comprobaciones tras un despliegue.

## Variables sensibles

`terraform.tfvars` nunca se sube al repositorio (está en `.gitignore`) — contiene la cadena de conexión real a MongoDB y la contraseña de aplicación de SMTP. `*.tfstate` tampoco se sube: el estado remoto vive en el bucket versionado `trust-4p-tfstate`.
