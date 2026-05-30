---
name: summarize
description: Use the local Summarize CLI from summarize.sh when the user asks Codex to summarize, transcribe, or extract content from a URL, article, blog post, YouTube or video link, podcast, transcript, PDF, or local file; when the user says "use Summarize", "use summarize.sh", or references the summarize CLI; or when structured summary output from web or document content would help.
homepage: https://summarize.sh
---

# Summarize

Use the `summarize` CLI for fast summaries and extraction from URLs, videos, PDFs, transcripts, and local files.

## First Check

Before first use in a session, or after any command failure, check whether the CLI is available:

```bash
command -v summarize
```

If it is missing, tell the user Summarize is not visible in this Codex environment and suggest installing the `steipete/tap/summarize` Homebrew formula or restarting Codex if it was just installed.

## Privacy Boundary

Summarize may send content to the configured model provider and optional extraction services. For private local files, authenticated pages, dashboards, inbox content, financial data, or other sensitive material, ask before sending the content through Summarize unless the user explicitly requested Summarize for that exact source.

Do not use Summarize as a substitute for authenticated connectors or browser sessions. Use the relevant app connector, Browser, or Chrome when the content requires the user's login, cookies, or existing page state.

## Workflow

1. Identify the source: URL, YouTube/video link, podcast, transcript, PDF, or local file path.
2. Choose the smallest useful mode:
   - General summary: `summarize "<source>" --plain --no-color`
   - Specific length: `summarize "<source>" --length short|medium|long|xl|xxl --plain --no-color`
   - Transcript or extracted source text: `summarize "<source>" --extract --plain --no-color`
   - YouTube or video transcript extraction: `summarize "<url>" --youtube auto --video-mode transcript --extract --timestamps --plain --no-color`
   - Structured output for downstream analysis: add `--json`
   - Token bound: add `--max-output-tokens <count>`
3. For multiple sources, process them one at a time and label the result for each source.
4. If extraction fails or returns thin content, retry only when a relevant fallback is available, such as `--firecrawl auto` for pages or `--youtube auto` for video links.
5. Report the useful result, the source handled, and any extraction limits or failures. Keep command details out of the response unless the user asked for them.

`--extract` is for URLs and supported local media or PDF files. It is not supported for piped stdin input, and local text files should be summarized directly instead of extracted.

## Keys And Config

Summarize uses the user's configured provider and model. Common environment variables:

- OpenAI: `OPENAI_API_KEY`
- Anthropic: `ANTHROPIC_API_KEY`
- xAI: `XAI_API_KEY`
- Google: `GEMINI_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`, or `GOOGLE_API_KEY`

Optional extraction services:

- `FIRECRAWL_API_KEY` for blocked or difficult web pages
- `APIFY_API_TOKEN` for YouTube fallback

Optional config file:

```text
~/.summarize/config.json
```

Do not print or expose API keys.

## Output Guidance

For user-facing summaries, prefer concise bullets with the main thesis, key details, and any caveats. For transcripts or extracted text, return a summary first when the output is very large, then ask what section or time range the user wants expanded.

Use `--plain --no-color` for normal Codex command capture so ANSI styling does not leak into the response. Use `--json` when you need reliable parsing; note that streaming is disabled in JSON mode.
