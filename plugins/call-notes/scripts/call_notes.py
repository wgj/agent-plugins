#!/usr/bin/env python3
"""Project-local call recording transcription helper."""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_QUO_NUMBER = "+17203034975"
QUO_API_BASE = "https://api.openphone.com/v1"
OPENAI_API_BASE = "https://api.openai.com/v1"
DEFAULT_TRANSCRIBE_MODEL = "gpt-4o-mini-transcribe"
DEFAULT_SUMMARY_MODEL = "gpt-5-mini"
OPENAI_TRANSCRIPTION_LIMIT_BYTES = 25_000_000
TRANSCRIPTION_CHUNK_TARGET_BYTES = 20_000_000


class ConfigError(RuntimeError):
    """Raised when local project or secret configuration is incomplete."""


@dataclass
class Person:
    name: str
    company: str
    role: str
    phone: str
    email: str
    notes: str

    @property
    def label(self) -> str:
        parts = [self.name, self.company]
        return " - ".join(part for part in parts if part).strip() or self.phone


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch and transcribe project-relevant call recordings.")

    def add_common_options(target: argparse.ArgumentParser, defaults: bool) -> None:
        suppress = argparse.SUPPRESS
        target.add_argument(
            "--project-root",
            type=Path,
            default=Path.cwd() if defaults else suppress,
            help="Project root containing PEOPLE.md and receiving calls/ output.",
        )
        target.add_argument(
            "--quo-number",
            default=os.environ.get("QUO_PHONE_NUMBER", DEFAULT_QUO_NUMBER) if defaults else suppress,
        )
        target.add_argument(
            "--phone-number-id",
            default=os.environ.get("QUO_PHONE_NUMBER_ID") if defaults else suppress,
        )
        target.add_argument(
            "--created-after",
            default=None if defaults else suppress,
            help="Only search calls created after this ISO 8601 timestamp.",
        )
        target.add_argument(
            "--created-before",
            default=None if defaults else suppress,
            help="Only search calls created before this ISO 8601 timestamp.",
        )
        target.add_argument("--call-id", default=None if defaults else suppress, help="Process one specific provider call ID.")
        target.add_argument(
            "--max-results",
            type=int,
            default=20 if defaults else suppress,
            help="Maximum calls to inspect per PEOPLE.md phone number.",
        )
        target.add_argument(
            "--force",
            action="store_true",
            default=False if defaults else suppress,
            help="Regenerate output even when transcript.md exists.",
        )
        target.add_argument(
            "--dry-run",
            action="store_true",
            default=False if defaults else suppress,
            help="List matching calls without downloading or transcribing.",
        )
        target.add_argument(
            "--no-keep-audio",
            action="store_true",
            default=False if defaults else suppress,
            help="Delete downloaded audio after transcript and summary files are written.",
        )

    add_common_options(parser, defaults=True)

    subparsers = parser.add_subparsers(dest="command", required=True)
    for name, help_text in [
        ("doctor", "Check project files, secrets, and Quo number configuration."),
        ("init-people", "Create a PEOPLE.md template when one does not exist."),
        ("list-numbers", "List Quo phone numbers visible to the configured API key."),
        ("transcribe-latest", "Find matching calls and write transcript/summary files."),
    ]:
        subparser = subparsers.add_parser(name, help=help_text)
        add_common_options(subparser, defaults=False)
    return parser.parse_args()


def project_root(args: argparse.Namespace) -> Path:
    return args.project_root.expanduser().resolve()


def read_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            values[key] = value
    return values


def keychain_secret(service: str) -> str | None:
    if not shutil.which("security"):
        return None
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-a", os.environ.get("USER", ""), "-s", service, "-w"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except subprocess.CalledProcessError:
        return None
    value = result.stdout.strip()
    return value or None


def secret(name: str, service: str, root: Path) -> str:
    value = os.environ.get(name)
    if value:
        return value

    value = keychain_secret(service)
    if value:
        return value

    value = read_env_file(root / ".env").get(name)
    if value:
        ensure_gitignore(root)
        return value

    raise ConfigError(
        f"Missing {name}. Set it in the environment, store it in macOS Keychain service `{service}`, "
        "or add it to a local .env file."
    )


def normalize_phone(value: str) -> str | None:
    value = value.strip()
    if not value:
        return None
    has_plus = value.startswith("+")
    digits = re.sub(r"\D", "", value)
    if not digits:
        return None
    if has_plus:
        return f"+{digits}"
    if len(digits) == 10:
        return f"+1{digits}"
    if len(digits) == 11 and digits.startswith("1"):
        return f"+{digits}"
    return f"+{digits}"


def split_phone_cell(value: str) -> list[str]:
    phones: list[str] = []
    for item in re.split(r"[,;/]|\s+and\s+", value):
        phone = normalize_phone(item)
        if phone:
            phones.append(phone)
    return phones


def parse_people(root: Path) -> list[Person]:
    path = root / "PEOPLE.md"
    if not path.is_file():
        raise ConfigError(f"{path} does not exist. Run `init-people` or create the structured table first.")

    lines = path.read_text(encoding="utf-8").splitlines()
    people: list[Person] = []
    headers: list[str] | None = None
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell.replace(" ", "")) for cell in cells):
            continue
        lowered = [cell.lower() for cell in cells]
        if "phone" in lowered:
            headers = lowered
            continue
        if not headers or len(cells) < len(headers):
            continue
        row = dict(zip(headers, cells))
        for phone in split_phone_cell(row.get("phone", "")):
            people.append(
                Person(
                    name=row.get("name", "").strip(),
                    company=row.get("company", "").strip(),
                    role=row.get("role", "").strip(),
                    phone=phone,
                    email=row.get("email", "").strip(),
                    notes=row.get("notes", "").strip(),
                )
            )

    if people:
        return people

    fallback_phones = sorted({phone for line in lines for phone in split_phone_cell(line)})
    return [Person(name="", company="", role="", phone=phone, email="", notes="") for phone in fallback_phones]


def api_get_json(url: str, api_key: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    if params:
        query = urllib.parse.urlencode(params, doseq=True)
        url = f"{url}?{query}"
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": api_key,
            "Accept": "application/json",
            "User-Agent": "curl/8.7.1",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GET {url} failed with HTTP {exc.code}: {body}") from exc


def openai_json(path: str, api_key: str, payload: dict[str, Any]) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        f"{OPENAI_API_BASE}{path}",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI request failed with HTTP {exc.code}: {body}") from exc


def list_phone_numbers(quo_key: str) -> list[dict[str, Any]]:
    return api_get_json(f"{QUO_API_BASE}/phone-numbers", quo_key).get("data", [])


def resolve_phone_number_id(quo_key: str, visible_number: str, explicit_id: str | None) -> str:
    if explicit_id:
        return explicit_id
    target = normalize_phone(visible_number)
    if not target:
        raise ConfigError(f"Could not normalize Quo phone number: {visible_number}")
    matches = []
    for item in list_phone_numbers(quo_key):
        candidates = [item.get("number", ""), item.get("formattedNumber", "")]
        if any(normalize_phone(candidate) == target for candidate in candidates):
            matches.append(item)
    if len(matches) == 1:
        return str(matches[0]["id"])
    if not matches:
        raise ConfigError(f"Could not find Quo phone number ID for {target}. Run `list-numbers` to inspect choices.")
    ids = ", ".join(str(item.get("id")) for item in matches)
    raise ConfigError(f"Multiple Quo phone numbers matched {target}: {ids}. Pass --phone-number-id PN...")


def list_calls_for_person(
    quo_key: str,
    phone_number_id: str,
    person: Person,
    created_after: str | None,
    created_before: str | None,
    max_results: int,
) -> list[dict[str, Any]]:
    params: dict[str, Any] = {
        "phoneNumberId": phone_number_id,
        "participants": [person.phone],
        "maxResults": max(1, min(max_results, 100)),
    }
    if created_after:
        params["createdAfter"] = created_after
    if created_before:
        params["createdBefore"] = created_before

    calls: list[dict[str, Any]] = []
    while True:
        page = api_get_json(f"{QUO_API_BASE}/calls", quo_key, params)
        calls.extend(page.get("data", []))
        token = page.get("nextPageToken")
        if not token or len(calls) >= max_results:
            break
        params["pageToken"] = token
    return calls[:max_results]


def get_call(quo_key: str, call_id: str) -> dict[str, Any]:
    return api_get_json(f"{QUO_API_BASE}/calls/{urllib.parse.quote(call_id)}", quo_key).get("data", {})


def get_recordings(quo_key: str, call_id: str) -> list[dict[str, Any]]:
    data = api_get_json(f"{QUO_API_BASE}/call-recordings/{urllib.parse.quote(call_id)}", quo_key).get("data", [])
    if isinstance(data, dict):
        return data.get("recordings", [])
    return data


def slugify(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value.lower()).strip("-")
    return value[:64] or "call"


def parse_time(value: str | None) -> datetime:
    if not value:
        return datetime.now(timezone.utc)
    try:
        if value.endswith("Z"):
            value = value[:-1] + "+00:00"
        return datetime.fromisoformat(value)
    except ValueError:
        return datetime.now(timezone.utc)


def output_dir(root: Path, call: dict[str, Any], person: Person) -> Path:
    timestamp = parse_time(call.get("completedAt") or call.get("answeredAt") or call.get("createdAt"))
    label = person.label
    return root / "calls" / f"{timestamp.date().isoformat()}-{slugify(label)}-{str(call.get('id', 'call'))[-8:]}"


def ensure_gitignore(root: Path) -> None:
    path = root / ".gitignore"
    entries = [".env", "calls/**/audio/"]
    if path.is_file():
        lines = path.read_text(encoding="utf-8").splitlines()
        missing = [entry for entry in entries if entry not in lines]
        if not missing:
            return
        text = "\n".join(lines)
        if text and not text.endswith("\n"):
            text += "\n"
        text += "".join(f"{entry}\n" for entry in missing)
    else:
        text = "".join(f"{entry}\n" for entry in entries)
    path.write_text(text, encoding="utf-8")


def content_extension(content_type: str | None, url: str) -> str:
    if content_type:
        content_type = content_type.split(";", 1)[0].strip().lower()
        ext = mimetypes.guess_extension(content_type)
        if ext:
            return ".mp3" if ext == ".mpga" else ext
    path_ext = Path(urllib.parse.urlparse(url).path).suffix
    return path_ext or ".mp3"


def download_recording(url: str, path_stem: Path, quo_key: str) -> Path:
    request = urllib.request.Request(url, headers={"User-Agent": "curl/8.7.1"})
    try:
        response = urllib.request.urlopen(request, timeout=180)
    except urllib.error.HTTPError as exc:
        if exc.code not in {401, 403}:
            raise
        request = urllib.request.Request(url, headers={"Authorization": quo_key, "User-Agent": "curl/8.7.1"})
        response = urllib.request.urlopen(request, timeout=180)

    with response:
        ext = content_extension(response.headers.get("Content-Type"), url)
        path = path_stem.with_suffix(ext)
        path.write_bytes(response.read())
        return path


def multipart_body(fields: dict[str, str], file_field: str, file_path: Path) -> tuple[bytes, str]:
    boundary = f"----codexquo{uuid.uuid4().hex}"
    chunks: list[bytes] = []
    for name, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
                value.encode(),
                b"\r\n",
            ]
        )
    mime_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    chunks.extend(
        [
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="{file_field}"; filename="{file_path.name}"\r\n'.encode(),
            f"Content-Type: {mime_type}\r\n\r\n".encode(),
            file_path.read_bytes(),
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )
    return b"".join(chunks), boundary


def transcribe_audio_chunk(openai_key: str, audio_path: Path, people: list[Person]) -> str:
    model = os.environ.get("OPENAI_TRANSCRIBE_MODEL", DEFAULT_TRANSCRIBE_MODEL)
    prompt_names = ", ".join(person.label for person in people if person.label)[:1200]
    fields = {
        "model": model,
        "response_format": "json",
    }
    if prompt_names and "diarize" not in model:
        fields["prompt"] = f"This is a business call involving project contacts: {prompt_names}."
    if "diarize" in model:
        fields["chunking_strategy"] = "auto"

    body, boundary = multipart_body(fields, "file", audio_path)
    request = urllib.request.Request(
        f"{OPENAI_API_BASE}/audio/transcriptions",
        data=body,
        headers={
            "Authorization": f"Bearer {openai_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body_text = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI transcription failed with HTTP {exc.code}: {body_text}") from exc
    text = data.get("text")
    if isinstance(text, str) and text.strip():
        return text.strip()
    return json.dumps(data, indent=2)


def require_audio_chunker(audio_path: Path) -> None:
    missing = [tool for tool in ("ffmpeg", "ffprobe") if not shutil.which(tool)]
    if missing:
        tools = ", ".join(missing)
        size_mb = audio_path.stat().st_size / 1_000_000
        raise RuntimeError(
            f"{audio_path} is {size_mb:.1f} MB, which is above OpenAI's 25 MB transcription upload limit. "
            f"Install {tools} so the helper can split large recordings before transcription."
        )


def audio_duration_seconds(audio_path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(audio_path),
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        duration = float(result.stdout.strip())
    except ValueError as exc:
        raise RuntimeError(f"Could not determine audio duration for {audio_path}") from exc
    if duration <= 0:
        raise RuntimeError(f"Could not determine a positive audio duration for {audio_path}")
    return duration


def split_audio_for_transcription(audio_path: Path, chunk_dir: Path) -> list[Path]:
    if audio_path.stat().st_size <= OPENAI_TRANSCRIPTION_LIMIT_BYTES:
        return [audio_path]

    require_audio_chunker(audio_path)
    duration = audio_duration_seconds(audio_path)
    chunk_count = max(2, (audio_path.stat().st_size + TRANSCRIPTION_CHUNK_TARGET_BYTES - 1) // TRANSCRIPTION_CHUNK_TARGET_BYTES)
    segment_seconds = max(15.0, duration / chunk_count)

    for _ in range(6):
        for old_chunk in chunk_dir.glob("chunk-*.mp3"):
            old_chunk.unlink()
        pattern = chunk_dir / "chunk-%03d.mp3"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                str(audio_path),
                "-vn",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-b:a",
                "48k",
                "-f",
                "segment",
                "-segment_time",
                f"{segment_seconds:.3f}",
                "-reset_timestamps",
                "1",
                str(pattern),
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        chunks = sorted(chunk_dir.glob("chunk-*.mp3"))
        if chunks and all(chunk.stat().st_size <= OPENAI_TRANSCRIPTION_LIMIT_BYTES for chunk in chunks):
            return chunks
        segment_seconds = max(15.0, segment_seconds / 2)

    largest_mb = max((chunk.stat().st_size for chunk in chunk_dir.glob("chunk-*.mp3")), default=0) / 1_000_000
    raise RuntimeError(
        f"Could not split {audio_path} into chunks below OpenAI's 25 MB transcription upload limit "
        f"(largest chunk: {largest_mb:.1f} MB)."
    )


def transcribe_audio(openai_key: str, audio_path: Path, people: list[Person]) -> str:
    if audio_path.stat().st_size <= OPENAI_TRANSCRIPTION_LIMIT_BYTES:
        return transcribe_audio_chunk(openai_key, audio_path, people)

    with tempfile.TemporaryDirectory(prefix="quo-transcription-chunks-") as tmpdir:
        chunks = split_audio_for_transcription(audio_path, Path(tmpdir))
        transcripts = [transcribe_audio_chunk(openai_key, chunk, people) for chunk in chunks]
    return "\n\n".join(f"[Part {index}]\n{text}" for index, text in enumerate(transcripts, start=1))


def call_metadata_markdown(call: dict[str, Any], person: Person) -> str:
    fields = [
        ("Provider call ID", call.get("id")),
        ("Matched contact", person.label),
        ("Matched phone", person.phone),
        ("Direction", call.get("direction")),
        ("Status", call.get("status")),
        ("Duration seconds", call.get("duration")),
        ("Created", call.get("createdAt")),
        ("Answered", call.get("answeredAt")),
        ("Completed", call.get("completedAt")),
        ("Participants", ", ".join(call.get("participants", [])) if isinstance(call.get("participants"), list) else None),
    ]
    return "\n".join(f"- **{key}:** {value}" for key, value in fields if value not in {None, ""})


def write_transcript(path: Path, call: dict[str, Any], person: Person, segments: list[tuple[Path, str]]) -> str:
    body = [
        f"# Call Transcript - {person.label}",
        "",
        "## Metadata",
        "",
        call_metadata_markdown(call, person),
        "",
        "## Transcript",
        "",
    ]
    for index, (audio_path, transcript) in enumerate(segments, start=1):
        body.extend([f"### Segment {index}", "", f"Audio: `{audio_path.as_posix()}`", "", transcript.strip(), ""])
    path.write_text("\n".join(body).rstrip() + "\n", encoding="utf-8")
    return "\n\n".join(transcript for _, transcript in segments)


def summarize(openai_key: str, call: dict[str, Any], person: Person, transcript: str) -> str:
    model = os.environ.get("OPENAI_SUMMARY_MODEL", DEFAULT_SUMMARY_MODEL)
    instructions = textwrap.dedent(
        f"""
        Create a concise project call note in Markdown.

        Required sections:
        # Call Summary - {person.label}
        ## Summary
        ## Follow-ups
        ## Highlights
        ## Decisions
        ## Open Questions

        Be specific. Use unchecked task boxes for follow-ups. If a section has no clear content, write "None captured."
        """
    ).strip()
    response = openai_json(
        "/responses",
        openai_key,
        {
            "model": model,
            "input": [
                {
                    "role": "system",
                    "content": [{"type": "input_text", "text": instructions}],
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_text",
                            "text": f"Call metadata:\n{json.dumps(call, indent=2)}\n\nTranscript:\n{transcript}",
                        }
                    ],
                },
            ],
        },
    )
    output_text = response.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text.strip()
    parts: list[str] = []
    for item in response.get("output", []):
        for content in item.get("content", []):
            text = content.get("text")
            if isinstance(text, str):
                parts.append(text)
    return "\n\n".join(parts).strip() or json.dumps(response, indent=2)


def matching_person_for_call(call: dict[str, Any], people: list[Person]) -> Person | None:
    participants = {normalize_phone(value) for value in call.get("participants", []) if isinstance(value, str)}
    for person in people:
        if person.phone in participants:
            return person
    return None


def find_matching_calls(args: argparse.Namespace, quo_key: str, phone_number_id: str, people: list[Person]) -> list[tuple[dict[str, Any], Person]]:
    if args.call_id:
        call = get_call(quo_key, args.call_id)
        person = matching_person_for_call(call, people)
        if not person:
            print(f"skip {args.call_id}: no participants match PEOPLE.md")
            return []
        return [(call, person)]

    found: dict[str, tuple[dict[str, Any], Person]] = {}
    for person in people:
        for call in list_calls_for_person(
            quo_key,
            phone_number_id,
            person,
            args.created_after,
            args.created_before,
            args.max_results,
        ):
            call_id = str(call.get("id", ""))
            if call_id:
                found.setdefault(call_id, (call, person))
    return sorted(
        found.values(),
        key=lambda item: item[0].get("completedAt") or item[0].get("createdAt") or "",
        reverse=True,
    )


def should_keep_audio(args: argparse.Namespace) -> bool:
    if args.no_keep_audio:
        return False
    return os.environ.get("QUO_KEEP_AUDIO", "true").lower() not in {"0", "false", "no"}


def process_call(args: argparse.Namespace, root: Path, quo_key: str, openai_key: str, call: dict[str, Any], person: Person) -> Path | None:
    call_dir = output_dir(root, call, person)
    transcript_path = call_dir / "transcript.md"
    summary_path = call_dir / "summary.md"
    if transcript_path.exists() and summary_path.exists() and not args.force:
        print(f"skip existing {call_dir}")
        return None

    recordings = [recording for recording in get_recordings(quo_key, str(call["id"])) if recording.get("url")]
    if not recordings:
        print(f"skip {call.get('id')}: no downloadable recordings")
        return None

    call_dir.mkdir(parents=True, exist_ok=True)
    audio_dir = call_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    keep_audio = should_keep_audio(args)
    ensure_gitignore(root)

    try:
        segments: list[tuple[Path, str]] = []
        for index, recording in enumerate(recordings, start=1):
            audio_path = download_recording(str(recording["url"]), audio_dir / f"segment-{index:02d}", quo_key)
            transcript = transcribe_audio(openai_key, audio_path, [person])
            segments.append((audio_path.relative_to(root), transcript))

        transcript_text = write_transcript(transcript_path, call, person, segments)
        summary_path.write_text(summarize(openai_key, call, person, transcript_text).rstrip() + "\n", encoding="utf-8")
    finally:
        if not keep_audio:
            shutil.rmtree(audio_dir, ignore_errors=True)
    print(f"wrote {call_dir}")
    return call_dir


def command_doctor(args: argparse.Namespace, root: Path) -> int:
    people = parse_people(root)
    print(f"PEOPLE.md: {len(people)} phone number(s)")
    quo_key = secret("QUO_API_KEY", "quo-api-key", root)
    print("Quo API key: found")
    secret("OPENAI_API_KEY", "openai-api-key", root)
    print("OpenAI API key: found")
    phone_number_id = resolve_phone_number_id(quo_key, args.quo_number, args.phone_number_id)
    print(f"Quo phone number ID: {phone_number_id}")
    return 0


def command_init_people(root: Path) -> int:
    path = root / "PEOPLE.md"
    if path.exists():
        print(f"{path} already exists")
        return 0
    path.write_text(
        textwrap.dedent(
            """\
            # PEOPLE

            | Name | Company | Role | Phone | Email | Notes |
            | --- | --- | --- | --- | --- | --- |
            | Jane Smith | Acme Co | Buyer | +1 303 555 0100 | jane@example.com | Main project contact |
            """
        ),
        encoding="utf-8",
    )
    print(f"created {path}")
    return 0


def command_list_numbers(args: argparse.Namespace, root: Path) -> int:
    quo_key = secret("QUO_API_KEY", "quo-api-key", root)
    target = normalize_phone(args.quo_number)
    for item in list_phone_numbers(quo_key):
        number = normalize_phone(str(item.get("number") or item.get("formattedNumber") or ""))
        marker = "*" if target and number == target else " "
        print(f"{marker} {item.get('id')} {item.get('formattedNumber') or item.get('number')} {item.get('name', '')}")
    return 0


def command_transcribe_latest(args: argparse.Namespace, root: Path) -> int:
    people = parse_people(root)
    if not people:
        raise ConfigError("PEOPLE.md does not contain any phone numbers.")
    quo_key = secret("QUO_API_KEY", "quo-api-key", root)
    phone_number_id = resolve_phone_number_id(quo_key, args.quo_number, args.phone_number_id)
    matches = find_matching_calls(args, quo_key, phone_number_id, people)
    if args.dry_run:
        for call, person in matches:
            print(
                f"{call.get('id')} {call.get('completedAt') or call.get('createdAt')} "
                f"{call.get('direction')} {person.label} {person.phone}"
            )
        print(f"{len(matches)} matching call(s)")
        return 0

    openai_key = secret("OPENAI_API_KEY", "openai-api-key", root)
    written = 0
    for call, person in matches:
        if process_call(args, root, quo_key, openai_key, call, person):
            written += 1
            if args.call_id:
                break
    print(f"processed {written} call(s)")
    return 0


def main() -> int:
    args = parse_args()
    root = project_root(args)
    try:
        if args.command == "doctor":
            return command_doctor(args, root)
        if args.command == "init-people":
            return command_init_people(root)
        if args.command == "list-numbers":
            return command_list_numbers(args, root)
        if args.command == "transcribe-latest":
            return command_transcribe_latest(args, root)
    except ConfigError as exc:
        print(f"configuration error: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        return 130
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
