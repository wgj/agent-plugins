# Agent Plugins

Personal Codex plugin marketplace for small, focused agent plugins.

## Plugins

- `kubernetes`: deploy applications to Kubernetes with preview-first defaults, port-forward exposure, rollout checks, status inspection, and cleanup.
- `prompt-builder`: create short Codex prompts from rough objectives.
- `codex-best-practices`: bootstrap Codex best-practice docs, project guidance, product specs, ExecPlans, ExecPlan waves, reusable workflow notes, and validation/review contracts.
- `call-notes`: match project `PEOPLE.md` contacts to business calls, download recordings, transcribe with OpenAI, and write project-local call transcript and summary files.
- `summarize`: use the Summarize CLI to summarize and extract content from URLs, videos, PDFs, and local files.
- `contacts`: create, search, update, upsert, and delete local macOS Contacts records through a native Swift CLI using Apple's Contacts framework.

## Marketplace

This repo includes a local marketplace file at:

```text
.agents/plugins/marketplace.json
```

The marketplace entries point at `./plugins/<plugin-name>` so the repo can be installed or shared as a Codex plugin source.

### Codex Action

For Codex environments that check out this repo, use the checked-in local environment action when you want to install or refresh the local marketplace plugins.

The action is defined at:

```text
.codex/environments/environment.toml
```

It appears in Codex as:

```text
Install plugins
```

Run it on demand from Codex. It is not a setup script and should not run on every environment or worktree creation.

The action runs:

```bash
./scripts/install-agent-plugins.sh
```

That script registers and refreshes the GitHub marketplace as `wgj`, installs every plugin listed in `.agents/plugins/marketplace.json` into the Codex plugin cache, and enables each plugin. The install surface stays versioned with the repo instead of living as copied README lines. For local development against a checked-out marketplace, run it with `AGENT_PLUGINS_MARKETPLACE_SOURCE=/path/to/agent-plugins`.

### Manual Setup

Use this path when you are not checking out this repo in a Codex environment.

Install and enable the marketplace from GitHub with the same setup script:

```bash
curl -fsSL https://raw.githubusercontent.com/wgj/agent-plugins/main/scripts/install-agent-plugins.sh | bash
```

Or add the marketplace directly:

```bash
codex plugin marketplace add https://github.com/wgj/agent-plugins --ref main
```

Then install and enable each plugin id listed in `.agents/plugins/marketplace.json` under `~/.codex/config.toml`.

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
