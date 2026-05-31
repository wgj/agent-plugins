---
name: call-notes
description: Fetch and transcribe business-phone call recordings for the current Codex project by matching call participants against a structured PEOPLE.md file at the project root, then write calls/<date>-<person>/transcript.md and summary.md with audio retained locally but ignored by Git.
---

# Call Notes

Use this skill when the user asks to transcribe, fetch, summarize, or inspect phone calls for the current project.

## Project Contract

The project root must contain `PEOPLE.md` with a structured table:

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
- `--force` regenerates existing transcript and summary files.

## Expected Output

For each processed call, write:

```text
calls/YYYY-MM-DD-person-or-company-callid/
  transcript.md
  summary.md
  audio/
    segment-01.mp3
```

Keep `transcript.md` and `summary.md` commit-friendly. The helper adds or preserves project `.gitignore` entries for `.env` and `calls/**/audio/` so local secrets and retained audio stay local.

## Defaults

- Visible Quo number: `+17203034975`, unless overridden by `QUO_PHONE_NUMBER` or `--quo-number`.
- Transcription model: `gpt-4o-transcribe`, override with `OPENAI_TRANSCRIBE_MODEL`.
- Summary model: `gpt-5.5`, override with `OPENAI_SUMMARY_MODEL`.
- Audio retention: keep audio by default, override with `--no-keep-audio` or `QUO_KEEP_AUDIO=false`.

## Notes

Quo's list-calls API requires both the Quo phone number ID and one external participant phone number. This is desirable for project privacy: the script can only discover calls for numbers present in the current project's `PEOPLE.md`.
