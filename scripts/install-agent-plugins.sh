#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_NAME="${AGENT_PLUGINS_MARKETPLACE_NAME:-wgj}"
MARKETPLACE_REF="${AGENT_PLUGINS_MARKETPLACE_REF:-main}"
DEFAULT_REMOTE_SOURCE="https://github.com/wgj/agent-plugins"
PLUGIN_NAMES=(
  "goal-prompt-builder"
  "kubernetes"
  "codex-best-practices"
  "call-notes"
  "summarize"
)

repo_root=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$script_dir/.." && pwd)"
fi

if [ -n "${AGENT_PLUGINS_MARKETPLACE_SOURCE:-}" ]; then
  marketplace_source="$AGENT_PLUGINS_MARKETPLACE_SOURCE"
elif [ -n "$repo_root" ] && [ -f "$repo_root/.agents/plugins/marketplace.json" ]; then
  marketplace_source="$repo_root"
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

add_output=""
if ! add_output="$(codex plugin marketplace add "${add_args[@]}" 2>&1)"; then
  if grep -q "already added from a different source" <<<"$add_output"; then
    printf '%s\n' "$add_output"
    printf 'Replacing marketplace `%s` with %s.\n' "$MARKETPLACE_NAME" "$marketplace_source"
    codex plugin marketplace remove "$MARKETPLACE_NAME"
    codex plugin marketplace add "${add_args[@]}"
  else
    printf '%s\n' "$add_output" >&2
    exit 1
  fi
else
  printf '%s\n' "$add_output"
fi

plugin_ids=()
for plugin_name in "${PLUGIN_NAMES[@]}"; do
  plugin_ids+=("${plugin_name}@${MARKETPLACE_NAME}")
done

CODEX_CONFIG_PATH="$config_path" \
AGENT_PLUGINS_IDS="$(IFS=,; printf '%s' "${plugin_ids[*]}")" \
python3 - <<'PY'
from __future__ import annotations

import os
import re
from pathlib import Path


config_path = Path(os.environ["CODEX_CONFIG_PATH"]).expanduser()
plugin_ids = [item for item in os.environ["AGENT_PLUGINS_IDS"].split(",") if item]

text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
if text and not text.endswith("\n"):
    text += "\n"


def ensure_plugin_enabled(document: str, plugin_id: str) -> str:
    header = f'[plugins."{plugin_id}"]'
    header_pattern = re.compile(rf"(?m)^\[plugins\.\"{re.escape(plugin_id)}\"\]\s*$")
    match = header_pattern.search(document)

    if not match:
        return document + f"\n{header}\nenabled = true\n"

    next_table = re.search(r"(?m)^\[", document[match.end() :])
    section_end = match.end() + next_table.start() if next_table else len(document)
    section = document[match.end() : section_end]

    enabled_pattern = re.compile(r"(?m)^enabled\s*=.*$")
    if enabled_pattern.search(section):
        section = enabled_pattern.sub("enabled = true", section, count=1)
    else:
        section = "\nenabled = true" + section

    return document[: match.end()] + section + document[section_end:]


for plugin_id in plugin_ids:
    text = ensure_plugin_enabled(text, plugin_id)

config_path.write_text(text.lstrip("\n"), encoding="utf-8")
PY

printf 'Enabled plugins in %s:\n' "$config_path"
for plugin_id in "${plugin_ids[@]}"; do
  printf '  - %s\n' "$plugin_id"
done
