#!/usr/bin/env python3
"""Bootstrap Codex best-practice docs, product specs, and ExecPlans."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


AGENTS_MARKER = "<!-- codex-best-practices:docs -->"
MAKE_ASSIGNMENT_OPERATOR_PATTERN = r"(?:\:\:\:\=|\:\:\=|\:\=|\+=|\?=|!=|=)"
MAKE_TARGET_RE = re.compile(r"^([A-Za-z0-9_.-]+)\s*:")
MAKE_VARIABLE_ASSIGNMENT_RE = re.compile(rf"^[A-Za-z0-9_.-]+\s*{MAKE_ASSIGNMENT_OPERATOR_PATTERN}")
MAKE_TARGET_VARIABLE_ASSIGNMENT_RE = re.compile(
    r"^[A-Za-z0-9_.-]+\s*:{1,2}\s*(?:private\s+|export\s+|unexport\s+|override\s+)*"
    rf"[A-Za-z0-9_.-]+\s*{MAKE_ASSIGNMENT_OPERATOR_PATTERN}"
)
MAKE_TARGET_COMMAND_MAP = {
    "build": ("build",),
    "test": ("test",),
    "lint": ("lint",),
    "typecheck": ("typecheck", "type-check", "check-types"),
    "format": ("format", "format-check", "check-format", "format-ci"),
}


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "untitled"


def utc_date() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def repo_path(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def assert_safe_output_path(path: Path, root: Path) -> None:
    root = root.resolve()
    path = path if path.is_absolute() else root / path
    if not is_relative_to(path, root):
        raise ValueError(f"refusing to write outside project root: {path}")

    relative = path.relative_to(root)
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"refusing to write through symlink: {current}")

    if path != root:
        parent = path.parent.resolve()
        if not is_relative_to(parent, root):
            raise ValueError(f"refusing to write under path outside project root: {path.parent}")
    if path.exists():
        resolved = path.resolve()
        if not is_relative_to(resolved, root):
            raise ValueError(f"refusing to write outside project root: {path}")


def ensure_directory(path: Path, root: Path) -> None:
    assert_safe_output_path(path, root)
    path.mkdir(parents=True, exist_ok=True)


def package_runner(root: Path) -> str:
    if (root / "bun.lockb").exists() or (root / "bun.lock").exists():
        return "bun run"
    if (root / "pnpm-lock.yaml").exists():
        return "pnpm"
    if (root / "yarn.lock").exists():
        return "yarn"
    return "npm run"


def make_targets(root: Path) -> set[str]:
    makefile = root / "Makefile"
    if not makefile.exists():
        return set()
    targets: set[str] = set()
    for line in makefile.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith(("\t", " ", ".", "#")):
            continue
        if MAKE_VARIABLE_ASSIGNMENT_RE.match(line):
            continue
        if MAKE_TARGET_VARIABLE_ASSIGNMENT_RE.match(line):
            continue
        match = MAKE_TARGET_RE.match(line)
        if match:
            targets.add(match.group(1))
    return targets


def write_if_missing(path: Path, root: Path, content: str, created: list[str], skipped: list[str]) -> None:
    assert_safe_output_path(path, root)
    if path.exists():
        skipped.append(str(path))
        return
    ensure_directory(path.parent, root)
    path.write_text(content, encoding="utf-8")
    created.append(str(path))


def write_requested(path: Path, root: Path, content: str, overwrite: bool, created: list[str], skipped: list[str]) -> None:
    assert_safe_output_path(path, root)
    if path.exists() and not overwrite:
        skipped.append(str(path))
        return
    ensure_directory(path.parent, root)
    path.write_text(content, encoding="utf-8")
    created.append(str(path))


def detect_commands(root: Path) -> dict[str, list[str]]:
    commands: dict[str, list[str]] = {
        "build": [],
        "test": [],
        "lint": [],
        "typecheck": [],
        "format": [],
    }

    package_json = root / "package.json"
    if package_json.exists():
        try:
            package = json.loads(package_json.read_text(encoding="utf-8"))
            scripts = package.get("scripts", {})
            runner = package_runner(root)
            if isinstance(scripts, dict):
                script_map = {
                    "build": ("build",),
                    "test": ("test",),
                    "lint": ("lint",),
                    "typecheck": ("typecheck", "type-check", "check-types"),
                    "format": ("format:check", "check:format", "format:ci"),
                }
                for bucket, keys in script_map.items():
                    for key in keys:
                        if key in scripts:
                            commands[bucket].append(f"{runner} {key}")
                            break
        except json.JSONDecodeError:
            pass

    if (root / "pyproject.toml").exists() or (root / "pytest.ini").exists():
        commands["test"].append("pytest")

    targets = make_targets(root)
    for bucket, target_names in MAKE_TARGET_COMMAND_MAP.items():
        for target_name in target_names:
            if target_name in targets:
                commands[bucket].append(f"make {target_name}")
                break

    if (root / "go.mod").exists():
        commands["test"].append("go test ./...")

    if (root / "Cargo.toml").exists():
        commands["test"].append("cargo test")
        commands["lint"].append("cargo clippy")
        commands["format"].append("cargo fmt --check")

    return commands


def command_lines(commands: dict[str, list[str]]) -> str:
    rows: list[str] = []
    for label in ["build", "test", "lint", "typecheck", "format"]:
        values = commands.get(label, [])
        value = ", ".join(f"`{cmd}`" for cmd in values) if values else "Not detected yet."
        rows.append(f"- {label}: {value}")
    return "\n".join(rows)


def append_agents_guidance(root: Path, project_name: str, created: list[str], skipped: list[str]) -> None:
    path = root / "AGENTS.md"
    assert_safe_output_path(path, root)
    section = f"""

{AGENTS_MARKER}
## Codex Project Guidance

This repository keeps Codex operating guidance in checked-in docs so a cold-start session can resume without chat history.

- Shape substantial tasks as Goal, Context, Constraints, and Done when. See `docs/codex/prompting.md`.
- Start cold by reading `AGENTS.md`, `docs/README.md`, and `docs/codex/README.md`.
- Read `docs/SPECS.md` before authoring or revising files under `docs/product-specs/`.
- Read `docs/PLANS.md` and `docs/exec-plans/README.md` before creating, revising, or implementing an ExecPlan.
- Keep active ExecPlans under `docs/exec-plans/active/` and completed plans under `docs/exec-plans/completed/`.
- Keep specs and plans cross-linked: specs use `Implemented By`; plans name the source spec they implement.
- Follow `docs/codex/validation-and-review.md` before handing back code or docs.
- Use `docs/codex/mcp.md`, `docs/codex/skills.md`, and `docs/codex/automations.md` to decide what belongs in external tools, repeatable skills, or scheduled work.
"""
    if path.exists():
        text = path.read_text(encoding="utf-8")
        if AGENTS_MARKER in text:
            skipped.append(str(path))
            return
        path.write_text(text.rstrip() + section + "\n", encoding="utf-8")
        created.append(str(path))
        return

    content = f"""# {project_name} Agent Guidance

{section.lstrip()}
"""
    write_if_missing(path, root, content, created, skipped)


def docs_readme(project_name: str) -> str:
    return f"""# Docs Map

This directory should be legible to a cold-start Codex session.

The goal is not just to store writing. The goal is to make it obvious what stage a document is in, what it is good for, and when it should be promoted into something more executable.

## Start Here

When starting cold, read in this order:

1. `AGENTS.md`
2. `docs/README.md`
3. `docs/codex/README.md`
4. `docs/SPECS.md` before authoring or revising product specs
5. `docs/PLANS.md` before creating or implementing ExecPlans
6. `docs/exec-plans/README.md`
7. the specific active ExecPlan under `docs/exec-plans/active/`
8. directly relevant supporting docs

## Directory Roles

- `docs/codex/`: Codex prompting, configuration, validation, MCP, skills, automations, and session guidance.
- `docs/product-specs/`: durable product or implementation behavior for {project_name}.
- `docs/exec-plans/`: active and completed implementation plans that can drive real code changes.
- `docs/reference/`: inputs, constraints, source material, and background notes.
- `docs/strategy/`: directional synthesis that is not yet precise enough to implement directly.
- `docs/guides/`: operator and developer guides for existing system behavior.
- `docs/reviews/`: review notes that pressure-test product or repo direction.

## Promotion Path

The intended path is:

`reference -> strategy -> product-specs -> exec-plans -> PR`

If Codex would still need to invent product behavior, the document is not a product spec yet. If Codex could implement safely from the document alone, it belongs in `docs/exec-plans/`.

## Validation

Use the repository-native doc validation command named in `AGENTS.md` or project docs. If no validator exists yet, inspect required headings and repo-relative links manually.
"""


def codex_readme(project_name: str) -> str:
    return f"""# Codex Operating Guide

This directory captures how Codex should work inside {project_name}.

Use these files to keep `AGENTS.md` concise while preserving detailed guidance for cold-start sessions.

## Guide Map

- `prompting.md`: task shape, clarification, and done criteria.
- `best-practices-audit.md`: checklist mapping OpenAI's best practices to this repository's docs.
- `configuration.md`: repo-specific Codex setup and config decisions.
- `validation-and-review.md`: tests, checks, manual verification, and review behavior.
- `mcp.md`: when external systems should be connected through MCP.
- `skills.md`: repeated workflows that should become local or shared skills.
- `automations.md`: stable recurring workflows that may become scheduled Codex jobs.
- `sessions-and-subagents.md`: thread, worktree, compaction, fork, and subagent guidance.

## Operating Rule

Prefer moving stable, repeated instructions from chat into checked-in guidance. Keep `AGENTS.md` as the router and keep detailed methods in focused docs or skills.
"""


def best_practices_audit_md(project_name: str) -> str:
    return f"""# Codex Best Practices Audit

This checklist maps OpenAI's Codex best-practices guidance to {project_name}.

Source: https://developers.openai.com/codex/learn/best-practices#plan-first-for-difficult-tasks

Use this file as the proof surface when auditing whether the repository has adopted the practices. Mark a row complete only after checking the current project state, not merely because the scaffold created a placeholder.

## Coverage

| Practice | Destination-project evidence | Owning skill |
| --- | --- | --- |
| Strong first use: Context and prompts | `docs/codex/prompting.md`; `AGENTS.md` routes substantial tasks to Goal / Context / Constraints / Done when | `codex-project-guidance` |
| Plan first for difficult tasks | `docs/PLANS.md`; `docs/exec-plans/README.md`; active ExecPlans when work is multi-step | `codex-planning-docs` |
| Make guidance reusable with AGENTS.md | concise `AGENTS.md` plus links to focused docs instead of repeated prompt rules | `codex-project-guidance` |
| Configure Codex for consistency | `docs/codex/configuration.md`; optional `.codex/config.example.toml`; documented sandbox, approval, model, profile, and MCP decisions | `codex-project-guidance` |
| Improve reliability with testing and review | `docs/codex/validation-and-review.md`; detected commands; optional `code_review.md`; done criteria | `codex-project-guidance` |
| Use MCPs for external context | `docs/codex/mcp.md` records external systems, sensitivity, owner, and why MCP is better than docs | `codex-workflow-systems` |
| Turn repeatable work into skills | `docs/codex/skills.md`; `.agents/skills/` candidates for repeated workflows | `codex-workflow-systems` |
| Use automations for repeated work | `docs/codex/automations.md`; stable recurring workflow candidates with confirmation gates | `codex-workflow-systems` |
| Organize long-running work with session controls | `docs/codex/sessions-and-subagents.md`; thread, fork, compact, worktree, and subagent guidance | `codex-workflow-systems` |
| Avoid common mistakes | guardrails in `AGENTS.md` and focused docs for prompt overload, missing tests, skipped planning, loose permissions, overlapping live threads, premature automation, and one-thread-per-project sprawl | all focused skills |

## Audit Notes

- Checked by:
- Date:
- Gaps found:
- Follow-up docs or skills needed:
"""


def prompting_md(project_name: str) -> str:
    return f"""# Codex Prompting

Use this guide when shaping substantial Codex tasks in {project_name}.

## Task Shape

Give Codex, or ask Codex to infer and confirm, four things:

- Goal: what should change or exist after the task.
- Context: files, folders, docs, examples, errors, screenshots, or external systems that matter.
- Constraints: architecture, safety, style, permissions, non-goals, and user preferences.
- Done when: tests, behavior, review state, or acceptance signals that prove the task is complete.

## Clarification

Ask targeted questions only when the missing answer would materially change the outcome or risk doing the wrong work. Otherwise proceed with explicit assumptions and verify cheaply.

## Promotion

If the same prompt pattern is repeated, move the durable parts into `AGENTS.md`, a focused doc, or a skill. Do not keep copying long-standing project rules into every prompt.
"""


def configuration_md(project_name: str) -> str:
    return f"""# Codex Configuration

Use this guide to keep Codex behavior consistent in {project_name}.

## Configuration Layers

- Personal defaults belong in the user's Codex config, not in this repository.
- Repo-specific defaults may belong in `.codex/config.toml` when the project intentionally owns them.
- One-off CLI or app overrides should stay out of checked-in docs unless they become repeatable.

## Decisions To Record

- model or reasoning defaults when the repo has a clear preference
- sandbox and approval expectations
- MCP servers that unlock real workflows
- profiles or local environment setup needed to run the project
- commands Codex should prefer for build, test, lint, typecheck, and docs validation

## Safety

Keep approval and sandboxing tight by default. Loosen permissions only for trusted repositories or specific workflows once the need is clear.

Do not store secrets in checked-in config. If a setup requires credentials, document where the user authorizes the connector or MCP server without recording private values.
"""


def validation_review_md(project_name: str, commands: dict[str, list[str]]) -> str:
    return f"""# Codex Validation and Review

Use this guide before handing back code or docs changes in {project_name}.

## Candidate Commands

These were detected when this guide was created. Confirm they are still correct before relying on them.

{command_lines(commands)}

## Validation Loop

- Add or update tests when the change introduces behavior that can regress.
- Run the focused checks that prove the changed behavior.
- Run broader checks when touching shared behavior, public APIs, repo structure, or build configuration.
- For docs-only changes, inspect required headings, links, and repo-specific validators.
- If a check cannot be run, say why and describe the residual risk.

## Review Loop

Before finishing:

- inspect the diff for unintended files, secrets, generated noise, or unrelated changes
- check for behavioral regressions and missing edge cases
- verify the final state matches the user's request
- update related specs, ExecPlans, architecture docs, and guidance if implementation reality changed

## Done Means

Work is not done just because files changed. It is done when the requested behavior is observable, the relevant checks pass or are explicitly reported as skipped, and the repo guidance remains accurate.
"""


def mcp_md(project_name: str) -> str:
    return f"""# MCP Decisions

Use MCPs in {project_name} when Codex needs context that lives outside the repository.

## Good MCP Candidates

- live issue trackers, pull requests, CI, logs, observability, or deployment state
- CRM, email, support, finance, admin, or data systems that change frequently
- tools Codex should operate directly instead of relying on pasted screenshots or copied text
- repeatable integrations that more than one user or project should share

## Not Good Candidates

- static facts that belong in checked-in docs
- one-off information that can be pasted safely once
- tools that do not remove a real manual loop
- broad access added before the workflow is understood

## Decision Log

Record proposed MCPs here before setup:

- System:
  Purpose:
  Data sensitivity:
  Authentication owner:
  Why MCP instead of checked-in docs:
  Status:
"""


def skills_md(project_name: str) -> str:
    return f"""# Skill Candidates

Use skills when a workflow in {project_name} becomes repeatable enough that prompts are getting long or corrections are recurring.

## Skill Shape

Each skill should have:

- one clear job
- trigger phrases a user would actually say
- required inputs and outputs
- the files or systems it should inspect first
- validation and final response expectations
- scripts or assets only when they improve reliability

## Candidate Backlog

Use this section to collect repeated workflows before creating `.agents/skills/<name>/SKILL.md` or packaging a shared plugin.

- Workflow:
  Trigger phrases:
  Inputs:
  Output:
  Validation:
  Status:

## Graduation

Start local and small. When a skill is stable and useful across repositories or users, package it as a plugin.
"""


def automations_md(project_name: str) -> str:
    return f"""# Automation Candidates

Use automations only after a workflow in {project_name} is stable enough to run on a schedule.

Skills define the method. Automations define the schedule, project, prompt, and execution environment.

## Good Candidates

- summarize recent commits
- check CI failures
- draft release notes
- run a repeatable analysis workflow
- summarize recurring project health or maintenance signals

## Guardrails

- Do not automate a workflow that still needs heavy steering.
- Keep final publish, submit, send, delete, purchase, deploy-to-production, or other irreversible actions behind explicit confirmation unless the user separately authorizes them.
- Record what the automation should report when there is nothing to do.

## Candidate Backlog

- Workflow:
  Cadence:
  Skill or method:
  Execution environment:
  Output expected:
  Confirmation gates:
  Status:
"""


def sessions_md(project_name: str) -> str:
    return f"""# Sessions and Subagents

Use this guide for long-running Codex work in {project_name}.

## Threads

Keep one thread per coherent unit of work. Stay in the same thread when the reasoning trail matters. Fork when the work truly branches.

Compact or resume deliberately when context grows large. After compaction, verify the newest user request before acting.

## Worktrees

Use separate worktrees for parallel file-changing work. Avoid running live threads over the same files unless coordination is explicit.

## Subagents

Use subagents for bounded side work: exploration, tests, review, triage, or independent verification. Keep the main agent on the critical path.

When delegating, give each subagent a clear scope, ownership area, expected output, and instruction not to revert unrelated changes.
"""


def specs_md(project_name: str) -> str:
    return f"""# Product Specs

This document describes the requirements for checked-in product or implementation specs in {project_name}. Treat the reader as a complete beginner to this repository: they have only the current working tree and the single spec file they are reading.

## How to use specs and `docs/SPECS.md`

When authoring or revising a file under `docs/product-specs/`, read this document before writing.

Specs are durable product and implementation contracts. They preserve product intent, workflow rules, implementation boundaries, policy contracts, UI expectations, and acceptance signals. They are not the active task queue.

When a spec becomes immediate enough to drive implementation, create or update an ExecPlan under `docs/exec-plans/active/`, then link the two documents.

## Required Sections

Every file under `docs/product-specs/` should contain these `##` sections once and in this order:

- `Implemented By`
- `Purpose`
- `Strategy Fit`
- `Current State Problem`
- `Decision Summary`
- `Acceptance Signals`

## Section Guidance

### `Implemented By`

List active or completed ExecPlans that implement this spec. If no ExecPlan exists yet, say exactly:

`No ExecPlan yet.`

### `Purpose`

Explain what someone gains from the behavior described in the spec.

### `Strategy Fit`

State which user, workflow, or product surface this spec serves, and what adjacent work it intentionally does not cover.

### `Current State Problem`

Explain what is missing, inconsistent, risky, or underdefined in the current repository or product.

### `Decision Summary`

Capture the most important rules that later implementation work should not reinvent.

### `Acceptance Signals`

Describe observable signals that distinguish done from aspirational.

## Writing Guidance

After the shared opening skeleton, add whatever sections the document actually needs. Name repository-relative files, modules, commands, routes, and artifacts precisely. If a spec is historical, partially implemented, or superseded, say so near the top.
"""


def plans_md(project_name: str) -> str:
    return f"""# Codex Execution Plans (ExecPlans)

This document describes the requirements for an execution plan, or ExecPlan, in {project_name}. An ExecPlan is a design document that a coding agent can follow to deliver a working feature or system change.

Treat the reader as a complete beginner to this repository. They have only the current working tree and the single ExecPlan file they are reading. There is no memory of prior chats.

## How to use ExecPlans and `docs/PLANS.md`

When authoring or revising an ExecPlan, follow this document. Start from the skeleton, research the repository, and flesh the plan out until it can stand on its own.

When implementing an ExecPlan, proceed milestone by milestone when the plan is still clear. Keep the plan current at every meaningful stopping point and record decisions in the plan itself.

## When to use an ExecPlan

Use an ExecPlan for complex features, significant refactors, cross-cutting runtime or observability work, repo-structure or process changes that must survive context loss, or any task likely to span multiple milestones.

Do not use an ExecPlan for trivial edits that can be completed safely in one small pass.

## Non-negotiable Requirements

Every ExecPlan must be self-contained, living, novice-guiding, and outcome-focused. It must produce demonstrably working behavior, not merely code changes that seem to satisfy a narrow definition.

Every ExecPlan must define terms of art in plain language or avoid them. It must explain why the work matters from the user's point of view, what someone can do after the change, and how to see it working.

## Required Sections

Every ExecPlan must contain and maintain all of the following sections:

- `Purpose / Big Picture`
- `Progress`
- `Surprises & Discoveries`
- `Decision Log`
- `Outcomes & Retrospective`
- `Context and Orientation`
- `Plan of Work`
- `Concrete Steps`
- `Validation and Acceptance`

Useful optional sections include `Idempotence and Recovery`, `Artifacts and Notes`, and `Interfaces and Dependencies`.

## Writing Guidance

Write for execution order, not overview. A cold-start agent should be able to answer what milestone is next, whether it is blocked, what files to edit, what commands to run, and what evidence proves success.

Validation is mandatory. Say what tests to run, what manual checks matter, what commands prove the change works, and what expected output should look like.

## Lifecycle

Active plans live in `docs/exec-plans/active/`. Completed plans move to `docs/exec-plans/completed/`.

If a PR implements an active ExecPlan, the same PR should update that plan. If the plan is finished, move it to `completed/` in the same PR and update related specs or architecture docs when reality changed.
"""


def exec_plans_readme() -> str:
    return """# ExecPlans

This directory is the repo-native location for Codex ExecPlans.

Start from `AGENTS.md`, then `docs/README.md`, then `docs/PLANS.md`, then this README, then the relevant active ExecPlan under `docs/exec-plans/active/`.

## Active Plans

Active ExecPlans live in `docs/exec-plans/active/`.

Use the relevant active plan as the source of truth for current milestone state, dependencies, next implementation slices, and validation criteria.

## Completed Plans

Completed ExecPlans move to `docs/exec-plans/completed/`.

Keep them readable. Do not delete the history that explains why the code looks the way it does.

## Working Rule

If a PR implements an active ExecPlan, the same PR should update that plan. If the plan is finished, move it to `completed/` in that same PR.
"""


def config_example() -> str:
    return """# Example repo-local Codex config.
# Rename to `.codex/config.toml` only when this project intentionally owns these defaults.

# model = "gpt-5"
# reasoning_effort = "medium"

# Keep sandbox and approval settings conservative until the workflow is trusted.
# sandbox_mode = "workspace-write"
# approval_policy = "on-request"

# Add MCP servers only when they unlock a real workflow.
# [mcp_servers.example]
# command = "example-mcp-server"
"""


def code_review_md(project_name: str) -> str:
    return f"""# Code Review Guidance

Use this checklist when reviewing changes in {project_name}.

- Start with correctness, regressions, data loss, security, and missing tests.
- Ground findings in file and line references.
- Check whether relevant docs, specs, ExecPlans, or generated references need updates.
- Verify tests and manual checks that prove the requested behavior.
- Keep summaries brief and put actionable findings first.
"""


def spec_template(title: str, plan_path: str | None, strategy_fit: str) -> str:
    implemented_by = f"- Active ExecPlan: {plan_path}" if plan_path else "No ExecPlan yet."
    return f"""# {title}

## Implemented By

{implemented_by}

## Purpose

TODO: Explain what someone gains from this behavior and why it matters.

## Strategy Fit

{strategy_fit}

TODO: State the user, workflow, or product surface this spec serves, plus what it intentionally does not cover.

## Current State Problem

TODO: Explain what is missing, inconsistent, risky, or underdefined in the current repository.

## Decision Summary

TODO: Capture the durable product or implementation decisions future work should preserve.

## Acceptance Signals

TODO: Describe observable signals that distinguish done from aspirational.

## Open Questions

- TODO: Replace or remove once the key product decisions are settled.
"""


def plan_template(title: str, source_spec: str | None) -> str:
    date = utc_date()
    spec_line = f"\nThis plan implements `{source_spec}`." if source_spec else ""
    return f"""# {title}

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan must be maintained in accordance with `docs/PLANS.md`.{spec_line}

## Purpose / Big Picture

TODO: Explain what someone gains after this change and how they can see it working.

## Progress

- [ ] {date}: Initial ExecPlan created; fill in researched milestones before implementation.

## Surprises & Discoveries

- Observation: None yet.
  Evidence: Initial plan scaffold.

## Decision Log

- Decision: Create an ExecPlan before implementation.
  Rationale: The work needs durable context and validation steps for cold-start Codex sessions.
  Date/Author: {date} / Codex

## Outcomes & Retrospective

TODO: Add outcomes, gaps, and lessons learned at major milestones or completion.

## Context and Orientation

TODO: Describe the current state as if the reader knows nothing. Name key files and define terms of art.

## Plan of Work

TODO: Describe the sequence of edits and additions. Name files, modules, and milestones in execution order.

## Concrete Steps

TODO: State exact commands to run, where to run them, and what output or behavior to expect.

## Validation and Acceptance

TODO: State automated tests, manual checks, and observable acceptance criteria.

## Idempotence and Recovery

TODO: Explain which steps are safe to repeat and how to recover from partial progress.

## Artifacts and Notes

TODO: Add concise transcripts, diffs, screenshots, or evidence snippets that prove important claims.
"""


def ensure_scaffold(
    root: Path,
    project_name: str,
    created: list[str],
    skipped: list[str],
    with_config_example: bool,
    with_code_review_file: bool,
) -> None:
    for directory in [
        "docs/codex",
        "docs/product-specs",
        "docs/exec-plans/active",
        "docs/exec-plans/completed",
        "docs/reference",
        "docs/strategy",
        "docs/guides",
        "docs/reviews",
    ]:
        ensure_directory(root / directory, root)

    commands = detect_commands(root)

    write_if_missing(root / "docs/README.md", root, docs_readme(project_name), created, skipped)
    write_if_missing(root / "docs/codex/README.md", root, codex_readme(project_name), created, skipped)
    write_if_missing(root / "docs/codex/best-practices-audit.md", root, best_practices_audit_md(project_name), created, skipped)
    write_if_missing(root / "docs/codex/prompting.md", root, prompting_md(project_name), created, skipped)
    write_if_missing(root / "docs/codex/configuration.md", root, configuration_md(project_name), created, skipped)
    write_if_missing(root / "docs/codex/validation-and-review.md", root, validation_review_md(project_name, commands), created, skipped)
    write_if_missing(root / "docs/codex/mcp.md", root, mcp_md(project_name), created, skipped)
    write_if_missing(root / "docs/codex/skills.md", root, skills_md(project_name), created, skipped)
    write_if_missing(root / "docs/codex/automations.md", root, automations_md(project_name), created, skipped)
    write_if_missing(root / "docs/codex/sessions-and-subagents.md", root, sessions_md(project_name), created, skipped)
    write_if_missing(root / "docs/SPECS.md", root, specs_md(project_name), created, skipped)
    write_if_missing(root / "docs/PLANS.md", root, plans_md(project_name), created, skipped)
    write_if_missing(root / "docs/exec-plans/README.md", root, exec_plans_readme(), created, skipped)
    append_agents_guidance(root, project_name, created, skipped)

    if with_config_example:
        write_if_missing(root / ".codex/config.example.toml", root, config_example(), created, skipped)

    if with_code_review_file:
        write_if_missing(root / "code_review.md", root, code_review_md(project_name), created, skipped)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".", help="Repository root to update")
    parser.add_argument("--project-name", help="Human-readable project name; defaults to directory name")
    parser.add_argument("--spec-title", help="Create a product spec skeleton with this title")
    parser.add_argument("--plan-title", help="Create an active ExecPlan skeleton with this title")
    parser.add_argument("--strategy-fit", default="TODO: State the strategy fit.", help="Initial text for the spec Strategy Fit section")
    parser.add_argument("--with-config-example", action="store_true", help="Create .codex/config.example.toml")
    parser.add_argument("--with-code-review-file", action="store_true", help="Create a root code_review.md checklist")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite requested spec or plan files if they already exist")
    args = parser.parse_args()

    root = Path(args.project_root).expanduser().resolve()
    project_name = args.project_name or root.name
    created: list[str] = []
    skipped: list[str] = []

    ensure_scaffold(
        root,
        project_name,
        created,
        skipped,
        args.with_config_example,
        args.with_code_review_file,
    )

    plan_repo_path: str | None = None
    plan_path: Path | None = None
    if args.plan_title:
        plan_path = root / "docs/exec-plans/active" / f"{slugify(args.plan_title)}.md"
        plan_repo_path = repo_path(plan_path, root)

    spec_repo_path: str | None = None
    if args.spec_title:
        spec_path = root / "docs/product-specs" / f"{slugify(args.spec_title)}.md"
        spec_repo_path = repo_path(spec_path, root)
        write_requested(
            spec_path,
            root,
            spec_template(args.spec_title, plan_repo_path, args.strategy_fit),
            args.overwrite,
            created,
            skipped,
        )

    if args.plan_title and plan_path:
        write_requested(
            plan_path,
            root,
            plan_template(args.plan_title, spec_repo_path),
            args.overwrite,
            created,
            skipped,
        )

    print("Codex docs scaffold complete.")
    if created:
        print("Created or updated:")
        for item in created:
            print(f"- {item}")
    if skipped:
        print("Preserved existing:")
        for item in skipped:
            print(f"- {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
