# Codex Best Practices

Codex Best Practices bootstraps repository-local Codex operating guidance: `AGENTS.md`, product specs, ExecPlans, validation and review docs, MCP decision notes, skill candidates, automation candidates, and session/subagent practices.

Use it when a project needs durable context that a cold-start Codex session can read instead of reconstructing from chat history.

## What It Provides

- a `codex-best-practices` skill for creating or revising Codex project guidance
- source guidance distilled from the OpenAI Codex best-practices page, the ExecPlans article, and a private reference project's docs pattern
- a conservative helper script that initializes missing docs scaffolding, starter best-practice docs, product specs, and active ExecPlans
- optional examples for `.codex/config.toml` and root-level `code_review.md`

## Helper Script

From a target project root:

```bash
python /path/to/plugins/codex-best-practices/skills/codex-best-practices/scripts/scaffold_codex_docs.py .
```

Create a spec and matching active ExecPlan:

```bash
python /path/to/plugins/codex-best-practices/skills/codex-best-practices/scripts/scaffold_codex_docs.py . \
  --spec-title "Buyer Intake Review" \
  --plan-title "Implement Buyer Intake Review"
```

Create optional Codex config and review files:

```bash
python /path/to/plugins/codex-best-practices/skills/codex-best-practices/scripts/scaffold_codex_docs.py . \
  --with-config-example \
  --with-code-review-file
```

The script writes only missing scaffold files by default. Existing files are preserved unless `--overwrite` is passed for a newly requested spec or plan path.
