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

if [ ! -d "$marketplace_source" ]; then
  printf 'Refreshing Git marketplace `%s`.\n' "$MARKETPLACE_NAME"
  upgrade_output="$(codex plugin marketplace upgrade "$MARKETPLACE_NAME" 2>&1)"
  printf '%s\n' "$upgrade_output"
  upgraded_marketplace_root="$(extract_installed_root "$upgrade_output")"
  if [ -n "$upgraded_marketplace_root" ]; then
    installed_marketplace_root="$upgraded_marketplace_root"
  fi
fi

marketplace_json_path=""
if [ -n "$installed_marketplace_root" ] && [ -f "$installed_marketplace_root/.agents/plugins/marketplace.json" ]; then
  marketplace_json_path="$installed_marketplace_root/.agents/plugins/marketplace.json"
elif [ -d "$marketplace_source" ] && [ -f "$marketplace_source/.agents/plugins/marketplace.json" ]; then
  marketplace_json_path="$marketplace_source/.agents/plugins/marketplace.json"
elif [ -f "$config_home/.tmp/marketplaces/$MARKETPLACE_NAME/.agents/plugins/marketplace.json" ]; then
  marketplace_json_path="$config_home/.tmp/marketplaces/$MARKETPLACE_NAME/.agents/plugins/marketplace.json"
fi

CODEX_CONFIG_PATH="$config_path" \
CODEX_HOME_PATH="$config_home" \
AGENT_PLUGINS_MARKETPLACE_NAME="$MARKETPLACE_NAME" \
AGENT_PLUGINS_MARKETPLACE_JSON_PATH="$marketplace_json_path" \
python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import shutil
from pathlib import Path


config_path = Path(os.environ["CODEX_CONFIG_PATH"]).expanduser()
codex_home = Path(os.environ["CODEX_HOME_PATH"]).expanduser()
marketplace_name = os.environ["AGENT_PLUGINS_MARKETPLACE_NAME"]
marketplace_path = os.environ.get("AGENT_PLUGINS_MARKETPLACE_JSON_PATH", "")


def load_marketplace() -> dict[str, object]:
    if marketplace_path:
        with Path(marketplace_path).open(encoding="utf-8") as handle:
            return json.load(handle)

    raise SystemExit("Could not locate installed marketplace.json")


marketplace = load_marketplace()
marketplace_root = Path(marketplace_path).resolve().parents[2]
marketplace_name = str(marketplace.get("name") or marketplace_name)
cache_root = codex_home / "plugins" / "cache"
plugins = marketplace.get("plugins")
if not isinstance(plugins, list) or not plugins:
    raise SystemExit("Marketplace does not define any plugins to enable")


def safe_component(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise SystemExit(f"{label} must be a non-empty string")
    if value in {".", ".."} or "/" in value or "\\" in value or "\0" in value:
        raise SystemExit(f"{label} is not a safe path component: {value!r}")
    return value


def reject_symlinks(root: Path, label: str) -> None:
    for current, dirs, files in os.walk(root, followlinks=False):
        for name in [*dirs, *files]:
            path = Path(current) / name
            if path.is_symlink():
                raise SystemExit(f"{label} contains an unsupported symlink: {path}")


marketplace_name = safe_component(marketplace_name, "Marketplace name")
plugin_ids: list[str] = []
cache_installs: list[tuple[str, Path]] = []
for entry in plugins:
    if not isinstance(entry, dict):
        raise SystemExit("Marketplace plugin entries must include string names")
    plugin_name = safe_component(entry.get("name"), "Plugin name")
    plugin_ids.append(f"{plugin_name}@{marketplace_name}")

    source = entry.get("source")
    if not isinstance(source, dict):
        raise SystemExit(f"Marketplace entry {plugin_name} is missing a source")
    if source.get("source") != "local" or not isinstance(source.get("path"), str):
        raise SystemExit(f"Marketplace entry {plugin_name} must use a local source path")

    plugin_source_dir = (marketplace_root / source["path"]).resolve()
    try:
        plugin_source_dir.relative_to(marketplace_root)
    except ValueError as exc:
        raise SystemExit(f"Plugin source escapes marketplace root: {source['path']}") from exc

    manifest_path = plugin_source_dir / ".codex-plugin" / "plugin.json"
    if not manifest_path.is_file():
        raise SystemExit(f"Missing plugin manifest: {manifest_path}")
    with manifest_path.open(encoding="utf-8") as handle:
        manifest = json.load(handle)
    version = manifest.get("version")
    manifest_name = manifest.get("name")
    if manifest_name != plugin_name:
        raise SystemExit(
            f"Marketplace entry {plugin_name} does not match manifest name {manifest_name}"
        )
    version = safe_component(version, f"Plugin {plugin_name} version")

    cache_dir = cache_root / marketplace_name / plugin_name / version
    try:
        cache_dir.resolve(strict=False).relative_to(cache_root.resolve(strict=False))
    except ValueError as exc:
        raise SystemExit(f"Plugin cache path escapes cache root: {cache_dir}") from exc
    reject_symlinks(plugin_source_dir, f"Plugin {plugin_name}")
    if cache_dir.exists():
        shutil.rmtree(cache_dir)
    cache_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(
        plugin_source_dir,
        cache_dir,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store", ".git"),
    )
    cache_installs.append((f"{plugin_name}@{marketplace_name}", cache_dir))

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


def ensure_table_key(document: str, table: str, key: str, value: str) -> str:
    header = f"[{table}]"
    header_pattern = re.compile(rf"(?m)^\s*\[{re.escape(table)}\]\s*(?:#.*)?$")
    bounds = section_bounds(document, header_pattern)
    if not bounds:
        return document + f"\n{header}\n{key} = {value}\n"

    section_start, section_end = bounds
    section = document[section_start:section_end]
    key_pattern = re.compile(rf"(?m)^(\s*){re.escape(key)}\s*=.*$")
    if key_pattern.search(section):
        section = key_pattern.sub(rf"\1{key} = {value}", section, count=1)
    else:
        section = f"\n{key} = {value}" + section

    return document[:section_start] + section + document[section_end:]


def enable_inline_features(document: str) -> tuple[str, bool]:
    inline_pattern = re.compile(r"(?m)^(\s*features\s*=\s*\{)([^}\n]*)(\}\s*(?:#.*)?$)")
    match = inline_pattern.search(document)
    if not match:
        return document, False

    body = match.group(2)
    plugins_pattern = re.compile(r"(?<![\w-])plugins\s*=\s*(?:true|false)\b")
    if plugins_pattern.search(body):
        body = plugins_pattern.sub("plugins = true", body, count=1)
    elif body.strip():
        body = f" plugins = true, {body.strip()} "
    else:
        body = " plugins = true "

    return document[: match.start()] + match.group(1) + body + match.group(3) + document[match.end() :], True


def ensure_plugins_feature_enabled(document: str) -> str:
    if section_bounds(document, re.compile(r"(?m)^\s*\[features\]\s*(?:#.*)?$")):
        return ensure_table_key(document, "features", "plugins", "true")

    first_table = re.search(r"(?m)^\s*\[", document)
    top_level_end = first_table.start() if first_table else len(document)
    top_level = document[:top_level_end]
    table_sections = document[top_level_end:]

    top_level, replaced_inline = enable_inline_features(top_level)
    if replaced_inline:
        return top_level + table_sections

    dotted_plugins_pattern = re.compile(r"(?m)^(\s*)features\.plugins\s*=.*$")
    if dotted_plugins_pattern.search(top_level):
        return dotted_plugins_pattern.sub(r"\1features.plugins = true", top_level, count=1) + table_sections

    dotted_feature_lines = list(re.finditer(r"(?m)^\s*features\.[^\s=]+\s*=.*$", top_level))
    if dotted_feature_lines:
        last_line = dotted_feature_lines[-1]
        return (
            top_level[: last_line.end()]
            + "\nfeatures.plugins = true"
            + top_level[last_line.end() :]
            + table_sections
        )

    return document + "\n[features]\nplugins = true\n"


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


text = ensure_plugins_feature_enabled(text)
for plugin_id in plugin_ids:
    text = ensure_plugin_enabled(text, plugin_id)

config_path.write_text(text.lstrip("\n"), encoding="utf-8")

print(f"Installed plugin bundles in {codex_home / 'plugins' / 'cache'}:")
for plugin_id, cache_dir in cache_installs:
    print(f"  - {plugin_id}: {cache_dir}")
print(f"Enabled plugins in {config_path}:")
for plugin_id in plugin_ids:
    print(f"  - {plugin_id}")
PY
