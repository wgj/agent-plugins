---
name: quo-call-transcript-automation
description: Set up and operate Codex Automations that periodically run Quo call transcription for a project, using PEOPLE.md as the project-local relevance filter and writing calls/<date>-<person>/transcript.md and summary.md outputs.
---

# Quo Call Transcript Automation

Use this skill when the user wants recurring Quo call transcription for a Codex project or wants to prepare a project for scheduled call-note generation.

## Automation Shape

Each Codex project should run its own automation from that project's root. The automation should call:

```bash
python3 /path/to/agent-plugins/plugins/quo-call-transcripts/scripts/quo_calls.py transcribe-latest \
  --project-root /path/to/project \
  --created-after <recent ISO timestamp>
```

Prefer a rolling recent window, such as the last 24-72 hours, because the script is idempotent and skips calls with existing output unless `--force` is passed.

## Before Scheduling

Confirm:

- `PEOPLE.md` exists at the project root and contains phone numbers in the `Phone` column.
- OpenAI auth is available via `OPENAI_API_KEY`, Keychain service `openai-api-key`, or project `.env`.
- Quo auth is available via `QUO_API_KEY`, Keychain service `quo-api-key`, or project `.env`.
- The Quo visible number is configured as `QUO_PHONE_NUMBER=+17203034975`, or the internal `QUO_PHONE_NUMBER_ID=PN...` is known.

## Recommended Project Files

Keep these commit-friendly:

- `PEOPLE.md`
- `calls/**/transcript.md`
- `calls/**/summary.md`

Keep these local-only:

- `calls/**/audio/`
- `.env`

The helper script adds `calls/**/audio/` to `.gitignore` when it writes retained audio.

## On-Demand Use

After a call, run the same script manually from the project root:

```bash
python3 /path/to/agent-plugins/plugins/quo-call-transcripts/scripts/quo_calls.py transcribe-latest
```

For a specific call, use:

```bash
python3 /path/to/agent-plugins/plugins/quo-call-transcripts/scripts/quo_calls.py transcribe-latest --call-id CA...
```
