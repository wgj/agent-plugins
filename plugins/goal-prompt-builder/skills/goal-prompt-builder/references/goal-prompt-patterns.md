# Goal Prompt Patterns

Use these patterns only when the main skill needs a template or wording example.

## Standard Template

```text
Goal: <single concrete outcome>.

Context to inspect:
- <workspace, files, links, IDs, commits, prior artifacts, or current thread facts>

Instructions:
- Start by verifying <state that may have changed>.
- <main work steps in execution order>
- Preserve <important user/workspace constraints>.
- Avoid <non-goals or risky detours>.

Validation:
- Run/check <tests, screenshots, commands, manual review, or evidence>.
- If validation cannot run, explain why and give the residual risk.

Pause before:
- <submit, publish, send, delete, purchase, destructive changes, or judgment-heavy choices>.

Final response:
- Summarize what changed, verification performed, and any follow-up needed.
```

## Clarifying Questions

Ask only the questions needed to make the prompt safe and executable:

- Target: "Where should the future agent work: this workspace, another repo, the browser, email, or a document?"
- Scope: "Should the goal include implementation, or only analysis and a handoff?"
- Done: "What result should count as finished?"
- Authority: "May the agent take routine actions, or should it stop before external submits/sends/publishes?"
- Limit: "Does the prompt need to fit a specific character limit?"

## Code Implementation Prompt

```text
Goal: Implement <feature/fix> in <repo/app> and verify it works.

Start by reading <repo docs or files>. Inspect the current git state and preserve unrelated changes. Make the smallest coherent changes that fit existing patterns. Add or update focused tests when behavior changes. Do not redesign unrelated surfaces.

Validation: run <known checks>, or discover and run the closest relevant checks. Report any checks that cannot run.

Final response: list changed files, verification, and remaining risks.
```

## Live-System Prompt

```text
Goal: Prepare <listing/email/application/admin update> until it is ready for final user review.

Use the existing signed-in session when available. Fill routine fields from verified source material. Do not submit, publish, send, delete, purchase, or make irreversible changes without explicit user confirmation.

Final response: state what is staged, what still needs user judgment, and where the final confirmation is needed.
```

## Compression Rules

When fitting a hard limit, keep these items first: objective, baseline/source anchors, hard constraints, verification, and confirmation gates.

Cut these first: background rationale, pleasantries, repeated file descriptions, examples, "be careful" language already covered by specific constraints, and optional nice-to-haves.
