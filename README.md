# Agent Plugins

Personal Codex plugin marketplace for small, focused agent plugins.

## Plugins

- `kubernetes`: deploy applications to Kubernetes with preview-first defaults, port-forward exposure, rollout checks, status inspection, and cleanup.
- `goal-prompt-builder`: create concise Codex Goal Mode prompts from rough objectives.
- `codex-best-practices`: bootstrap Codex best-practice docs, project guidance, product specs, ExecPlans, reusable workflow notes, and validation/review contracts.

## Marketplace

This repo includes a local marketplace file at:

```text
.agents/plugins/marketplace.json
```

The marketplace entries point at `./plugins/<plugin-name>` so the repo can be installed or shared as a Codex plugin source.

Install the marketplace from GitHub:

```bash
codex plugin marketplace add https://github.com/wgj/agent-plugins --ref main
```

Then install a plugin:

```bash
codex plugin add kubernetes@wgj
```

For local development, add this checkout as the marketplace source instead:

```bash
codex plugin marketplace add /path/to/agent-plugins
codex plugin add kubernetes@wgj
```

## Global AGENTS.md

The source-controlled copy of the global Codex guidance lives at:

```text
global/AGENTS.md
```

Sync it to the active Codex home file with:

```bash
scripts/sync-global-agents.sh apply
```

Check for drift with:

```bash
scripts/sync-global-agents.sh check
```

Use `scripts/sync-global-agents.sh pull` only when the live global file intentionally changed first and should become the repo source of truth.

## Kubernetes Quick Start

Use the Kubernetes plugin when asking Codex to deploy a project to Docker Desktop Kubernetes, k3s, or a cloud Kubernetes cluster.

```bash
skill_dir="plugins/kubernetes/skills/kubernetes-deploy"

# Deploy an existing image as a preview.
K8S_DEPLOY_IMAGE=registry.example.com/team/app:sha-123456 \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project

# Or build and push from a Dockerfile.
K8S_DEPLOY_REGISTRY=registry.example.com/team \
  bash "$skill_dir/scripts/deploy.sh" /path/to/project
```

Preview deploys default to a `codex-preview-*` namespace and return a port-forward command instead of creating public exposure. See [plugins/kubernetes/README.md](plugins/kubernetes/README.md) for the full environment variable contract.
