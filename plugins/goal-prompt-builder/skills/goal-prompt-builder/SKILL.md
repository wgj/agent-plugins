---
name: goal-prompt-builder
description: Create concise, paste-ready Codex Goal Mode prompts from rough or minimal user instructions. Use when the user asks to make, write, prepare, refine, compress, or sanity-check a goal prompt, Goal Mode prompt, handoff prompt, new-session objective, or agent task prompt; when a task needs to be turned into a self-contained goal with context, constraints, verification, and stopping rules; or when Codex should ask targeted questions before drafting a goal prompt.
---

# Goal Prompt Builder

## Overview

Turn a rough request into either a small set of clarifying questions or a self-contained Goal Mode prompt another Codex session can execute without the original conversation.

Read `references/goal-prompt-patterns.md` when you need concrete templates, example wording, or compression patterns.

## Workflow

1. Identify the intended outcome, likely workspace or surface, required deliverable, and what "done" should mean.
2. Use available thread and workspace context before asking questions. Verify cheap, drift-prone details when they matter; otherwise make the prompt tell the future agent to verify current state first.
3. Ask questions only when a missing answer would materially change the prompt. Prefer one to three targeted questions, each tied to the decision it unlocks.
4. Draft a paste-ready goal prompt in imperative form. Include the objective, context to inspect, constraints and non-goals, workflow expectations, verification, stopping rules, and final response expectations.
5. Check whether the result fits the user's requested limit. If no limit is given and the target is Codex Goal Mode, keep the prompt under 4000 characters by default.

## Question Policy

Ask before drafting when the target system, workspace, deliverable, authority boundary, irreversible action, or success criteria is unclear enough to make the prompt unsafe or low-quality.

Do not ask when a reasonable default is obvious. Use these defaults unless contradicted: work in the current workspace, preserve unrelated user changes, inspect project docs before editing, run relevant validation, report anything unverified, and stop before final submit, publish, send, delete, purchase, or other irreversible actions.

When asking questions, offer defaults in plain language so the user can answer quickly. If the user wants speed or says to use judgment, proceed with explicit assumptions inside the prompt.

## Prompt Checklist

Include only information the next agent needs to act:

- Objective: one concrete outcome, not a vibe or broad theme.
- Context: exact files, repos, links, IDs, commits, thread facts, or source materials when known.
- First moves: what to read, inspect, or verify before changing anything.
- Constraints: user preferences, scope boundaries, style, privacy, safety, deadlines, and hard limits.
- Non-goals: tempting work the next agent should avoid.
- Execution: whether to implement, research, draft, reconcile, or ask before proceeding.
- Verification: tests, screenshots, checks, manual review points, or evidence expected.
- Stopping rules: when to pause for user confirmation.
- Final output: what the agent should report back.

## Quality Bar

Make the goal prompt operational, compact, and self-contained. Prefer exact nouns over broad phrasing, file paths over "the relevant files," and dated or verified state over "latest." If a fact may be stale, instruct the next agent to verify it first.

Avoid explanatory prose, motivational framing, hidden assumptions, invented commands, and instructions that conflict with Codex's normal safety or repository hygiene. Keep the prompt focused on the task, not on describing why the task matters.

For code work, include repository-native workflows when known. For browser, email, marketplace, finance, admin, or other live-system work, include a final confirmation gate before any external action.

## Compression

If the prompt is too long, preserve hard constraints, source anchors, acceptance checks, and stopping rules first. Cut rationale, examples, duplicate context, soft adjectives, and optional polish. Use terse bullets and compact section labels.
