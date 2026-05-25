# Kubernetes

Deploy applications to Kubernetes through Codex with preview-first guardrails.

The plugin is intentionally smaller than the Vercel ecosystem plugin. It has one primary skill, `kubernetes-deploy`, backed by scripts for deployment, status, and cleanup.

## What It Does

- Deploys previews to Kubernetes with `kubectl`.
- Builds and pushes a Docker image when `K8S_DEPLOY_REGISTRY` is set, or deploys an existing image from `K8S_DEPLOY_IMAGE`.
- Defaults to `ClusterIP` plus a port-forward command, which works well for Docker Desktop Kubernetes and k3s.
- Supports explicit `Ingress` and `LoadBalancer` exposure for cloud-native clusters.
- Runs server-side manifest dry-runs, prints the active context and namespace, waits for rollout, and returns JSON.
- Cleans up Codex-managed preview resources and generated preview namespaces.

## Quick Start

```bash
skill_dir="plugins/kubernetes/skills/kubernetes-deploy"

# Existing image.
K8S_DEPLOY_IMAGE=registry.example.com/team/app:sha-123456 \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project

# Build and push.
K8S_DEPLOY_REGISTRY=registry.example.com/team \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project
```

The default exposure mode is `port-forward`. The deploy output includes a command like:

```bash
kubectl port-forward -n codex-preview-app-main svc/app 3000:3000
```

Then open:

```text
http://localhost:3000
```

Preview deploys default to a namespace beginning with `codex-preview`. If you set `K8S_DEPLOY_NAMESPACE` for a preview, the namespace must equal or begin with `K8S_PREVIEW_NAMESPACE_PREFIX`; preview deploys into namespaces such as `production` are not supported.

## Local Kubernetes

For Docker Desktop Kubernetes, you can build locally without pushing:

```bash
K8S_DEPLOY_REGISTRY=local \
K8S_DEPLOY_SKIP_PUSH=1 \
K8S_IMAGE_PULL_POLICY=IfNotPresent \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project
```

k3s usually needs a registry the cluster can pull from, or an image imported into k3s outside this plugin.

## Production

Production deploys require explicit user intent and a context guard:

```bash
K8S_DEPLOY_CONTEXT="$(kubectl config current-context)" \
K8S_DEPLOY_NAMESPACE=my-app \
K8S_DEPLOY_IMAGE=registry.example.com/team/app:sha-123456 \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project --production
```

Production deploys do not auto-create namespaces.

## Status

```bash
bash "$skill_dir/scripts/status.sh" /path/to/project
```

Set `K8S_DEPLOY_NAMESPACE` when you want one namespace instead of all Codex-managed previews for the app.

## Cleanup

```bash
bash "$skill_dir/scripts/cleanup.sh" /path/to/project
```

Cleanup deletes Deployment, Service, and Ingress resources matching Codex labels. It also auto-deletes generated preview namespaces with Codex labels when the namespace matches `K8S_PREVIEW_NAMESPACE_PREFIX`. To clean resources in a non-preview namespace, set `K8S_CONFIRM_PRODUCTION_CLEANUP=1`.

## Environment Variables

### Core

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_DEPLOY_CONTEXT` | Production yes, preview optional | active kubecontext | Abort if the active context does not match. |
| `K8S_DEPLOY_NAMESPACE` | Production yes, preview optional | `codex-preview-<app>-<slug>` | Namespace for resources. |
| `K8S_PREVIEW_NAMESPACE_PREFIX` | No | `codex-preview` | Required namespace prefix for preview deploys and cleanup. |
| `K8S_DEPLOY_APP` | No | project folder name | Kubernetes app/resource name. |
| `K8S_DEPLOY_IMAGE` | Required unless building | none | Existing image to deploy. |
| `K8S_DEPLOY_REGISTRY` | Required when building | none | Registry/repository prefix used as `<registry>/<app>:<tag>`. |
| `K8S_DEPLOY_TAG` | No | git SHA or timestamp | Image tag when building. |
| `K8S_DOCKERFILE` | No | `Dockerfile` | Dockerfile path relative to the project root. |
| `K8S_DEPLOY_SKIP_PUSH` | No | `0` | Set to `1` for local-image workflows. |
| `K8S_USE_IMAGE_DIGEST` | No | `1` | After push, use the image digest if Docker reports one. |
| `K8S_IMAGE_PULL_POLICY` | No | `IfNotPresent` | Container image pull policy. |
| `K8S_DRY_RUN` | No | `0` | Set to `1` to validate with dry-run checks without applying resources. |

### Ports and Rollout

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_CONTAINER_PORT` | No | `3000` | Container port exposed by the app. |
| `K8S_SERVICE_PORT` | No | same as container port | Service port. |
| `K8S_PORT_FORWARD_PORT` | No | same as service port | Local port in the generated port-forward command. |
| `K8S_REPLICAS` | No | `1` | Deployment replicas. |
| `K8S_ROLLOUT_TIMEOUT` | No | `180s` | Timeout for rollout status. |

### Exposure

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_EXPOSE_MODE` | No | `port-forward` | One of `port-forward`, `none`, `ingress`, or `loadbalancer`. |
| `K8S_INGRESS_HOST` | Ingress yes | none | Hostname for `K8S_EXPOSE_MODE=ingress`. |
| `K8S_INGRESS_PATH` | No | `/` | Ingress path prefix. |
| `K8S_INGRESS_CLASS` | No | none | Ingress class name. |
| `K8S_INGRESS_TLS_SECRET` | No | none | Existing TLS secret for HTTPS Ingress. |

### Cleanup

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_DELETE_NAMESPACE` | No | `auto` | `auto` deletes Codex-labeled namespaces matching `K8S_PREVIEW_NAMESPACE_PREFIX`; `0` leaves namespaces; `1` deletes targeted namespaces. |
| `K8S_CONFIRM_PRODUCTION_CLEANUP` | Non-preview cleanup yes | `0` | Set to `1` to permit cleanup in a non-preview namespace. |

## Limitations

- This is a direct-`kubectl` workflow, not GitOps. It does not open PRs against Helm, Kustomize, Argo CD, or Flux repos.
- The generated Deployment and Service are intentionally generic. Production clusters may need org-specific security contexts, resource requests, probes, policies, or admission labels.
- A port-forward URL is local to the machine running `kubectl`; it is not a shareable preview URL.
