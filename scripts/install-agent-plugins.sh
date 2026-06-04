#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_NAME="${AGENT_PLUGINS_MARKETPLACE_NAME:-wgj}"
MARKETPLACE_REF="${AGENT_PLUGINS_MARKETPLACE_REF:-main}"
MARKETPLACE_SOURCE="${AGENT_PLUGINS_MARKETPLACE_SOURCE:-https://github.com/wgj/agent-plugins}"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_PATH="${CODEX_CONFIG:-$CODEX_HOME/config.toml}"
mkdir -p "$(dirname "$CONFIG_PATH")"

extract_root() {
  sed -n -e 's/^Installed marketplace root: //p' -e 's/^Marketplace root: //p' <<<"$1" | tail -n 1
}

add_args=("$MARKETPLACE_SOURCE")
if [ ! -d "$MARKETPLACE_SOURCE" ] && [ -n "$MARKETPLACE_REF" ]; then
  add_args+=("--ref" "$MARKETPLACE_REF")
fi

if ! add_output="$(codex plugin marketplace add "${add_args[@]}" 2>&1)"; then
  if ! grep -q "already added from a different source" <<<"$add_output"; then
    printf '%s\n' "$add_output" >&2
    exit 1
  fi
  printf '%s\nReplacing marketplace `%s` with %s.\n' "$add_output" "$MARKETPLACE_NAME" "$MARKETPLACE_SOURCE"
  codex plugin marketplace remove "$MARKETPLACE_NAME"
  add_output="$(codex plugin marketplace add "${add_args[@]}" 2>&1)"
fi
printf '%s\n' "$add_output"
marketplace_root="$(extract_root "$add_output")"

if [ ! -d "$MARKETPLACE_SOURCE" ]; then
  printf 'Refreshing Git marketplace `%s`.\n' "$MARKETPLACE_NAME"
  upgrade_output="$(codex plugin marketplace upgrade "$MARKETPLACE_NAME" 2>&1)"
  printf '%s\n' "$upgrade_output"
  upgraded_root="$(extract_root "$upgrade_output")"
  [ -z "$upgraded_root" ] || marketplace_root="$upgraded_root"
fi

if [ -z "$marketplace_root" ]; then
  marketplace_root="$MARKETPLACE_SOURCE"
fi
marketplace_json="$marketplace_root/.agents/plugins/marketplace.json"
if [ ! -f "$marketplace_json" ]; then
  marketplace_json="$CODEX_HOME/.tmp/marketplaces/$MARKETPLACE_NAME/.agents/plugins/marketplace.json"
fi
if [ ! -f "$marketplace_json" ]; then
  echo "Could not locate installed marketplace.json" >&2
  exit 1
fi

plugin_ids=()
legacy_plugin_ids=()
cache_root="$CODEX_HOME/plugins/cache/$MARKETPLACE_NAME"
plugin_list="$(mktemp)"
trap 'rm -f "$plugin_list"' EXIT
python3 - "$marketplace_json" >"$plugin_list" <<'PY'
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

marketplace_path = Path(sys.argv[1]).resolve()
marketplace_root = marketplace_path.parents[2]
marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))


def safe_component(value: object, label: str) -> str:
    if not isinstance(value, str) or not value or value in {".", ".."}:
        raise SystemExit(f"{label} must be a safe path component")
    if "/" in value or "\\" in value or "\0" in value:
        raise SystemExit(f"{label} must be a safe path component: {value!r}")
    return value


def reject_symlinks(root: Path, label: str) -> None:
    for current, dirs, files in os.walk(root, followlinks=False):
        for name in [*dirs, *files]:
            path = Path(current) / name
            if path.is_symlink():
                raise SystemExit(f"{label} contains an unsupported symlink: {path}")


for entry in marketplace.get("plugins", []):
    name = safe_component(entry.get("name"), "Plugin name")
    source = entry.get("source")
    if not isinstance(source, dict) or source.get("source") != "local":
        raise SystemExit(f"Plugin {name} must use a local marketplace source")
    source_path = source.get("path")
    if not isinstance(source_path, str):
        raise SystemExit(f"Plugin {name} is missing a source path")

    plugin_dir = (marketplace_root / source_path).resolve()
    try:
        plugin_dir.relative_to(marketplace_root)
    except ValueError as exc:
        raise SystemExit(f"Plugin {name} source escapes marketplace root") from exc

    manifest_path = plugin_dir / ".codex-plugin" / "plugin.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("name") != name:
        raise SystemExit(f"Plugin {name} manifest name does not match marketplace entry")
    version = safe_component(manifest.get("version"), f"Plugin {name} version")
    reject_symlinks(plugin_dir, f"Plugin {name}")
    print(f"{name}\t{version}\t{plugin_dir}")
PY

while IFS=$'\t' read -r plugin_name plugin_version plugin_source; do
  plugin_ids+=("$plugin_name@$MARKETPLACE_NAME")
  if [ "$plugin_name" = "prompt-builder" ]; then
    legacy_plugin_ids+=("goal-prompt-builder@$MARKETPLACE_NAME")
    rm -rf "$cache_root/goal-prompt-builder"
  fi
  cache_parent="$cache_root/$plugin_name"
  cache_target="$cache_parent/$plugin_version"
  rm -rf "$cache_parent"
  mkdir -p "$cache_parent"
  cp -R "$plugin_source" "$cache_target"
  printf 'Installed %s@%s: %s\n' "$plugin_name" "$MARKETPLACE_NAME" "$cache_target"
done <"$plugin_list"

python3 - "$CONFIG_PATH" "${#legacy_plugin_ids[@]}" "${legacy_plugin_ids[@]}" "${plugin_ids[@]}" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

config_path = Path(sys.argv[1]).expanduser()
legacy_count = int(sys.argv[2])
legacy_plugin_ids = sys.argv[3 : 3 + legacy_count]
plugin_ids = sys.argv[3 + legacy_count :]
removable_plugin_ids = [*plugin_ids, *legacy_plugin_ids]
begin = "# BEGIN agent-plugins managed block"
end = "# END agent-plugins managed block"

text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
if text and not text.endswith("\n"):
    text += "\n"
text = re.sub(rf"\n?{re.escape(begin)}\n.*?{re.escape(end)}\n?", "\n", text, flags=re.S)


def key_pattern(plugin_id: str) -> str:
    escaped = re.escape(plugin_id)
    return rf'(?:"{escaped}"|\'{escaped}\')'


def table_header(line: str) -> str:
    return line.split("#", 1)[0].strip()


def is_table(line: str) -> bool:
    header = table_header(line)
    return header.startswith("[") and header.endswith("]")


def is_plugins_table(line: str) -> bool:
    return table_header(line) == "[plugins]"


def is_plugin_table(line: str) -> bool:
    header = table_header(line)
    return any(
        re.fullmatch(rf"\[\s*plugins\s*\.\s*{key_pattern(plugin_id)}\s*\]", header)
        for plugin_id in removable_plugin_ids
    )


def is_plugin_inline(line: str) -> bool:
    return any(re.match(rf"\s*{key_pattern(plugin_id)}\s*=", line) for plugin_id in removable_plugin_ids)


def drop_existing_plugin_entries(document: str) -> str:
    lines = document.splitlines()
    out: list[str] = []
    in_plugins = False
    skip_plugin_table = False

    for line in lines:
        if skip_plugin_table:
            if is_table(line):
                skip_plugin_table = False
            else:
                continue

        if is_plugin_table(line):
            skip_plugin_table = True
            in_plugins = False
            continue

        if is_table(line):
            in_plugins = is_plugins_table(line)

        if in_plugins and is_plugin_inline(line):
            continue

        out.append(line)

    return "\n".join(out).rstrip() + ("\n" if out else "")


def section_bounds(document: str, header_re: re.Pattern[str]) -> tuple[int, int] | None:
    match = header_re.search(document)
    if not match:
        return None
    next_table = re.search(r"(?m)^\s*\[", document[match.end() :])
    end_index = match.end() + next_table.start() if next_table else len(document)
    return match.end(), end_index


def enable_plugins_feature(document: str) -> str:
    features_bounds = section_bounds(document, re.compile(r"(?m)^\s*\[features\]\s*(?:#.*)?$"))
    if features_bounds:
        start, stop = features_bounds
        section = document[start:stop]
        if re.search(r"(?m)^\s*plugins\s*=", section):
            section = re.sub(r"(?m)^(\s*)plugins\s*=.*$", r"\1plugins = true", section, count=1)
        else:
            section = "\nplugins = true" + section
        return document[:start] + section + document[stop:]

    first_table = re.search(r"(?m)^\s*\[", document)
    top_stop = first_table.start() if first_table else len(document)
    top = document[:top_stop]
    rest = document[top_stop:]

    if re.search(r"(?m)^\s*features\.plugins\s*=", top):
        top = re.sub(r"(?m)^(\s*)features\.plugins\s*=.*$", r"\1features.plugins = true", top, count=1)
        return top + rest

    inline = re.search(r"(?m)^(\s*features\s*=\s*\{)([^}\n]*)(\}\s*(?:#.*)?$)", top)
    if inline:
        body = inline.group(2)
        if re.search(r"(?<![\w-])plugins\s*=", body):
            body = re.sub(r"(?<![\w-])plugins\s*=\s*(?:true|false)\b", "plugins = true", body, count=1)
        else:
            body = f" plugins = true, {body.strip()} " if body.strip() else " plugins = true "
        top = top[: inline.start()] + inline.group(1) + body + inline.group(3) + top[inline.end() :]
        return top + rest

    dotted = list(re.finditer(r"(?m)^\s*features\.[^\s=]+\s*=.*$", top))
    if dotted:
        last = dotted[-1]
        top = top[: last.end()] + "\nfeatures.plugins = true" + top[last.end() :]
        return top + rest

    return document.rstrip() + "\n\n[features]\nplugins = true\n"


text = drop_existing_plugin_entries(text)
text = enable_plugins_feature(text)
block = [begin]
for plugin_id in plugin_ids:
    block.extend(["", f'[plugins."{plugin_id}"]', "enabled = true"])
block.append(end)

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(text.rstrip() + "\n\n" + "\n".join(block) + "\n", encoding="utf-8")
print(f"Enabled plugins in {config_path}:")
for plugin_id in plugin_ids:
    print(f"  - {plugin_id}")
PY
