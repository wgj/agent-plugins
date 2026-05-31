---
name: codex-keychain-environment
description: "Create or revise a repository-local Codex Environment that loads local secrets from macOS Keychain into the current worktree. Use when a user wants worktree-safe local secret handling, Keychain-backed .env generation, or a reusable setup pattern that avoids searching sibling worktrees for secrets."
---

# Codex Keychain Environment

Create a repo-owned Codex Environment that prepares each worktree from a secure local source of truth: macOS Keychain. Use this when a project has local provider secrets that Codex needs for validation, deployment setup, or API smoke tests, but those secrets should not live in git, chat, shell history, or sibling worktrees.

## When To Use

Use this skill when the user asks to:

- move local `.env` secrets into macOS Keychain
- make Codex setup work consistently across git worktrees
- add a checked-in `.codex/environments/environment.toml`
- generate ignored `.env` files from Keychain during environment setup
- stop agents from searching other worktrees for secrets

Do not use this pattern for live production secret rotation by itself. Provider-side secret creation, deployment env updates, and live-mode payment changes need explicit user approval and project-specific validation.

## Workflow

1. Inspect the destination repo first. Read `.gitignore`, existing `.codex/environments/`, bootstrap scripts, docs such as `docs/codex/configuration.md`, and any setup guide that mentions local secrets.
2. Choose a stable Keychain service name, usually the repo or product domain such as `example.com`. Account names should match env var names, for example `STRIPE_SECRET_KEY`.
3. Add a helper script such as `scripts/<project>-keychain-env.sh` with these operations:
   - `check`: report only presence and safe classifications, never values.
   - `import-current-env`: import only from the current worktree `.env` by default, or from an explicit `PROJECT_ENV_FILE`.
   - `write-env`: write an ignored current-worktree `.env` from Keychain.
   - `exec -- <command>`: run a command with Keychain-loaded env vars.
4. Add or update `.codex/environments/environment.toml` so `[setup].script` runs a repo bootstrap script.
5. Add or update a bootstrap script such as `scripts/bootstrap_worktree.sh`. It should install local dependencies and then call the Keychain helper to write the current worktree `.env`.
6. Keep `AGENTS.md` lean. Prefer a short pointer only if needed. Put detailed rules in `docs/codex/configuration.md`, setup docs, or the helper's `--help`.
7. Update setup docs to say Keychain is the local source of truth and sibling worktree secret search is forbidden unless the user grants a one-time exception.
8. Validate shell syntax, the bootstrap path, `check`, `write-env`, and `exec -- ...`. Use temporary Keychain services with dummy values to test migration and optional-secret behavior.

## Implementation Rules

- Never print secret values.
- Never pass secret values as command-line arguments. For macOS `security add-generic-password`, use the prompted/stdin form with `-w` as the last option instead of `-w "$value"`.
- Never search sibling worktrees for `.env` files unless the user explicitly grants a one-time exception.
- Preserve or emit required non-secret env settings when regenerating `.env`, such as `SITE_URL`, local port settings, or feature flags.
- Do not make provider-specific optional values mandatory. If a token can be scoped to one account/store/project, its account/store/project ID should be optional and exported only when present.
- Write generated `.env` files with restrictive permissions and rely on `.gitignore` to keep them untracked.
- Make `exec -- ...` export the same effective environment as `write-env`: required secrets, optional secrets when present, and required non-secret defaults.
- Keep the helper project-specific enough to be obvious, but generic enough that it can be reused from every worktree of the same repo.

## Suggested File Shape

Use existing repo conventions when they differ, but this shape works well:

```text
.codex/environments/environment.toml
scripts/bootstrap_worktree.sh
scripts/<project>-keychain-env.sh
docs/codex/configuration.md
```

Minimal environment descriptor:

```toml
version = 1
name = "local"

[setup]
script = "./scripts/bootstrap_worktree.sh"

[[actions]]
name = "Bootstrap worktree"
icon = "tool"
command = "./scripts/bootstrap_worktree.sh"

[[actions]]
name = "Check local secrets"
icon = "debug"
command = "./scripts/<project>-keychain-env.sh check"

[[actions]]
name = "Export local env"
icon = "tool"
command = "./scripts/<project>-keychain-env.sh write-env"
```

## Validation Checklist

Run the relevant subset before handing back:

```bash
bash -n scripts/bootstrap_worktree.sh scripts/<project>-keychain-env.sh
scripts/<project>-keychain-env.sh check
scripts/<project>-keychain-env.sh write-env
scripts/<project>-keychain-env.sh exec -- env
git diff --check
```

For helper behavior, create a temporary Keychain service with dummy values and confirm:

- import works without placing secret values in process arguments
- missing optional secrets do not fail bootstrap or `exec`
- optional secrets are written/exported when present
- non-secret local settings are preserved or defaulted

## Reporting

Report:

- Keychain service name and env var account names, without values
- files changed
- whether `.env` was generated and ignored
- validation commands run
- any secrets still missing or provider-side steps that remain
