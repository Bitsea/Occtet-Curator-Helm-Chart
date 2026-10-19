# Curator configuration examples

This directory holds the template of the Curator credentials secret. The settings of an installation go in a values file of your own, applied after the chart defaults ([occtet-curator/values.yaml](../occtet-curator/values.yaml)).

| File | Content |
|---|---|
| [occtet-curator-secrets-example.yaml](occtet-curator-secrets-example.yaml) | Template of the `occtet-curator-secrets` Secret |

## Create the credentials secret

A single secret, `occtet-curator-secrets` in the `curator` namespace, holds every credential. From the repository root:

```bash
make secrets-create
```

The target creates the namespace if needed, refuses to overwrite an existing secret and prompts for each value. Passwords are not echoed. An empty answer keeps the default shown in brackets, and an empty PostgreSQL password is generated. A value set in the environment is used without prompting, even when empty: `DB_USER`, `DB_NAME`, `DB_PASSWORD`, `ORT_USERNAME`, `ORT_PASSWORD`, `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`.

> **Warning:** PostgreSQL keeps the user, database and password of its first start. When the database volume already exists, enter its current values, not the defaults.

To create it from the template instead, copy it to a name that `.gitignore` excludes, replace every `CHANGE_ME_*` value, then apply it:

```bash
cp examples/occtet-curator-secrets-example.yaml occtet-curator.secret.yaml
kubectl apply -n curator -f occtet-curator.secret.yaml
```

Never commit a filled-in copy.

| Key | Default in `make secrets-create` | Used for |
|---|---|---|
| `username` | `curator` | PostgreSQL application user (`DB_USERNAME` in the frontend and the backend services) |
| `database` | `curator` | PostgreSQL database, created at the first start (`postgresql.customUser`) |
| `postgres-password` | generated | PostgreSQL password of the superuser and the application user (`DB_PASSWORD`) |
| `ort-username` | none, required | ORT Server user (`ORT_USERNAME`) |
| `ort-password` | none, required | ORT Server password (`ORT_PASSWORD`) |
| `keycloak-client-id` | `api-access` | Keycloak client (`KEYCLOAK_CLIENT_ID`) |
| `keycloak-client-secret` | none, required | Secret of that client (`KEYCLOAK_CLIENT_SECRET` and `ORT_CLIENT_SECRET`) |

Check the secret and list its keys (requires `jq`):

```bash
make secrets-check
```

## Trust additional CA certificates

Optional. Put the certificates in a ConfigMap:

```bash
kubectl create configmap occtet-curator-cacerts -n curator --from-file=/path/to/cacerts/
```

Then reference it in your values file:

```yaml
frontend:
  caCerts:
    existingConfigMap: occtet-curator-cacerts
```

It is mounted on `/cacerts` in the frontend and in the backend services with `mountCaCerts: true` (`ortRunStart`, `processRun`). `frontend.caCerts.existingSecret` does the same from a Secret. Without either, an empty directory is mounted.

## Point the Curator at your ORT Server and Keycloak

The addresses are under `frontend.env` in your values file:

| Parameter | Example | Description |
|---|---|---|
| `frontend.env.ortBaseUrl` | `https://ort-server.example.com` | ORT Server API |
| `frontend.env.ortTokenUrl` | `https://keycloak.example.com/realms/<realm>/protocol/openid-connect/token` | Token endpoint used to call ORT Server |
| `frontend.env.ortClientId` | `api-access` | Keycloak client used to call ORT Server |
| `frontend.env.keycloakIssuerUri` | `https://keycloak.example.com/realms/<realm>` | Issuer of the user login |
| `frontend.env.frontendBaseUrl` | `https://curator.example.com/boc` | Public URL of the frontend |

Because `frontend.existingSecret` is set, the user names, passwords, client ID and client secret come from `occtet-curator-secrets`. `frontend.env.ortUsername`, `ortPassword`, `keycloakClientId` and `keycloakClientSecret` are then ignored.

To deploy with your values files (later files win; `.gitignore` excludes `values-*.yaml`):

```bash
make upgrade VALUES_FILES="values-site.yaml values-custom.yaml"
```

## Troubleshooting

```bash
# The secret and its keys
make secrets-check

# The CA certificates ConfigMap
kubectl get configmap occtet-curator-cacerts -n curator

# Names of the frontend environment variables, without their values
kubectl get pod -n curator -l app.kubernetes.io/component=frontend \
  -o jsonpath='{.items[0].spec.containers[0].env[*].name}' | tr ' ' '\n'

# Frontend logs, for authentication errors
make logs-frontend
```
