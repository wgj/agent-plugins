---
name: codex-best-practices
description: "Bootstrap or revise repository-local Codex best-practice guidance: AGENTS.md, product specs, ExecPlans, prompting templates, validation and review docs, MCP decision notes, skill candidates, automation candidates, and session/subagent workflow guidance. Use when the user asks to set up Codex for a project, implement Codex best practices, create a product spec, implementation spec, ExecPlan, PLANS.md, SPECS.md, project docs map, cold-start instructions, reusable workflow guidance, or spec-to-plan promotion."
---

# Codex Best Practices

Create durable, repo-native Codex project guidance that a cold-start session can read and act on without chat history.

Read `references/source-guidance.md` when you need the source-derived rules, section contracts, or starter snippets. Use `scripts/scaffold_codex_docs.py` when a project is missing the standard docs scaffolding or when a first-pass skeleton will save time.

This plugin also includes focused destination-project skills. Use them when the user asks for a narrower pass or when the broad setup needs deeper project context:

- `codex-project-guidance`: AGENTS.md, prompting, configuration, validation, and review.
- `codex-planning-docs`: Plan mode guidance, PLANS.md, product specs, and ExecPlans.
- `codex-exec-waves`: sequencing, status, completion evidence, and subagent guidance across multiple ExecPlans.
- `codex-workflow-systems`: MCP, skill candidates, automations, sessions, worktrees, and subagents.
- `codex-keychain-environment`: worktree-safe local secret setup through macOS Keychain and checked-in Codex Environments.

## Inputs To Gather

Before writing, identify:

- target repository root
- whether the user wants a broad Codex setup, a focused audit, docs scaffolding, a product spec, an ExecPlan, multi-ExecPlan waves, or a spec-to-plan promotion
- project-specific conventions already present in `AGENTS.md`, `.codex/config.toml`, `docs/README.md`, `docs/SPECS.md`, `docs/PLANS.md`, `docs/exec-plans/README.md`, review docs, workflow docs, or existing skills
- product objective, audience or workflow, non-goals, and acceptance signals
- likely implementation surfaces, commands, validation checks, external context sources, repeated workflows, and recurring automation candidates

Ask only when the missing answer would change the document shape or create the wrong work item. If the target repo and objective are clear, inspect the repository and proceed.

## Workflow

1. Locate the project root and read existing guidance first. Prefer `AGENTS.md`, `.codex/config.toml` if present, `docs/README.md`, `docs/SPECS.md`, `docs/PLANS.md`, `docs/exec-plans/README.md`, validation/review docs, and any relevant existing spec or active plan.
2. Preserve local conventions. If the project already has stricter section names, validation scripts, lifecycle rules, or team-owned docs, extend those instead of replacing them.
3. Add missing cold-start scaffolding when needed. Keep `AGENTS.md` lean and routing-oriented; put detailed contracts in focused docs under `docs/` or `.agents/skills/`.
4. Make prompt expectations explicit. Capture the task shape Codex should ask for or infer: Goal, Context, Constraints, and Done when.
5. Make planning explicit. For hard or multi-step work, point to `docs/PLANS.md` and active ExecPlans instead of relying on chat-only plans. For initiatives with several dependent ExecPlans, create or revise `docs/exec-plans/WAVES.md`.
6. Make validation and review explicit. Name tests, lint/type checks, manual checks, diff review expectations, and what done means.
7. Decide what belongs in MCP, skills, and automations. Use MCP for live external context, skills for repeatable methods, and automations only after a workflow is stable manually.
8. Add or revise product specs as durable product intent, not task queues. Add or revise ExecPlans as self-contained implementation documents.
9. Cross-link docs. Specs point to plans through `Implemented By`; plans name source specs; `AGENTS.md` points to the detailed docs rather than duplicating them.
10. Confirm coverage against `docs/codex/best-practices-audit.md`. If the repo needs local context for a row, inspect the current project before marking it covered.
11. Validate. Run repository-native checks when they exist. If no validator exists, inspect required headings, repo-relative links, and best-practice coverage manually.
12. Report created or changed files, validation result, and any assumptions that remain unverified.

## Best-Practices Coverage

When the user asks to "implement Codex best practices", cover these areas unless the repository already handles them:

- `AGENTS.md`: lean routing guidance, repo layout, run/test commands, conventions, constraints, done criteria, and links to deeper docs.
- Prompting: a reusable Goal / Context / Constraints / Done when task shape.
- Planning: when to use Plan mode, when to create an ExecPlan, when to coordinate several ExecPlans with waves, and how plans stay current.
- Configuration: where personal defaults, repo defaults, sandboxing, approvals, MCP, profiles, and local environment notes belong. Prefer documenting `.codex/config.toml` choices; do not change user-level config without an explicit request.
- Validation and review: test, lint, typecheck, manual behavior, and diff-review expectations, plus a stable review checklist.
- MCP: decision notes for external, frequently changing, or tool-backed context.
- Skills: local or shared skill candidates for repeated workflows. Keep each skill scoped to one job with clear triggers, inputs, and outputs.
- Automations: stable recurring workflows only; skills define the method and automations define the cadence.
- Sessions and subagents: one thread per coherent task, fork when work branches, compact/resume deliberately, use worktrees for parallel file-changing work, and delegate bounded side tasks when subagents are available.
- Common mistakes: avoid stuffing durable rules into prompts, skipping planning or validation, loosening permissions prematurely, running live threads over the same files, or automating an unreliable workflow.

## Product Spec Contract

For a repo with no existing spec contract, create or follow this default opening skeleton:

```md
# <Spec title>

## Implemented By

No ExecPlan yet.

## Purpose

## Strategy Fit

## Current State Problem

## Decision Summary

## Acceptance Signals
```

Use `Implemented By` to prevent duplicate work. If an active or completed plan exists, replace `No ExecPlan yet.` with repo-relative links such as:

```md
- Active ExecPlan: docs/exec-plans/active/001-<slug>.md
- Completed ExecPlan: docs/exec-plans/completed/001-<slug>.md
```

After the shared opening skeleton, add sections that fit the work, such as `User Journey`, `Data Contract`, `UI Boundaries`, `Policy Rules`, `Out of Scope`, or `Open Questions`.

## ExecPlan Contract

For a repo with no existing plan contract, create or follow this default section set:

- `Purpose / Big Picture`
- `Progress`
- `Surprises & Discoveries`
- `Decision Log`
- `Outcomes & Retrospective`
- `Context and Orientation`
- `Plan of Work`
- `Concrete Steps`
- `Validation and Acceptance`
- `Idempotence and Recovery`
- `Artifacts and Notes`

The plan must be self-contained. Define terms of art, name files and modules precisely, state the first unblocked milestone, include commands and expected evidence, and update living sections whenever work proceeds or decisions change.

## AGENTS.md Guidance

When adding project-local instructions, keep them short. Add a routing section that tells future Codex sessions:

- how to shape the initial task prompt
- where detailed Codex workflow docs live
- where product specs live
- where active and completed ExecPlans live
- what to read before authoring, implementing, reviewing, or automating
- how to keep specs and plans linked
- which validation commands prove work is done
- which external tools need MCPs, which workflows should become skills, and which stable workflows may become automations

Do not turn `AGENTS.md` into the entire contract. Link to focused docs that own the detail.

ExecPlan filenames should use a stable three-digit prefix plus a short slug, such as `001-user-auth-foundation.md`. Treat that prefix as an identifier and sort key; for multi-plan initiatives, `docs/exec-plans/WAVES.md` owns the canonical answer for sequencing and parallel subagent work.

## Reusable Workflows

When a repo repeats a workflow, document it in the right place:

- Frequent long prompt with stable steps: create or update a skill under `.agents/skills/<name>/SKILL.md` or recommend a plugin if the workflow should be shared broadly.
- External context that changes often: document the MCP need in `docs/codex/mcp.md` and avoid copying volatile data into checked-in docs.
- Recurring stable task: document an automation candidate in `docs/codex/automations.md`; do not schedule it until the manual workflow is reliable and the user asks to create the automation.
- Review checklist: put it in `docs/codex/validation-and-review.md` or root `code_review.md` if the repo already uses that convention.

## Helper Script

Use the scaffold script from this skill directory when useful:

```bash
python3 scripts/scaffold_codex_docs.py /path/to/project
python3 scripts/scaffold_codex_docs.py /path/to/project --spec-title "Buyer Intake Review"
python3 scripts/scaffold_codex_docs.py /path/to/project --spec-title "Buyer Intake Review" --plan-title "Implement Buyer Intake Review"
python3 scripts/scaffold_codex_docs.py /path/to/project --with-config-example --with-code-review-file
python3 scripts/scaffold_codex_docs.py /path/to/project --with-waves
```

The script is intentionally conservative:

- it creates missing docs contracts, Codex best-practice guides, and directories
- it can create an optional `docs/exec-plans/WAVES.md` coordination doc for multi-ExecPlan initiatives
- it appends an `AGENTS.md` routing section only when the marker is absent
- it does not overwrite existing scaffold files
- it creates requested spec or plan files only when missing unless `--overwrite` is passed
- it writes config examples only when explicitly requested

Review generated skeletons before treating them as complete. The script creates a strong envelope; the skill still owns the research, product judgment, and repo-specific details.
