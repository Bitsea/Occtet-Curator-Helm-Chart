# Occtet Curator Chart Values

This document describes the configuration values for the Occtet Curator Helm chart.

## Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.namespace` | Kubernetes namespace for all resources | `curator` |

## Image Registry

| Parameter | Description | Default |
|-----------|-------------|---------|
| `imageRegistry` | Container image registry for all images | `ghcr.io/bitsea` |

## Frontend Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.enabled` | Enable frontend deployment | `true` |
| `frontend.name` | Frontend component name | `frontend` |
| `frontend.image.repository` | Frontend image repository | `occtet-frontend` |
| `frontend.image.tag` | Frontend image tag | `latest` |
| `frontend.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `frontend.replicaCount` | Number of frontend replicas | `1` |
| `frontend.service.type` | Service type (ClusterIP/NodePort/LoadBalancer) | `ClusterIP` |
| `frontend.service.port` | Service port | `8090` |
| `frontend.service.targetPort` | Container port | `8090` |
| `frontend.ingress.enabled` | Enable Ingress | `false` |
| `frontend.ingress.className` | Ingress class name | `nginx` |
| `frontend.ingress.hosts[0].host` | Ingress hostname | `curator` |
| `frontend.env.javaOpts` | JVM options passed through `JAVA_OPTS` | `-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError` |
| `frontend.resources.limits.cpu` | CPU limit | `2000m` |
| `frontend.resources.limits.memory` | Memory limit | `4Gi` |
| `frontend.resources.requests.cpu` | CPU request | `500m` |
| `frontend.resources.requests.memory` | Memory request | `2Gi` |

## PostgreSQL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.image.registry` | PostgreSQL image registry | `docker.io` |
| `postgresql.image.repository` | PostgreSQL image repository | `pgvector/pgvector` |
| `postgresql.image.tag` | PostgreSQL image tag | `pg17-trixie` |
| `postgresql.auth.username` | PostgreSQL username | `occtetuser` |
| `postgresql.auth.password` | PostgreSQL password (use existingSecret instead) | `""` |
| `postgresql.auth.database` | Database name | `occtet_boc` |
| `postgresql.auth.postgresPassword` | Admin password (use existingSecret instead) | `""` |
| `postgresql.auth.existingSecret` | **RECOMMENDED**: Name of existing secret | `""` |
| `postgresql.primary.persistence.enabled` | Enable persistence | `true` |
| `postgresql.primary.persistence.size` | PVC size | `20Gi` |
| `postgresql.primary.persistence.storageClass` | Storage class | `""` |
| `postgresql.primary.resources.limits.cpu` | CPU limit | `2000m` |
| `postgresql.primary.resources.limits.memory` | Memory limit | `4Gi` |
| `postgresql.service.type` | Service type | `ClusterIP` |
| `postgresql.service.ports.postgresql` | PostgreSQL port | `5432` |

**IMPORTANT**: Always use `postgresql.auth.existingSecret` for production deployments. See [SECRETS.md](../SECRETS.md) for details.

## NATS Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nats.enabled` | Enable NATS | `true` |
| `nats.name` | NATS component name | `nats` |
| `nats.image.repository` | NATS image repository | `nats` |
| `nats.image.tag` | NATS image tag | `latest` |
| `nats.replicaCount` | Number of NATS replicas | `1` |
| `nats.jetstream.enabled` | Enable JetStream | `true` |
| `nats.jetstream.maxMemory` | Max memory for JetStream | `512M` |
| `nats.jetstream.maxFile` | Max file storage | `10G` |
| `nats.persistence.enabled` | Enable persistence | `true` |
| `nats.persistence.size` | PVC size | `10Gi` |
| `nats.service.ports.client` | Client port | `4222` |
| `nats.service.ports.monitoring` | Monitoring port | `8222` |
| `nats.resources.limits.cpu` | CPU limit | `1000m` |
| `nats.resources.limits.memory` | Memory limit | `2Gi` |

## Ollama Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ollama.enabled` | Enable Ollama AI service | `true` |
| `ollama.name` | Ollama component name | `ollama` |
| `ollama.image.repository` | Ollama image repository | `ollama/ollama` |
| `ollama.image.tag` | Ollama image tag | `latest` |
| `ollama.replicaCount` | Number of replicas | `1` |
| `ollama.service.port` | Service port | `11434` |
| `ollama.persistence.enabled` | Enable persistence | `true` |
| `ollama.persistence.size` | PVC size | `50Gi` |
| `ollama.resources.limits.cpu` | CPU limit | `4000m` |
| `ollama.resources.limits.memory` | Memory limit | `8Gi` |

## Backend Services Configuration

Each backend service has the following structure:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backend.services.<service>.enabled` | Enable this service | `true` |
| `backend.services.<service>.name` | Service name | varies |
| `backend.services.<service>.image.repository` | Image repository | varies |
| `backend.services.<service>.image.tag` | Image tag | `latest` |
| `backend.services.<service>.replicaCount` | Number of replicas | `1` |
| `backend.services.<service>.resources.limits.cpu` | CPU limit | `1000m` |
| `backend.services.<service>.resources.limits.memory` | Memory limit | `2Gi` |

### Available Services

- `licensematcher` - License identification and matching
- `aiCopyrightfilter` - AI-powered copyright filtering
- `copyrightfilter` - Traditional copyright filtering
- `fossReport` - FOSS report generation
- `vulnerability` - Security vulnerability analysis
- `aiLicensematcher` - AI-enhanced license matching
- `spdx` - SPDX document management
- `cyclonedx` - CycloneDX document management
- `cyclonedxExport` - CycloneDX export functionality
- `download` - Package download service
- `spdxExport` - SPDX export functionality

## Persistence Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.projectData.enabled` | Enable project data PVC | `true` |
| `persistence.projectData.size` | PVC size | `100Gi` |
| `persistence.projectData.storageClass` | Storage class | `""` |
| `persistence.projectData.accessMode` | Access mode | `ReadWriteOnce` |

## Service Account

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `serviceAccount.name` | Service account name | `""` |

## Security Context

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext.fsGroup` | Filesystem group | `1000` |
| `securityContext.runAsNonRoot` | Run as non-root | `false` |
| `securityContext.runAsUser` | User ID | `1000` |

## Node Selection

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector labels | `{}` |
| `tolerations` | Pod tolerations | `[]` |
| `affinity` | Pod affinity rules | `{}` |

## Example Values Files

### Minimal Configuration (with secrets)

```yaml
# minimal-values.yaml
postgresql:
  auth:
    existingSecret: occtet-curator-postgresql-secret
```

### Production Configuration

```yaml
# production-values.yaml
imageRegistry: ghcr.io/bitsea

frontend:
  replicaCount: 3
  image:
    tag: v1.0.0
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - host: curator.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: curator-tls
        hosts:
          - curator.example.com
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
    requests:
      cpu: 1000m
      memory: 4Gi

postgresql:
  auth:
    existingSecret: occtet-curator-postgresql-secret
  primary:
    persistence:
      size: 100Gi
      storageClass: fast-ssd
    resources:
      limits:
        cpu: 4000m
        memory: 16Gi

nats:
  replicaCount: 3
  persistence:
    size: 50Gi

ollama:
  persistence:
    size: 200Gi
  resources:
    limits:
      cpu: 8000m
      memory: 16Gi

persistence:
  projectData:
    size: 500Gi
    storageClass: fast-ssd
```

### Development Configuration

```yaml
# dev-values.yaml
frontend:
  image:
    tag: dev
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 250m
      memory: 512Mi

postgresql:
  auth:
    existingSecret: occtet-curator-postgresql-secret
  primary:
    persistence:
      size: 10Gi

nats:
  persistence:
    size: 5Gi

ollama:
  enabled: false

backend:
  services:
    aiCopyrightfilter:
      enabled: false
    aiLicensematcher:
      enabled: false

persistence:
  projectData:
    size: 20Gi
```

### Disable AI Services

```yaml
# no-ai-values.yaml
ollama:
  enabled: false

backend:
  services:
    aiCopyrightfilter:
      enabled: false
    aiLicensematcher:
      enabled: false
```

## Resource Planning

### Minimum Requirements
- **CPU**: 8 cores
- **Memory**: 16Gi
- **Storage**: 180Gi (20Gi PostgreSQL + 10Gi NATS + 50Gi Ollama + 100Gi project data)

### Recommended Production
- **CPU**: 24 cores
- **Memory**: 64Gi
- **Storage**: 500Gi+ (depends on project size)

### Storage Breakdown
- PostgreSQL: 20-100Gi (depends on dataset size)
- NATS: 10-50Gi (message retention)
- Ollama: 50-200Gi (AI models)
- Project Data: 100Gi-1Ti (analysis results, source code)

---

**Version**: See [Chart.yaml](Chart.yaml)  
**Last Updated**: March 2026
