---
name: codex-project-guidance
description: "Inspect a destination repository and create or revise Codex project guidance for AGENTS.md, prompting, configuration, validation, and review. Use when a user asks to implement Codex best practices in a repo, audit AGENTS.md, add prompting guidance, document Codex config, define validation commands, or create review guidance."
---

# Codex Project Guidance

Create the destination-project guidance needed for these Codex best-practices sections:

- Strong first use: Context and prompts
- Make guidance reusable with `AGENTS.md`
- Configure Codex for consistency
- Improve reliability with testing and review
- Common mistakes that can be prevented by project-local instructions

## Workflow

1. Inspect the destination project before writing. Read `AGENTS.md`, `.codex/config.toml`, `README.md`, package manifests, build files, CI files, test config, and existing docs under `docs/` or `.agents/`.
2. Run the scaffold helper if the project is missing the Codex docs envelope. Resolve this path relative to this skill directory:

```bash
python3 ../codex-best-practices/scripts/scaffold_codex_docs.py /path/to/project
```

3. Keep `AGENTS.md` concise. It should route future agents to focused docs and name the commands, constraints, and done criteria that matter most.
4. Customize `docs/codex/prompting.md` so Goal, Context, Constraints, and Done when examples match the project.
5. Customize `docs/codex/configuration.md` with project-specific model, reasoning, sandbox, approval, profile, MCP, and environment decisions. Do not write secrets.
6. Customize `docs/codex/validation-and-review.md` from real project commands. Prefer non-mutating checks. Include skipped-check reporting.
7. Add or update `code_review.md` only when the repo wants root-level review guidance.
8. Update `docs/codex/best-practices-audit.md` with evidence and gaps.

## Validation

Run repository-native checks when docs or config validators exist. At minimum, inspect links, required headings, and the audit checklist. Report any command that could not be verified.
