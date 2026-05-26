# Source Guidance

This plugin distills guidance from:

- OpenAI Cookbook, "Using PLANS.md for multi-hour problem solving", reviewed 2026-05-25: https://developers.openai.com/cookbook/articles/codex_exec_plans
- OpenAI Codex best practices, reviewed 2026-05-25: https://developers.openai.com/codex/learn/best-practices
- a private reference project's docs pattern, reviewed on 2026-05-25 and generalized here without naming the private repository or exposing its internal paths

## Core Rules

OpenAI's ExecPlan article frames plans as thorough living documents for complex work. A project should teach Codex when to use them through `AGENTS.md`, then keep the actual plan contract in `PLANS.md`.

The Codex best-practices guidance recommends a full operating loop: clear task context, planning for hard work, durable guidance in `AGENTS.md`, consistent configuration, testing and review, MCPs for external context, skills for repeated workflows, automations for stable recurring work, and session/subagent discipline.

A private reference project's docs pattern adds a useful product-to-implementation pipeline:

```text
reference -> strategy -> product-specs -> exec-plans -> PR
```

In that pattern, specs preserve product intent and active ExecPlans preserve current implementation state. The repository, not chat history, is the source of truth.

## Best-Practices Coverage Matrix

| OpenAI guidance | Repo artifact this plugin creates or revises |
| --- | --- |
| Strong first use: Goal, Context, Constraints, Done when | `codex-project-guidance` creates `docs/codex/prompting.md`, plus a short `AGENTS.md` routing note |
| Plan first for difficult tasks | `codex-planning-docs` creates `docs/PLANS.md`, `docs/exec-plans/README.md`, and active ExecPlans |
| Make guidance reusable with `AGENTS.md` | `codex-project-guidance` keeps project-local `AGENTS.md` lean and links to focused docs |
| Configure Codex for consistency | `codex-project-guidance` creates `docs/codex/configuration.md` and optional `.codex/config.example.toml` |
| Improve reliability with testing and review | `codex-project-guidance` creates `docs/codex/validation-and-review.md` and optional `code_review.md` |
| Use MCPs for external context | `codex-workflow-systems` creates or revises `docs/codex/mcp.md` |
| Turn repeatable work into skills | `codex-workflow-systems` creates or revises `docs/codex/skills.md` |
| Use automations for repeated work | `codex-workflow-systems` creates or revises `docs/codex/automations.md` |
| Organize long-running work with session controls | `codex-workflow-systems` creates or revises `docs/codex/sessions-and-subagents.md` |
| Avoid common mistakes | all focused skills update `AGENTS.md`, `docs/codex/best-practices-audit.md`, and guide guardrails |

## Docs Map Pattern

Use `docs/README.md` as the map for cold-start readers. A good read order is:

1. `AGENTS.md`
2. `docs/README.md`
3. `docs/codex/README.md`
4. `docs/SPECS.md` before authoring or revising product specs
5. `docs/PLANS.md` before creating or implementing ExecPlans
6. `docs/exec-plans/README.md`
7. the relevant active plan under `docs/exec-plans/active/`
8. directly relevant supporting docs

Keep root-level docs rare. Let `docs/README.md`, `docs/SPECS.md`, and `docs/PLANS.md` be the root exceptions when a project needs a stable product and planning contract.

## Prompting

Codex tasks should be shaped around four fields:

- Goal: the change or artifact to produce
- Context: files, folders, docs, examples, errors, screenshots, or external systems that matter
- Constraints: architecture, standards, safety, style, and non-goals
- Done when: tests, behavior, reproduction status, review state, or acceptance signals

Do not keep retyping durable rules in prompts. Promote stable rules to `AGENTS.md`, focused docs, or a skill.

## Configuration

Document repository-specific Codex defaults in `docs/codex/configuration.md`, and use `.codex/config.toml` only when the project intentionally owns those defaults.

Keep personal defaults in user-level config, not in the repository. Do not loosen sandboxing or approval policies just to make a scaffold look complete. Record the recommended setup and let the user opt in.

## Validation and Review

Every repo should say what "done" means. Capture:

- tests to run
- lint, formatting, or type checks
- manual behavior checks
- generated-doc or schema drift checks
- diff-review expectations
- what can be skipped and how to report skipped checks

Review guidance belongs in a focused doc, optionally root `code_review.md` when the team already uses that convention.

## MCP, Skills, and Automations

Use MCP when context lives outside the repo, changes frequently, or should be accessed as a tool rather than pasted into prompts.

Create skills when a workflow is repeated enough that a long prompt or repeated correction is becoming wasteful. Start with a small local skill with clear trigger phrases and only add scripts/assets when they improve reliability.

Use automations only after the manual workflow is stable. Skills define the method; automations define cadence and environment.

## Sessions, Worktrees, and Subagents

Use one thread per coherent task. Fork when work truly branches, compact or resume deliberately, and use worktrees when parallel sessions might edit the same files.

Use subagents for bounded exploration, tests, or triage. Keep the main agent on the critical path and give subagents clear ownership and non-overlap.

## Product Specs

Use product specs when the repository needs durable behavior, workflow rules, implementation boundaries, policy contracts, or UI expectations that may feed one or more ExecPlans.

Default required opening sections:

```md
## Implemented By
## Purpose
## Strategy Fit
## Current State Problem
## Decision Summary
## Acceptance Signals
```

`Implemented By` is the anti-duplication section. It should point to active or completed ExecPlans that implement the spec. If no plan exists yet, say exactly:

```text
No ExecPlan yet.
```

Specs are not queues. When work becomes immediate, create or update an active ExecPlan and link the two documents.

## ExecPlans

Use an ExecPlan for complex features, significant refactors, cross-cutting runtime or observability work, repo-structure or process changes that must survive context loss, or any task likely to span multiple milestones.

Default required sections:

```md
## Purpose / Big Picture
## Progress
## Surprises & Discoveries
## Decision Log
## Outcomes & Retrospective
## Context and Orientation
## Plan of Work
## Concrete Steps
## Validation and Acceptance
```

Useful optional sections from the OpenAI article:

```md
## Idempotence and Recovery
## Artifacts and Notes
## Interfaces and Dependencies
```

An ExecPlan must be self-contained, novice-guiding, outcome-focused, and maintained as work proceeds. It should define terms of art, embed needed context, name files and commands precisely, and describe how to observe the finished behavior.

`Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` are living sections. Update them at meaningful stopping points and whenever implementation reality changes.

## Lifecycle

Active plans live under:

```text
docs/exec-plans/active/
```

Completed plans move to:

```text
docs/exec-plans/completed/
```

When a PR implements an active plan, the PR should also advance the plan. If the plan is complete, move it to `completed/` and update related specs or architecture docs in the same pass.

## Validation

Use repository-native validation when present. Some projects may define checks such as:

```bash
python3 scripts/doc_gardening.py
python3 scripts/validate_knowledge_base.py
```

Other projects may use different checks. If no validator exists, manually inspect required headings, repo-relative links, and spec-plan cross-links.
