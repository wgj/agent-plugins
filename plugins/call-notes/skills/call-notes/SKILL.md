---
name: call-notes
description: Inspect project call notes or generate transcripts and summaries from business-phone recordings. Match participants against the project-root PEOPLE.md. Requested generation saves transcript and summary Markdown under calls/, with audio retained locally but ignored by Git.
---

# Call Notes

Use this skill when the user asks to transcribe, fetch, summarize, or inspect phone calls for the current project.

## Task Scope

- For inspection, review, or status requests, read existing files under `calls/`. If provider discovery is needed, use `transcribe-latest --dry-run`; it lists matching calls without downloading, transcribing, or writing output.
- Run the processing command and write project outputs only for requested transcription or call-note generation. For a summary of an existing transcript, answer from that file; save a new summary only when requested.
- Use `--force` only when the user requests regeneration of both existing transcript and summary files.

## Project Contract

For provider discovery or generation, the project root must contain `PEOPLE.md` with a structured table. Reading existing notes does not require provider setup.

```md
# PEOPLE

| Name | Company | Role | Phone | Email | Notes |
| --- | --- | --- | --- | --- | --- |
| Jane Smith | Acme Co | Buyer | +1 303 555 0100 | jane@example.com | Main diligence contact |
```

Only calls involving phone numbers listed in `PEOPLE.md` should be processed for the project. Keep matching project-local; do not try to route calls across other Codex projects.

## Secret Lookup

The helper script reads secrets in this order:

1. Environment variable, such as `OPENAI_API_KEY` or `QUO_API_KEY`
2. macOS Keychain service `openai-api-key` for OpenAI or `quo-api-key` for Quo
3. Project `.env` file

Do not use a Codex-specific OpenAI keychain fallback.

## Commands

Run commands from any project root or pass `--project-root`.

```bash
python3 /path/to/agent-plugins/plugins/call-notes/scripts/call_notes.py doctor
python3 /path/to/agent-plugins/plugins/call-notes/scripts/call_notes.py init-people
python3 /path/to/agent-plugins/plugins/call-notes/scripts/call_notes.py list-numbers
python3 /path/to/agent-plugins/plugins/call-notes/scripts/call_notes.py transcribe-latest
```

Useful options:

- `--quo-number +17203034975` selects the visible Quo business number and resolves the internal Quo `PN...` phone number ID.
- `--phone-number-id PN...` skips discovery when the internal ID is already known.
- `--created-after 2026-05-30T00:00:00Z` limits call search.
- `--call-id CA...` processes a specific provider call ID.
- `--dry-run` lists matching calls without downloading or transcribing.
- `--force` regenerates both existing transcript and summary files; use it only when that regeneration is requested.

## Expected Output

For each call processed as part of requested generation, write:

```text
calls/YYYY-MM-DD-person-or-company-callid/
  transcript.md
  summary.md
  audio/
    segment-01.mp3
```

Keep `transcript.md` and `summary.md` commit-friendly. The helper adds or preserves project `.gitignore` entries for `.env` and `calls/**/audio/` so local secrets and retained audio stay local.

## Defaults

- Quo API base: `https://api.quo.com/v1`.
- Visible Quo number: `+17203034975`, unless overridden by `QUO_PHONE_NUMBER` or `--quo-number`.
- Transcription model: `gpt-4o-transcribe`, override with `OPENAI_TRANSCRIBE_MODEL`.
- Summary model: `gpt-5.5`, override with `OPENAI_SUMMARY_MODEL`.
- Audio retention: keep audio by default, override with `--no-keep-audio` or `QUO_KEEP_AUDIO=false`.

## Notes

Quo's list-calls API requires both the Quo phone number ID and one external participant phone number. This is desirable for project privacy: the script can only discover calls for numbers present in the current project's `PEOPLE.md`.
