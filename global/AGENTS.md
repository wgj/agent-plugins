# Global Codex Guidance

## Subagent Use

- When the user explicitly asks for subagents, delegation, parallel agent work, or asks you to have agents investigate/fix/review different parts of a task, use subagents proactively.
- Before delegating, decide the critical path and keep immediate blocking work local. Delegate bounded sidecar tasks that can run in parallel and materially advance the user's goal.
- Prefer `explorer` agents for focused, read-only codebase questions and `worker` agents for bounded implementation or verification work.
- For implementation delegation, give each worker a clear ownership area and disjoint write scope. Tell workers they are not alone in the codebase and must not revert unrelated changes.
- While subagents run, continue useful non-overlapping work locally. When they finish, review their results, integrate what matters, and close agent threads that are no longer needed.
- Use deeper recursive delegation only when the user explicitly wants it and the task justifies the extra token, latency, and local resource cost.
