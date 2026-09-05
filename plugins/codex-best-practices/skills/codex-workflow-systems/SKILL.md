---
name: codex-workflow-systems
description: "Inspect a destination repository to review or create Codex workflow-system guidance for MCPs, skills, automations, sessions, worktrees, subagents, and common-mistake guardrails. Use when a user asks to identify MCPs, turn repeated work into skills, document automation candidates, or improve long-running Codex session practices."
---

# Codex Workflow Systems

Review or create the destination-project guidance needed for the context-heavy Codex best practices, according to the user's request:

- Use MCPs for external context
- Turn repeatable work into skills
- Use automations for repeated work
- Organize long-running work with session controls
- Avoid common mistakes

## Task Scope

Requests to identify, inspect, review, audit, or recommend workflows are read-only unless the user also requests changes. Inspect existing sources and report candidates, evidence, and gaps. Do not scaffold docs, create skills, update the audit checklist, or schedule automations for a read-only request.

Use the workflow below for requested setup or changes, limited to the requested outputs. A recommendation to use a tool, skill, or automation does not authorize creating or configuring it.

## Create or Update Workflow

1. Inspect the destination project and recent workflow docs. Look for `AGENTS.md`, `.agents/skills/`, `.codex/config.toml`, `.github/`, CI config, scripts, docs, runbooks, deployment notes, issue/PR references, and repeated manual processes.
2. Run the scaffold helper only if the requested setup or changes need missing Codex docs. It creates multiple files; do not use it for a focused edit that does not need those outputs. Resolve this path relative to this skill directory:

```bash
python3 ../codex-best-practices/scripts/scaffold_codex_docs.py /path/to/project
```

3. Update `docs/codex/mcp.md` with external systems that deserve MCP access. Record purpose, sensitivity, authentication owner, and why MCP beats checked-in docs.
4. Update `docs/codex/skills.md` with repeated workflows that should become local skills. Use concrete trigger phrases, inputs, outputs, and validation.
5. Create or revise `.agents/skills/<name>/SKILL.md` only when a workflow is clear enough to encode. Keep each skill scoped to one job.
6. Update `docs/codex/automations.md` only for workflows that are stable manually. Record cadence, environment, output, and confirmation gates.
7. Update `docs/codex/sessions-and-subagents.md` with thread, fork, compact, worktree, and subagent rules that fit the repository.
8. Update `docs/codex/best-practices-audit.md` with evidence and gaps.

## Guardrails

Do not recommend wiring every external tool into MCP. Do not create automations for workflows that still need heavy steering. Do not let repeated guidance bloat `AGENTS.md`; move detail into focused docs or skills.
