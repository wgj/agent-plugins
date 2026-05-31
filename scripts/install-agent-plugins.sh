#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_NAME="${AGENT_PLUGINS_MARKETPLACE_NAME:-wgj}"
MARKETPLACE_REF="${AGENT_PLUGINS_MARKETPLACE_REF:-main}"
DEFAULT_REMOTE_SOURCE="https://github.com/wgj/agent-plugins"

if [ -n "${AGENT_PLUGINS_MARKETPLACE_SOURCE:-}" ]; then
  marketplace_source="$AGENT_PLUGINS_MARKETPLACE_SOURCE"
else
  marketplace_source="$DEFAULT_REMOTE_SOURCE"
fi

config_home="${CODEX_HOME:-$HOME/.codex}"
config_path="${CODEX_CONFIG:-$config_home/config.toml}"
mkdir -p "$(dirname "$config_path")"

add_args=("$marketplace_source")
if [ ! -d "$marketplace_source" ] && [ -n "$MARKETPLACE_REF" ]; then
  add_args+=("--ref" "$MARKETPLACE_REF")
fi

installed_marketplace_root=""
extract_installed_root() {
  sed -n \
    -e 's/^Installed marketplace root: //p' \
    -e 's/^Marketplace root: //p' \
    <<<"$1" | tail -n 1
}

add_output=""
if ! add_output="$(codex plugin marketplace add "${add_args[@]}" 2>&1)"; then
  if grep -q "already added from a different source" <<<"$add_output"; then
    printf '%s\n' "$add_output"
    printf 'Replacing marketplace `%s` with %s.\n' "$MARKETPLACE_NAME" "$marketplace_source"
    codex plugin marketplace remove "$MARKETPLACE_NAME"
    add_output="$(codex plugin marketplace add "${add_args[@]}" 2>&1)"
    printf '%s\n' "$add_output"
    installed_marketplace_root="$(extract_installed_root "$add_output")"
  else
    printf '%s\n' "$add_output" >&2
    exit 1
  fi
else
  printf '%s\n' "$add_output"
  installed_marketplace_root="$(extract_installed_root "$add_output")"
fi

marketplace_json_path=""
if [ -n "$installed_marketplace_root" ] && [ -f "$installed_marketplace_root/.agents/plugins/marketplace.json" ]; then
  marketplace_json_path="$installed_marketplace_root/.agents/plugins/marketplace.json"
elif [ -d "$marketplace_source" ] && [ -f "$marketplace_source/.agents/plugins/marketplace.json" ]; then
  marketplace_json_path="$marketplace_source/.agents/plugins/marketplace.json"
fi

CODEX_CONFIG_PATH="$config_path" \
AGENT_PLUGINS_MARKETPLACE_NAME="$MARKETPLACE_NAME" \
AGENT_PLUGINS_MARKETPLACE_JSON_PATH="$marketplace_json_path" \
python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
from pathlib import Path


config_path = Path(os.environ["CODEX_CONFIG_PATH"]).expanduser()
marketplace_name = os.environ["AGENT_PLUGINS_MARKETPLACE_NAME"]
marketplace_path = os.environ.get("AGENT_PLUGINS_MARKETPLACE_JSON_PATH", "")


def load_marketplace() -> dict[str, object]:
    if marketplace_path:
        with Path(marketplace_path).open(encoding="utf-8") as handle:
            return json.load(handle)

    raise SystemExit("Could not locate installed marketplace.json")


marketplace = load_marketplace()
plugins = marketplace.get("plugins")
if not isinstance(plugins, list) or not plugins:
    raise SystemExit("Marketplace does not define any plugins to enable")

plugin_ids: list[str] = []
for entry in plugins:
    if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
        raise SystemExit("Marketplace plugin entries must include string names")
    plugin_ids.append(f"{entry['name']}@{marketplace_name}")

text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
if text and not text.endswith("\n"):
    text += "\n"


def section_bounds(document: str, header_pattern: re.Pattern[str]) -> tuple[int, int] | None:
    match = header_pattern.search(document)
    if not match:
        return None

    next_table = re.search(r"(?m)^\s*\[", document[match.end() :])
    section_end = match.end() + next_table.start() if next_table else len(document)
    return match.end(), section_end


def enable_inline_plugin_entry(document: str, plugin_id: str) -> tuple[str, bool]:
    plugins_header = re.compile(r"(?m)^\s*\[plugins\]\s*(?:#.*)?$")
    bounds = section_bounds(document, plugins_header)
    if not bounds:
        return document, False

    section_start, section_end = bounds
    section = document[section_start:section_end]
    inline_pattern = re.compile(
        rf'(?m)^(\s*"{re.escape(plugin_id)}"\s*=\s*\{{)([^}}\n]*)(\}}\s*(?:#.*)?$)'
    )
    match = inline_pattern.search(section)
    if not match:
        return document, False

    body = match.group(2)
    enabled_pattern = re.compile(r"(?<![\w-])enabled\s*=\s*(?:true|false)\b")
    if enabled_pattern.search(body):
        body = enabled_pattern.sub("enabled = true", body, count=1)
    elif body.strip():
        body = f" enabled = true, {body.strip()} "
    else:
        body = " enabled = true "

    updated_section = section[: match.start()] + match.group(1) + body + match.group(3) + section[match.end() :]
    return document[:section_start] + updated_section + document[section_end:], True


def ensure_plugin_enabled(document: str, plugin_id: str) -> str:
    header = f'[plugins."{plugin_id}"]'
    header_pattern = re.compile(rf"(?m)^\s*\[plugins\.\"{re.escape(plugin_id)}\"\]\s*(?:#.*)?$")
    bounds = section_bounds(document, header_pattern)

    if not bounds:
        document, replaced_inline = enable_inline_plugin_entry(document, plugin_id)
        if replaced_inline:
            return document
        return document + f"\n{header}\nenabled = true\n"

    section_start, section_end = bounds
    section = document[section_start:section_end]

    enabled_pattern = re.compile(r"(?m)^(\s*)enabled\s*=.*$")
    if enabled_pattern.search(section):
        section = enabled_pattern.sub(r"\1enabled = true", section, count=1)
    else:
        section = "\nenabled = true" + section

    return document[:section_start] + section + document[section_end:]


for plugin_id in plugin_ids:
    text = ensure_plugin_enabled(text, plugin_id)

config_path.write_text(text.lstrip("\n"), encoding="utf-8")

print(f"Enabled plugins in {config_path}:")
for plugin_id in plugin_ids:
    print(f"  - {plugin_id}")
PY
