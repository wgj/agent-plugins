# Kubernetes Deploy Configuration

The deploy scripts use environment variables so Codex can adapt to local Kubernetes, k3s, and cloud clusters without rewriting shell commands.

## Core

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_DEPLOY_CONTEXT` | Production yes, preview optional | active kubecontext | Guardrail: aborts if the active context does not match. |
| `K8S_DEPLOY_NAMESPACE` | Production yes, preview optional | `codex-preview-<app>-<slug>` | Namespace for resources. |
| `K8S_DEPLOY_APP` | No | project folder name | Kubernetes app/resource name. |
| `K8S_DEPLOY_IMAGE` | Required unless building | none | Existing image to deploy. |
| `K8S_DEPLOY_REGISTRY` | Required when building | none | Registry/repository prefix used as `<registry>/<app>:<tag>`. |
| `K8S_DEPLOY_TAG` | No | git SHA or timestamp | Image tag when building. |
| `K8S_DOCKERFILE` | No | `Dockerfile` | Dockerfile path relative to the project root. |
| `K8S_DEPLOY_SKIP_PUSH` | No | `0` | Set to `1` for local-image workflows such as Docker Desktop Kubernetes. |
| `K8S_USE_IMAGE_DIGEST` | No | `1` | After push, use the image digest if Docker reports one. |
| `K8S_IMAGE_PULL_POLICY` | No | `IfNotPresent` | Container image pull policy. |
| `K8S_DRY_RUN` | No | `0` | Set to `1` to validate and diff without applying resources. |

## Ports and Rollout

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_CONTAINER_PORT` | No | `3000` | Container port exposed by the app. |
| `K8S_SERVICE_PORT` | No | same as container port | Service port. |
| `K8S_PORT_FORWARD_PORT` | No | same as service port | Local port in the generated port-forward command. |
| `K8S_REPLICAS` | No | `1` | Deployment replicas. |
| `K8S_ROLLOUT_TIMEOUT` | No | `180s` | Timeout for `kubectl rollout status`. |

## Exposure

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_EXPOSE_MODE` | No | `port-forward` | One of `port-forward`, `none`, `ingress`, or `loadbalancer`. |
| `K8S_INGRESS_HOST` | Ingress yes | none | Hostname for `K8S_EXPOSE_MODE=ingress`. |
| `K8S_INGRESS_PATH` | No | `/` | Ingress path prefix. |
| `K8S_INGRESS_CLASS` | No | none | Ingress class name. |
| `K8S_INGRESS_TLS_SECRET` | No | none | Existing TLS secret for HTTPS Ingress. |

## Cleanup

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `K8S_DELETE_NAMESPACE` | No | `auto` | `auto` deletes Codex-labeled `codex-preview-*` namespaces; `0` leaves namespaces; `1` deletes targeted namespaces. |
| `K8S_CONFIRM_PRODUCTION_CLEANUP` | Non-preview cleanup yes | `0` | Set to `1` to permit cleanup in a non-preview namespace. |

## Local Cluster Notes

Docker Desktop Kubernetes can often run an image built in the local Docker daemon when `K8S_DEPLOY_SKIP_PUSH=1` and `K8S_IMAGE_PULL_POLICY=IfNotPresent` are set.

k3s usually runs containerd, so it normally needs either a pushed image in a registry the cluster can pull from or an image imported into k3s outside this plugin.

Cloud clusters should generally use a real registry, an explicit `K8S_DEPLOY_CONTEXT`, and explicit exposure configuration.
