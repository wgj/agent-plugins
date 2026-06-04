---
name: prompt-builder
description: Create short, paste-ready Codex prompts from rough objectives. Use when the user asks for a prompt, handoff, new-session objective, agent task, prompt rewrite, or prompt sanity check.
---

# Prompt Builder

## Principle

Start with the result the user needs. Add only context, sources, audience, output requirements, boundaries, or final checks that materially change the work. Leave the approach to Codex unless the method itself matters.

Read `references/prompt-patterns.md` only when a concrete example would help.

## Workflow

1. Identify the result and how the user will use or review it.
2. Keep only context that changes the work: relevant files, links, IDs, commits, current state, source material, or reproduction steps.
3. Include the audience or output format only when it changes the result.
4. Add the one or two boundaries that prevent real problems. Do not control every step.
5. For important work, ask for a specific final check that can reveal failure.
6. Ask at most three questions, and only when an answer would change the result, boundary, evidence, or artifact. Otherwise, make a reasonable assumption and draft.
7. Write a natural, direct instruction. Use labeled sections only when they make a complex prompt easier to scan.

## Defaults

Apply these silently unless the user says otherwise:

- Treat the current workspace and supplied material as context.
- Do not repeat generic agent hygiene, process narration, or status-update rules.
- Do not prescribe research steps or tool calls; name the sources and evidence the result needs.
- Include a stop boundary only when the task approaches sending, publishing, deleting, purchasing, deploying, or changing information other people rely on.
- Use the shortest prompt that fully communicates the assignment.

## Quality Bar

Prompts should feel like a clear assignment, not a form or instruction manual. Prefer exact nouns, observable results, and ordinary language. Cut labels, rationale, repeated context, examples, optional polish, and generic cautions first.
