# Codex Best Practices

Codex Best Practices bootstraps repository-local Codex operating guidance: `AGENTS.md`, product specs, ExecPlans, validation and review docs, MCP decision notes, skill candidates, automation candidates, and session/subagent practices.

It is based on OpenAI's [Codex best practices](https://developers.openai.com/codex/learn/best-practices#plan-first-for-difficult-tasks) guidance: start with the right task context, plan before difficult work, make guidance reusable with `AGENTS.md`, configure Codex consistently, validate and review changes, connect external context with MCP, turn repeated workflows into skills, automate stable workflows, and organize long-running work with sessions and subagents.

Use it when a project needs durable context that a cold-start Codex session can read instead of reconstructing from chat history. Some best practices can be scaffolded generically, but the important ones need destination-project context: the plugin includes focused skills that inspect the target repo before creating or revising guidance.

## What It Provides

- a `codex-best-practices` skill for creating or revising Codex project guidance
- focused destination-project skills for project guidance, planning docs, and workflow systems
- source guidance distilled from the OpenAI Codex best-practices page, the ExecPlans article, and a private reference project's docs pattern
- a conservative helper script that initializes missing docs scaffolding, starter best-practice docs, product specs, and active ExecPlans
- optional examples for `.codex/config.toml` and root-level `code_review.md`

## Skills

- `codex-best-practices`: orchestrates the full best-practices setup or audit.
- `codex-project-guidance`: inspects a destination project and creates or revises `AGENTS.md`, prompting, configuration, validation, and review guidance.
- `codex-planning-docs`: creates or revises product specs, `docs/PLANS.md`, and active ExecPlans for plan-first work.
- `codex-workflow-systems`: inspects a destination project for MCP, skill, automation, session, worktree, and subagent guidance.

## Helper Script

From a target project root:

```bash
python3 /path/to/plugins/codex-best-practices/skills/codex-best-practices/scripts/scaffold_codex_docs.py .
```

Create a spec and matching active ExecPlan:

```bash
python3 /path/to/plugins/codex-best-practices/skills/codex-best-practices/scripts/scaffold_codex_docs.py . \
  --spec-title "Buyer Intake Review" \
  --plan-title "Implement Buyer Intake Review"
```

Create optional Codex config and review files:

```bash
python3 /path/to/plugins/codex-best-practices/skills/codex-best-practices/scripts/scaffold_codex_docs.py . \
  --with-config-example \
  --with-code-review-file
```

The script writes only missing scaffold files by default. Existing files are preserved unless `--overwrite` is passed for a newly requested spec or plan path, with one routing exception: if an existing `AGENTS.md` does not contain the Codex best-practices marker, the script appends a short guidance section instead of replacing the file.
