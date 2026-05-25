# Agent Plugins

Personal Codex plugin marketplace for small, focused agent plugins.

## Plugins

- `kubernetes`: deploy applications to Kubernetes with preview-first defaults, port-forward exposure, rollout checks, status inspection, and cleanup.
- `goal-prompt-builder`: create concise Codex Goal Mode prompts from rough objectives.

## Marketplace

This repo includes a local marketplace file at:

```text
.agents/plugins/marketplace.json
```

The marketplace entries point at `./plugins/<plugin-name>` so the repo can be installed or shared as a Codex plugin source.

## Codex App Skill Setup

For a new computer, install shared Codex skills separately from this plugin marketplace.

The recommended setup for `autoreview` is to keep the canonical OpenClaw skill repo in the local GitHub workspace and symlink the skill into Codex App:

```bash
mkdir -p ~/Repositories/GitHub/openclaw
git clone https://github.com/openclaw/agent-skills.git ~/Repositories/GitHub/openclaw/agent-skills

cd ~/Repositories/GitHub/openclaw/agent-skills
scripts/install-skills --target ~/.codex/skills autoreview
```

This creates:

```text
~/.codex/skills/autoreview -> ~/Repositories/GitHub/openclaw/agent-skills/skills/autoreview
```

Use `--mode copy` if the new machine should have a frozen local copy instead of a symlink:

```bash
scripts/install-skills --mode copy --target ~/.codex/skills autoreview
```

Start a new Codex App thread after installing so the available skill list is reloaded.

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
