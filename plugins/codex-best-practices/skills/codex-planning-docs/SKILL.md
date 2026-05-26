---
name: codex-planning-docs
description: "Create or revise destination-project planning docs for Codex plan-first workflows, including docs/PLANS.md, docs/exec-plans/README.md, active ExecPlans, product specs, and spec-plan cross-links. Use when a user asks to add Plan mode guidance, PLANS.md, ExecPlans, product specs, or promote product intent into an implementation plan."
---

# Codex Planning Docs

Create the destination-project guidance needed for "Plan first for difficult tasks" and longer-running implementation work.

## Workflow

1. Inspect the destination project. Read `AGENTS.md`, existing `docs/PLANS.md`, `docs/SPECS.md`, `docs/exec-plans/README.md`, active plans, product specs, architecture docs, and validation docs.
2. Use the scaffold helper for missing baseline docs. Resolve this path relative to this skill directory:

```bash
python ../codex-best-practices/scripts/scaffold_codex_docs.py /path/to/project
```

3. Preserve stricter local plan contracts. Do not replace a mature `PLANS.md`; extend it.
4. Create or revise `docs/PLANS.md` so plans are self-contained, living, novice-guiding, outcome-focused, and validation-backed.
5. Create or revise `docs/exec-plans/README.md` so active/completed plan locations, lifecycle rules, and PR expectations are obvious.
6. When product intent is durable but not immediate, create or revise `docs/product-specs/` using the local spec contract.
7. When implementation should begin, create or revise an active ExecPlan under `docs/exec-plans/active/` and link it from the source spec's `Implemented By` section.
8. Update `docs/codex/best-practices-audit.md` with plan-first evidence and gaps.

## Validation

A complete planning pass identifies when to use Plan mode versus an ExecPlan, where active work lives, how progress is updated, and how a cold-start agent can prove the work is done.
