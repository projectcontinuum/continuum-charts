# Continuum Helm Charts

This directory contains two Helm charts for deploying Project Continuum on Kubernetes:

| Chart | Description |
|-------|-------------|
| `continuum-infra` | Infrastructure layer — PostgreSQL, Temporal, Kafka, Schema Registry, Kafka UI, Mosquitto, MinIO |
| `continuum-platform` | Application layer — API Server, Orchestration Service, Message Bridge, Workbench, Feature Base Worker, Feature Cheminformatics Worker |

## Prerequisites

- Kubernetes cluster (v1.26+)
- Helm v3.12+
- `kubectl` configured to target your cluster

## Dev vs Production Temporal Backend

The Temporal persistence backend differs between environments:

| Environment | Default Store | Visibility Store | Extra Components |
|-------------|--------------|-----------------|------------------|
| **Dev** (`values-dev.yaml`) | PostgreSQL (shared instance) | PostgreSQL (shared instance) | None |
| **Production** (`values.yaml`) | Cassandra (3-node cluster) | Elasticsearch | Cassandra + Elasticsearch subcharts |

In dev, Temporal reuses the same PostgreSQL instance deployed for the Continuum application (with separate databases `temporal` and `temporal_visibility`). This significantly reduces resource requirements — no Cassandra or Elasticsearch pods are deployed.

In production, the base `values.yaml` configures Cassandra for high-throughput durable storage and Elasticsearch for advanced workflow search/list/count capabilities.

## Architecture

```
                        ┌─────────────────────────────────────────────────┐
                        │              continuum-platform                  │
                        │                                                 │
                        │  ┌──────────┐  ┌───────────────┐  ┌──────────┐ │
                        │  │Workbench │  │  API Server   │  │ Message  │ │
                        │  │  (UI)    │  │               │  │  Bridge  │ │
                        │  └──────────┘  └───────┬───────┘  └────┬─────┘ │
                        │                        │               │       │
                        │  ┌─────────────────┐  ┌┴───────────┐   │       │
                        │  │  Feature Base   │  │Orchestration│   │       │
                        │  │     Worker      │  │  Service    │   │       │
                        │  └────────┬────────┘  └──────┬─────┘   │       │
                        │           │                  │         │       │
                        │  ┌────────┴────────┐         │         │       │
                        │  │ Feature Chemin- │         │         │       │
                        │  │  informatics    │         │         │       │
                        │  └────────┬────────┘         │         │       │
                        └───────────┼──────────────────┼─────────┼───────┘
                                    │                  │         │
                        ┌───────────┼──────────────────┼─────────┼───────┐
                        │           ▼     continuum-infra        ▼       │
                        │  ┌──────────────┐  ┌─────────┐  ┌───────────┐ │
                        │  │    Kafka      │  │Temporal │  │ Mosquitto │ │
                        │  │  (3-broker)   │  │(4 svcs) │  │  (MQTT)   │ │
                        │  └──────┬───────┘  └────┬────┘  └───────────┘ │
                        │         │               │                     │
                        │  ┌──────┴───────┐  ┌────┴──────┐              │
                        │  │Schema Registry│  │Cassandra  │  ┌────────┐ │
                        │  └──────────────┘  │(3-node)   │  │ MinIO  │ │
                        │                    └───────────┘  └────────┘ │
                        │  ┌──────────┐  ┌──────────────┐              │
                        │  │Kafka UI  │  │Elasticsearch │  ┌────────┐ │
                        │  └──────────┘  └──────────────┘  │PostgreSQL│ │
                        │                                  └────────┘ │
                        └─────────────────────────────────────────────┘
```

## Installation

### Step 1: Create the namespace

```bash
kubectl create namespace continuum
```

### Step 2: Build infrastructure chart dependencies

The `continuum-infra` chart depends on three subcharts (Temporal, Cassandra, Elasticsearch). Download them first:

```bash
helm dependency build ./continuum-infra
```

This creates a `charts/` directory containing the downloaded `.tgz` archives.

### Step 3: Configure credentials

**Option A — Dev environment (quick start):**

Use the provided dev overrides which include pre-filled passwords:

```bash
# values-dev.yaml already has dev credentials — no extra steps needed
```

**Option B — Production:**

Create a custom values file with your credentials:

```yaml
# my-values.yaml
postgresql:
  auth:
    postgresPassword: "<strong-password>"
    continuumPassword: "<strong-password>"

cassandra:
  dbUser:
    password: "<strong-password>"

minio:
  auth:
    rootUser: "<access-key>"
    rootPassword: "<secret-key>"
```

Or use existing Kubernetes Secrets (recommended for production):

```yaml
# my-values.yaml
postgresql:
  auth:
    existingSecret: my-postgres-secret   # keys: postgres-password, continuum-password

minio:
  auth:
    existingSecret: my-minio-secret      # keys: root-user, root-password
```

### Step 4: Install the infrastructure chart

```bash
# Development
helm install continuum-infra ./continuum-infra \
  -n continuum \
  -f continuum-infra/values-dev.yaml \
  --wait --timeout 15m

# Production
helm install continuum-infra ./continuum-infra \
  -n continuum \
  -f my-values.yaml \
  --wait --timeout 15m
```

The `--wait` flag ensures all pods are ready before returning. Cassandra and Elasticsearch may need several minutes to initialize.

### Step 5: Verify infrastructure is running

```bash
kubectl get pods -n continuum -l app.kubernetes.io/instance=continuum-infra
```

All pods should be in `Running` or `Completed` state. Key things to check:

```bash
# Cassandra nodes ready
kubectl get pods -n continuum -l app.kubernetes.io/component=cassandra

# Elasticsearch nodes ready
kubectl get pods -n continuum -l app.kubernetes.io/component=elasticsearch

# Temporal frontend accepting connections
kubectl get pods -n continuum -l app.kubernetes.io/component=frontend

# PostgreSQL ready
kubectl get pods -n continuum -l app.kubernetes.io/component=postgresql

# Kafka brokers ready
kubectl get pods -n continuum -l app.kubernetes.io/component=kafka
```

### Step 6: Configure platform credentials

The platform chart needs credentials to connect to infrastructure services. These must match what was set in Step 3.

For dev, the `values-dev.yaml` file has matching credentials. For production, create a values file:

```yaml
# platform-values.yaml
secrets:
  postgresql:
    username: continuum_owner
    password: "<same-password-from-step-3>"
  minio:
    rootUser: "<same-access-key>"
    rootPassword: "<same-secret-key>"

  # Or reference existing secrets:
  # existingPostgresqlSecret: my-postgres-secret   # keys: username, password
  # existingMinioSecret: my-minio-secret           # keys: root-user, root-password
```

### Step 7: Install the platform chart

```bash
# Development
helm install continuum-platform ./continuum-platform \
  -n continuum \
  -f continuum-platform/values-dev.yaml \
  --wait --timeout 10m

# Production
helm install continuum-platform ./continuum-platform \
  -n continuum \
  -f platform-values.yaml \
  --wait --timeout 10m
```

### Step 8: Verify platform is running

```bash
kubectl get pods -n continuum -l app.kubernetes.io/instance=continuum-platform
```

All pods should be `Running`. The init containers will wait for their infrastructure dependencies before starting the main containers.

### Step 9: Access the application

**Port-forward (dev):**

```bash
# Workbench UI
kubectl port-forward svc/continuum-platform-workbench 8080:8080 -n continuum

# API Server
kubectl port-forward svc/continuum-platform-api-server 8081:8080 -n continuum

# Temporal UI
kubectl port-forward svc/continuum-infra-temporal-web 8082:8080 -n continuum

# Kafka UI
kubectl port-forward svc/continuum-infra-kafka-ui 8083:8080 -n continuum

# MinIO Console
kubectl port-forward svc/continuum-infra-minio 9001:9001 -n continuum
```

**Ingress (production):**

Enable ingress in both charts' values files and configure your domain names:

```yaml
# Infrastructure ingress
ingress:
  enabled: true
  className: nginx
  hosts:
    temporalUi:
      host: temporal.yourdomain.com
    kafkaUi:
      host: kafka-ui.yourdomain.com
    minioConsole:
      host: minio-console.yourdomain.com
```

```yaml
# Platform ingress
ingress:
  enabled: true
  className: nginx
  hosts:
    workbench:
      host: continuum.yourdomain.com
    apiServer:
      host: api.continuum.yourdomain.com
```

## Smoke Test

After both charts are installed:

```bash
# Check API Server health
kubectl exec -n continuum deploy/continuum-platform-api-server -- \
  wget -qO- http://localhost:8080/actuator/health

# Check Temporal is reachable
kubectl exec -n continuum deploy/continuum-platform-api-server -- \
  nc -z continuum-infra-temporal-frontend 7233 && echo "Temporal OK"
```

## Upgrading

```bash
# Update infrastructure
helm upgrade continuum-infra ./continuum-infra \
  -n continuum \
  -f continuum-infra/values-dev.yaml \
  --wait --timeout 15m

# Update platform
helm upgrade continuum-platform ./continuum-platform \
  -n continuum \
  -f continuum-platform/values-dev.yaml \
  --wait --timeout 10m
```

## Uninstalling

Remove in reverse order (platform first, then infrastructure):

```bash
helm uninstall continuum-platform -n continuum
helm uninstall continuum-infra -n continuum
```

**Note:** PersistentVolumeClaims are not deleted by `helm uninstall`. To fully clean up:

```bash
kubectl delete pvc -n continuum -l app.kubernetes.io/instance=continuum-infra
kubectl delete pvc -n continuum -l app.kubernetes.io/instance=continuum-platform
kubectl delete namespace continuum
```

## Customization

### Scaling feature workers

Feature workers support horizontal pod autoscaling:

```yaml
featureBase:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
```

### Using an external database

To use a managed PostgreSQL (e.g., AWS RDS, GCP Cloud SQL):

```yaml
# continuum-infra values
postgresql:
  enabled: false

# continuum-platform values
infra:
  postgresql:
    host: my-rds-instance.abc123.us-east-1.rds.amazonaws.com
    port: 5432
    database: continuum
```

### Using external object storage

To use AWS S3 instead of MinIO:

```yaml
# continuum-infra values
minio:
  enabled: false

# continuum-platform values
storage:
  type: s3
  bucketName: my-continuum-bucket
  bucketRegion: us-east-1
  bucketBasePath: workflow-data
```

### Connecting to a different infra release name

If the infrastructure chart was installed with a different release name, update the platform chart's `infra` block:

```yaml
infra:
  releaseName: my-custom-infra-release
  postgresql:
    host: my-custom-infra-release-postgresql
  temporal:
    host: my-custom-infra-release-temporal-frontend
  kafka:
    brokerList: "PLAINTEXT://my-custom-infra-release-kafka-0.my-custom-infra-release-kafka-headless:19092"
  schemaRegistry:
    url: "http://my-custom-infra-release-schema-registry:8080"
  mosquitto:
    host: my-custom-infra-release-mosquitto
  minio:
    endpoint: "http://my-custom-infra-release-minio:9000"
```

## Troubleshooting

**Pods stuck in Init:**

Init containers wait for dependencies via TCP checks. Check which dependency is down:

```bash
kubectl describe pod <pod-name> -n continuum
kubectl logs <pod-name> -n continuum -c wait-for-kafka
```

**Temporal schema migration failures:**

The Temporal subchart runs schema migration Jobs automatically. Check their logs:

```bash
kubectl get jobs -n continuum -l app.kubernetes.io/instance=continuum-infra
kubectl logs job/<job-name> -n continuum
```

**Cassandra not starting:**

Cassandra requires sufficient memory. Ensure your nodes have at least 4Gi available (2Gi for dev):

```bash
kubectl describe pod -n continuum -l app.kubernetes.io/component=cassandra
```

**Kafka broker errors:**

For KRaft mode, ensure the `clusterId` has not changed between deployments. Check broker logs:

```bash
kubectl logs -n continuum continuum-infra-kafka-0
```
