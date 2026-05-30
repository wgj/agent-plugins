# Agent Plugins

Personal Codex plugin marketplace for small, focused agent plugins.

## Plugins

- `kubernetes`: deploy applications to Kubernetes with preview-first defaults, port-forward exposure, rollout checks, status inspection, and cleanup.
- `goal-prompt-builder`: create concise Codex Goal Mode prompts from rough objectives.
- `codex-best-practices`: bootstrap Codex best-practice docs, project guidance, product specs, ExecPlans, ExecPlan waves, reusable workflow notes, and validation/review contracts.
- `quo-call-transcripts`: match project `PEOPLE.md` contacts to Quo calls, download recordings, transcribe with OpenAI, and write project-local call transcript and summary files.

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

Install every plugin advertised by the `wgj` marketplace:

```bash
codex plugin add goal-prompt-builder@wgj
codex plugin add kubernetes@wgj
codex plugin add codex-best-practices@wgj
codex plugin add quo-call-transcripts@wgj
```

For local development, add this checkout as the marketplace source instead:

```bash
codex plugin marketplace add /path/to/agent-plugins
codex plugin add goal-prompt-builder@wgj
codex plugin add kubernetes@wgj
codex plugin add codex-best-practices@wgj
codex plugin add quo-call-transcripts@wgj
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
