---
name: kubernetes-deploy
description: Deploy, inspect, port-forward, and clean up web applications on Kubernetes with safe preview defaults. Use for requests involving Kubernetes, kubectl, k8s, k3s, Docker Desktop Kubernetes, cloud clusters, preview deploys, production deploys, Ingress, LoadBalancer Services, or cleanup of Codex-managed Kubernetes resources.
---

# Kubernetes Deploy

Deploy applications to Kubernetes through `kubectl`. Preview deploys are the default; production deploys require an explicit user request.

## Safety Defaults

- Treat the active kubecontext as dangerous until checked. Show the context, namespace, app name, image, and exposure mode before mutating resources.
- Preview deploys use Codex-managed labels and default to an isolated namespace named `codex-preview-<app>-<slug>`.
- Default exposure is private `ClusterIP` plus a port-forward command. Do not describe this as a public or shareable URL.
- `Ingress` and `LoadBalancer` exposure are explicit opt-ins through configuration.
- Never use `latest` for generated image tags. Prefer commit SHA or timestamp tags.
- Production requires explicit user wording, `--production`, `K8S_DEPLOY_NAMESPACE`, and a context guard through `K8S_DEPLOY_CONTEXT`.
- Cleanup must target Codex-managed labels/namespaces. Do not delete arbitrary Kubernetes resources.

## Quick Start

Set the skill path, then deploy a preview:

```bash
skill_dir="<path-to-this-skill>"
bash "$skill_dir/scripts/deploy.sh" /path/to/project
```

If the project already has an image:

```bash
K8S_DEPLOY_IMAGE=registry.example.com/team/app:sha-123456 \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project
```

If the project should be built and pushed:

```bash
K8S_DEPLOY_REGISTRY=registry.example.com/team \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project
```

For Docker Desktop Kubernetes only, a local image can be built without pushing:

```bash
K8S_DEPLOY_REGISTRY=local \
K8S_DEPLOY_SKIP_PUSH=1 \
K8S_IMAGE_PULL_POLICY=IfNotPresent \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project
```

The script returns JSON with the namespace, app, image, exposure mode, local URL, port-forward command, and public URL when one exists.

## Status

Use status after a deploy or when asked what is running:

```bash
bash "$skill_dir/scripts/status.sh" /path/to/project
```

If multiple previews exist for the same app, status reports all Codex-managed preview namespaces it can find. Set `K8S_DEPLOY_NAMESPACE` to target one namespace.

## Cleanup

Cleanup is part of the workflow. Use it when the user asks to tear down a preview, remove a test deploy, or clean stale Codex-managed Kubernetes resources:

```bash
bash "$skill_dir/scripts/cleanup.sh" /path/to/project
```

By default, cleanup deletes generated preview resources and auto-deletes `codex-preview-*` namespaces that carry Codex labels. For non-preview namespaces, it refuses unless `K8S_CONFIRM_PRODUCTION_CLEANUP=1` is set.

## Production

Only run production when the user explicitly asks for production. Require a stable namespace and context guard:

```bash
K8S_DEPLOY_CONTEXT="$(kubectl config current-context)" \
K8S_DEPLOY_NAMESPACE=my-app \
K8S_DEPLOY_IMAGE=registry.example.com/team/app:sha-123456 \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project --production
```

After a production deploy, report the rollout result and the exact context/namespace used.

## Exposure Modes

- `K8S_EXPOSE_MODE=port-forward` creates a `ClusterIP` Service and returns a local port-forward command. This is the default.
- `K8S_EXPOSE_MODE=none` creates the Deployment and Service without a URL.
- `K8S_EXPOSE_MODE=ingress` creates an Ingress and requires `K8S_INGRESS_HOST`.
- `K8S_EXPOSE_MODE=loadbalancer` creates a `LoadBalancer` Service and reports the hostname/IP if the cloud provider assigns one.

For full configuration details, read `references/configuration.md`.

## Output To User

Report the useful endpoint:

- For port-forward, show the local URL and the exact port-forward command.
- For Ingress or LoadBalancer, show the public URL/host when available.
- If the URL is pending, say that the Kubernetes resources are applied and the external address is still pending.

Also report the namespace, app name, and cleanup command for previews.
