# Continuum Helm Charts

This directory contains three Helm charts for deploying Project Continuum on Kubernetes:


| Chart                | Description                                                                                                                            | Required |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| `continuum-infra`    | Core infrastructure services — PostgreSQL, Temporal, Kafka, Schema Registry, Kafka UI, Mosquitto, MinIO                               | Yes      |
| `continuum-platform` | Application services — API Server, Orchestration Service, Message Bridge, Workbench, Feature Workers                                  | Yes      |
| `continuum-sso`      | Optional Single Sign-On — OAuth2 Proxy with Keycloak OIDC                                                                              | No       |

## Prerequisites

- Kubernetes cluster (v1.26+)
- Helm v3.12+
- `kubectl` configured to target your cluster

## Quick Launch with Minikube

> [!TIP]
> **Want to try Continuum in under 5 minutes?** Just copy-paste the commands below — no configuration needed.

**Prerequisites:** [Minikube](https://minikube.sigs.k8s.io/docs/start/) and [Helm](https://helm.sh/docs/intro/install/) installed.

```bash
# Start minikube (4 CPUs, 8GB RAM recommended)
minikube start --cpus=4 --memory=8192

# Create the namespaces
kubectl create namespace continuum-dev
kubectl create namespace continuum-workbench-dev

# Build infra chart dependencies (downloads Temporal subchart)
helm dependency build ./continuum-infra

# Install infrastructure (PostgreSQL, Temporal, Kafka, MinIO, Mosquitto)
helm install continuum-infra ./continuum-infra \
  -n continuum-dev \
  -f continuum-infra/values-dev.yaml \
  --wait --timeout 15m

# Install platform (Cloud Gateway, API Server, Cluster Manager, Workers)
helm install continuum-platform ./continuum-platform \
  -n continuum-dev \
  -f continuum-platform/values-dev.yaml \
  --wait --timeout 10m

# Verify everything is running
kubectl get pods -n continuum-dev
```

Once all pods are `Running`, port-forward the Cloud Gateway:

```bash
kubectl port-forward svc/continuum-platform-cloud-gateway 8080:8080 -n continuum-dev
```

Open the UI in your browser: **http://localhost:8080/cluster-manager/ui/**

## Dev vs Production Temporal Backend

The Temporal persistence backend differs between environments:


| Environment                    | Default Store                | Visibility Store             | Extra Components                    |
| ------------------------------ | ---------------------------- | ---------------------------- | ----------------------------------- |
| **Dev** (`values-dev.yaml`)    | PostgreSQL (shared instance) | PostgreSQL (shared instance) | None                                |
| **Production** (`values.yaml`) | Cassandra (3-node cluster)   | Elasticsearch                | Cassandra + Elasticsearch subcharts |

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
# MQTT Server
kubectl port-forward svc/continuum-infra-mosquitto 31884:1884 -n continuum

# API Server
kubectl port-forward svc/continuum-platform-api-server 8080:8080 -n continuum

# Workbench UI
kubectl port-forward svc/continuum-platform-workbench 3002:8080 -n continuum

# Temporal UI [optional]
kubectl port-forward svc/continuum-infra-temporal-web 8082:8080 -n continuum

# Kafka UI [optional]
kubectl port-forward svc/continuum-infra-kafka-ui 8083:8080 -n continuum

# MinIO Console [optional]
kubectl port-forward svc/continuum-infra-minio 9001:9001 -n continuum
```
**Open Workbench in browser** 

Open workbench in your browser: [Continuum-Workbench](http://localhost:3002/#/home/node)

**Ingress (production):**

For external access, configure your own Ingress resources or use an ingress controller.
If you need OAuth2 authentication with Keycloak, deploy the `continuum-sso` chart:

**Step 1: Create the Keycloak database in PostgreSQL**

First, connect to the PostgreSQL pod and create the Keycloak database:

```bash
# Connect to PostgreSQL
kubectl exec -it continuum-infra-postgresql-0 -n continuum-dev -- psql -U postgres

# Run these SQL commands:
CREATE USER keycloak WITH PASSWORD 'dev-keycloak-pass';
CREATE DATABASE keycloak OWNER keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
\c keycloak
GRANT ALL ON SCHEMA public TO keycloak;
\q
```

**Step 2: Create the required Kubernetes secrets**

```bash
# Create the Keycloak admin credentials secret
kubectl create secret generic keycloak-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=admin \
  -n continuum-dev

# Create the OAuth2 Proxy cookie secret (32-byte random string)
kubectl create secret generic oauth2-proxy-cookie \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n continuum-dev

# Create the Keycloak client credentials secret (placeholder - update after Keycloak setup)
kubectl create secret generic oauth2-proxy-client-creds \
  --from-literal=client-id=REPLACE_WITH_CLIENT_ID \
  --from-literal=client-secret=REPLACE_WITH_CLIENT_SECRET \
  -n continuum-dev
```

**Step 3: Install the SSO chart**

```bash
helm install continuum-sso ./continuum-sso \
  -n continuum-dev \
  -f continuum-sso/values-dev.yaml \
  --wait
```

**Step 4: Configure Keycloak realm and client**

```bash
# Port-forward to Keycloak
kubectl port-forward svc/continuum-sso-keycloak 8080:8080 -n continuum-dev

# Open http://localhost:8080 and login with admin/admin
# 1. Create a realm named "continuum"
# 2. Create a client with:
#    - Client ID: continuum
#    - Client authentication: ON
#    - Valid redirect URIs:
#      - https://auth.192.168.49.2.nip.io/oauth2/callback (OAuth2 Proxy callback)
#      - https://continuum.192.168.49.2.nip.io/auth/keycloak-callback (Landing page callback for direct IdP flows)
#    - Web origins: https://*.192.168.49.2.nip.io
# 3. Copy the client secret from Credentials tab
```

**Step 5: Configure Identity Providers (optional - for SSO buttons)**

To enable "Sign in with Google/GitHub/etc" buttons on the landing page:

1. In Keycloak, go to Identity Providers
2. Add providers (Google, GitHub, etc.) with their respective OAuth credentials
3. Use the provider alias (e.g., `google`, `github`) - the landing page uses these as `kc_idp_hint`

The landing page will redirect directly to Keycloak with `kc_idp_hint` parameter, which skips the Keycloak login page and goes straight to the selected IdP.

**Step 6: Update the oauth2-proxy-client-creds secret with the actual client secret**

```bash
# Delete and recreate with the actual secret
kubectl delete secret oauth2-proxy-client-creds -n continuum-dev
kubectl create secret generic oauth2-proxy-client-creds \
  --from-literal=client-id=continuum \
  --from-literal=client-secret=YOUR_ACTUAL_CLIENT_SECRET \
  -n continuum-dev

# Restart oauth2-proxy to pick up the new secret
kubectl rollout restart deployment continuum-sso-oauth2-proxy -n continuum-dev
```

Then configure your ingress annotations to use oauth2-proxy:

```yaml
# Example ingress with oauth2-proxy authentication
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-protected-ingress
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "http://continuum-sso-oauth2-proxy.continuum-dev.svc.cluster.local:4180/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://auth.192.168.49.2.nip.io/oauth2/start?rd=$escaped_request_uri"
spec:
  # ... your ingress spec
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
