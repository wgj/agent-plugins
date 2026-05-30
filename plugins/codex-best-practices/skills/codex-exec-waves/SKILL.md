---
name: codex-exec-waves
description: "Create or revise ExecPlan wave coordination docs for multi-plan initiatives. Use when a user asks for waves, work waves, phased execution, multi-ExecPlan sequencing, dependency/status tables, or a coordination layer across active ExecPlans."
---

# Codex ExecPlan Waves

Create or revise `docs/exec-plans/WAVES.md` as the coordination layer above several ExecPlans.

Use waves when one initiative needs multiple active plans that should not all start at once. A wave doc says what must happen first, what can run in parallel, what is blocked, what evidence proves a wave is complete, and how future Codex sessions should pick up the work.

## When To Use

Use this skill when:

- one product or engineering effort has several active ExecPlans
- plans have ordering constraints, such as policy before payments or foundation before UI
- a user asks for "waves", "phases", "workstreams", "multi-plan coordination", or "what should happen first"
- subagents or parallel workers could help inside a wave, but cross-wave sequencing matters
- a cold-start Codex session needs one place to find current status and the next unblocked plan

Do not use a wave doc for one small feature with one clear ExecPlan. Keep the overhead proportional.

## Inputs To Gather

Read the destination project before writing:

- `AGENTS.md`
- `docs/README.md`
- `docs/PLANS.md`
- `docs/exec-plans/README.md`
- existing `docs/exec-plans/WAVES.md`, if present
- active and completed ExecPlans under `docs/exec-plans/`
- product specs, architecture notes, policy docs, reviews, and validation docs that explain dependencies

Identify:

- the initiative name
- all active plans that belong to it
- completed prerequisite plans
- hard blockers and soft ordering preferences
- which plans can run in parallel
- which files, systems, or decisions each plan owns
- exit evidence for each wave
- validation commands or manual checks that prove wave completion

## Workflow

1. Preserve local conventions. If `docs/exec-plans/WAVES.md` already exists, revise it instead of replacing it.
2. Group plans by dependency, risk, and feedback loop. Put policy, architecture, data model, and foundation work before user-facing surfaces that rely on them.
3. Keep each wave small enough to understand. A wave can contain one plan when sequencing is important or several plans when work can safely run in parallel.
4. Mark every wave with one of these statuses: `Blocked`, `Ready`, `Active`, or `Complete`.
5. Set `Current wave` to the first non-complete wave that is unblocked or actively being worked.
6. In the status table, use evidence that points to repo artifacts, not chat memory.
7. For each wave, list:
   - plans
   - parallelism guidance
   - exit criteria
   - completion evidence or remaining blocker, if known
8. Add operating rules for subagents, file ownership, validation, and cross-wave blockers.
9. Update `docs/exec-plans/README.md`, `AGENTS.md`, or relevant specs only when they need a pointer to the wave doc.
10. When a wave completes, update the wave doc, the completed ExecPlans, and the next wave status in the same change.

## Recommended Template

Use this shape unless the destination repo has a stronger local convention:

```md
# <Initiative> Waves

Cold-start order: `AGENTS.md` -> `docs/README.md` -> `docs/PLANS.md` -> `docs/exec-plans/README.md` -> this file -> current wave ExecPlan(s).

Last updated: YYYY-MM-DD
Current wave: Wave N, <Name>

## Status

| Wave | Status | Evidence | Next |
| --- | --- | --- | --- |
| 1 <Name> | Active | `<path>` | <next action> |
| 2 <Name> | Blocked | Needs Wave 1 | Wait |

Statuses: `Blocked`, `Ready`, `Active`, `Complete`.

Trust repo evidence over this table if they differ. Update this table in the same change and record the discrepancy in the relevant ExecPlan.

## Completion Rules

Before marking a wave `Complete`:

- Verify its exit criteria.
- Update each wave ExecPlan's `Progress`, `Decision Log`, `Validation and Acceptance`, and `Outcomes & Retrospective`.
- Move finished ExecPlans to `docs/exec-plans/completed/`; leave blocked ones active with an explicit blocker.
- Update `Last updated`, `Current wave`, and the status table.
- Mark the next wave `Active` if continuing immediately, otherwise `Ready`.

## Operating Rules

- Complete earlier waves before relying on later-wave implementation.
- If a wave has multiple ExecPlans, use subagents for disjoint bounded work.
- Main agent stays on the critical path; delegate sidecar research, separate implementation slices, QA, or review.
- Give every worker clear file or area ownership. Workers must not revert unrelated changes.
- Do not implement blocked surfaces before the dependency named in this file is resolved.

## Waves

### Wave 1: <Name>

Plans: `<plan path>`

Parallelism: <sequential or parallel guidance>.

Exit: <observable evidence that this wave is done>.

### Wave 2: <Name>

Plans: `<plan path>`, `<plan path>`

Parallelism: <which plans can run concurrently and what must stay coordinated>.

Exit: <observable evidence that this wave is done>.

## Quick Picker

- No policy or architecture decision record: Wave 1.
- Foundation does not build: Wave 2.
- Core user surfaces are missing: Wave 3.
- Integrations, admin, or production hardening are missing: later waves.
```

## Validation

Before handing back:

- Confirm every referenced plan path exists.
- Confirm the status table and wave sections agree.
- Confirm exactly one wave is `Active`, unless the repo intentionally has no active work.
- Confirm blocked waves name the dependency that blocks them.
- Confirm completed waves point to completion evidence.
- Confirm later plans do not rely on unresolved earlier-wave decisions without naming the blocker.
- Run repo-native docs or test checks if available; otherwise inspect links and headings manually.
