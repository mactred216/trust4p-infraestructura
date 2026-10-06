# Runbook de operación: respaldo, restauración y secretos

Cubre la brecha B16 de la validación (respaldos y recuperación). La base de datos de Trust 4P es MongoDB Atlas (base `trust4p`, compartida por la API de negocio y el servicio del agente).

## 1. Respaldo

**Atlas con respaldos nativos (clúster M10 o superior):** activar *Cloud Backup* con instantáneas diarias y retención de 7 días como mínimo; es la opción recomendada para producción.

**Clúster gratuito (M0) o respaldo adicional manual** — volcado lógico a un bucket de GCS:

```bash
# Requiere MongoDB Database Tools (mongodump) y gcloud autenticado.
export MONGO_URI="mongodb+srv://..."          # lectura sobre la base trust4p
FECHA=$(date +%Y%m%d-%H%M)
mongodump --uri "$MONGO_URI" --db trust4p --gzip --archive="trust4p-$FECHA.archive.gz"
gcloud storage cp "trust4p-$FECHA.archive.gz" gs://trust-4p-respaldos/
shred -u "trust4p-$FECHA.archive.gz" 2>/dev/null || rm -f "trust4p-$FECHA.archive.gz"
```

Crear el bucket una vez, con versionado y borrado automático a los 30 días:

```bash
gcloud storage buckets create gs://trust-4p-respaldos --project=trust-4p --location=us-central1 --uniform-bucket-level-access
gcloud storage buckets update gs://trust-4p-respaldos --versioning
echo '{"rule":[{"action":{"type":"Delete"},"condition":{"age":30}}]}' > ciclo.json
gcloud storage buckets update gs://trust-4p-respaldos --lifecycle-file=ciclo.json
```

Frecuencia sugerida: diaria. El volcado contiene datos personales: el bucket no debe ser público y el acceso se limita a quienes administran la plataforma (Ley 1581 de 2012).

## 2. Restauración

1. Elegir el respaldo: `gcloud storage ls gs://trust-4p-respaldos/`.
2. **Probar primero en una base distinta** para no pisar datos vivos:

   ```bash
   gcloud storage cp gs://trust-4p-respaldos/trust4p-FECHA.archive.gz .
   mongorestore --uri "$MONGO_URI_DESTINO" --gzip --archive=trust4p-FECHA.archive.gz \
     --nsFrom 'trust4p.*' --nsTo 'trust4p_restauracion.*'
   ```
3. Verificar conteos de `usuarios`, `empresas`, `diagnosticos` y `modelos_madurez` en la base restaurada.
4. Para recuperación real: detener escrituras (poner los servicios en mantenimiento o `--max-instances=0`), restaurar sobre `trust4p` con `--drop`, volver a levantar y comprobar el inicio de sesión y un diagnóstico.
5. Las colecciones `sesiones` y `tokens` caducan solas; tras restaurar, las personas deben iniciar sesión de nuevo.

Probar la restauración al menos una vez por trimestre.

## 3. Secretos

| Secreto | Dónde vive | Rotación |
|---|---|---|
| `MONGO_URI` | Secret Manager | Crear nuevo usuario en Atlas → actualizar `terraform.tfvars` → `terraform apply` → forzar nueva revisión (`gcloud run services update SERVICIO --update-env-vars ROTADO=$(date +%s)`) → borrar el usuario viejo |
| `SMTP_CLAVE` | Secret Manager | Generar otra contraseña de aplicación de Gmail y repetir el mismo procedimiento |
| `API_KEY_SERVICIOS` | Secret Manager (generado por Terraform) | `terraform apply -replace=random_password.api_key_servicios` y nueva revisión de api-negocio y servicio-agente |

Los servicios leen `latest` de cada secreto al arrancar: tras rotar hay que desplegar una revisión nueva. Nunca se versionan secretos en los repositorios ni en las variables de GitHub (solo los identificadores públicos de Workload Identity).

## 4. Comprobaciones tras un despliegue

```bash
URL=$(terraform output -raw url_frontend)
curl -fsS "$URL/salud"                                  # nginx
curl -fsS "$URL/api/negocio/v1/sectores"                # proxy → API de negocio → MongoDB
curl -fsS "$URL/api/agente/openapi.json" | head -c 100  # proxy → servicio del agente
```

Luego, en el navegador: inicio de sesión, un diagnóstico de punta a punta (el índice se calcula al instante; la narrativa del agente puede tardar unos segundos) y la bitácora de auditoría.

Logs: `gcloud run services logs read SERVICIO --project trust-4p --region us-central1 --limit 100`.
