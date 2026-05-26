#!/usr/bin/env python3
"""Validate local plugin marketplace and manifest wiring."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MARKETPLACE_PATH = ROOT / ".agents/plugins/marketplace.json"


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"{path.relative_to(ROOT)} is invalid JSON: {exc}") from exc


def repo_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def resolve_repo_path(value: str, base_dir: Path, source_file: Path) -> Path:
    path = (base_dir / value).resolve()
    try:
        path.relative_to(ROOT)
    except ValueError as exc:
        raise ValueError(f"{source_file.relative_to(ROOT)} points outside the repo: {value}") from exc
    return path


def validate_required_string(document: dict[str, Any], key: str, label: str, errors: list[str]) -> str | None:
    value = document.get(key)
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{label} must define a non-empty string field `{key}`")
        return None
    return value


def validate_manifest(plugin_dir: Path, marketplace_name: str, marketplace_category: str, errors: list[str]) -> None:
    manifest_path = plugin_dir / ".codex-plugin/plugin.json"
    if not manifest_path.is_file():
        errors.append(f"{repo_relative(plugin_dir)} is missing .codex-plugin/plugin.json")
        return

    manifest = load_json(manifest_path)
    if not isinstance(manifest, dict):
        errors.append(f"{repo_relative(manifest_path)} must contain a JSON object")
        return

    manifest_name = validate_required_string(manifest, "name", repo_relative(manifest_path), errors)
    if manifest_name and manifest_name != marketplace_name:
        errors.append(
            f"{repo_relative(manifest_path)} name `{manifest_name}` does not match marketplace name `{marketplace_name}`"
        )

    for key in ["version", "description", "skills"]:
        validate_required_string(manifest, key, repo_relative(manifest_path), errors)

    interface = manifest.get("interface")
    if not isinstance(interface, dict):
        errors.append(f"{repo_relative(manifest_path)} must define an `interface` object")
        return

    for key in ["displayName", "shortDescription", "longDescription", "developerName", "category"]:
        validate_required_string(interface, key, f"{repo_relative(manifest_path)} interface", errors)

    if interface.get("category") != marketplace_category:
        errors.append(
            f"{repo_relative(manifest_path)} interface.category `{interface.get('category')}` "
            f"does not match marketplace category `{marketplace_category}`"
        )

    capabilities = interface.get("capabilities")
    if not isinstance(capabilities, list) or not capabilities:
        errors.append(f"{repo_relative(manifest_path)} interface.capabilities must be a non-empty list")

    prompts = interface.get("defaultPrompt")
    if not isinstance(prompts, list) or not all(isinstance(prompt, str) and prompt.strip() for prompt in prompts):
        errors.append(f"{repo_relative(manifest_path)} interface.defaultPrompt must be a list of non-empty strings")

    skills_value = manifest.get("skills")
    if isinstance(skills_value, str):
        skills_dir = resolve_repo_path(skills_value, plugin_dir, manifest_path)
        if not skills_dir.is_dir():
            errors.append(f"{repo_relative(manifest_path)} skills path does not exist: {skills_value}")
        elif not list(skills_dir.glob("*/SKILL.md")):
            errors.append(f"{repo_relative(skills_dir)} must contain at least one skill directory with SKILL.md")

    for asset_key in ["composerIcon", "logo"]:
        asset_value = interface.get(asset_key)
        if isinstance(asset_value, str):
            asset_path = resolve_repo_path(asset_value, plugin_dir, manifest_path)
            if not asset_path.is_file():
                errors.append(f"{repo_relative(manifest_path)} {asset_key} path does not exist: {asset_value}")


def validate_marketplace(errors: list[str]) -> None:
    if not MARKETPLACE_PATH.is_file():
        errors.append(".agents/plugins/marketplace.json is missing")
        return

    marketplace = load_json(MARKETPLACE_PATH)
    if not isinstance(marketplace, dict):
        errors.append(".agents/plugins/marketplace.json must contain a JSON object")
        return

    plugins = marketplace.get("plugins")
    if not isinstance(plugins, list) or not plugins:
        errors.append(".agents/plugins/marketplace.json must define a non-empty plugins list")
        return

    seen_names: set[str] = set()
    marketplace_dirs: set[Path] = set()
    for index, entry in enumerate(plugins):
        label = f".agents/plugins/marketplace.json plugins[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{label} must be an object")
            continue

        name = validate_required_string(entry, "name", label, errors)
        category = validate_required_string(entry, "category", label, errors)
        if name:
            if name in seen_names:
                errors.append(f"{label} duplicates marketplace plugin name `{name}`")
            seen_names.add(name)

        source = entry.get("source")
        if not isinstance(source, dict):
            errors.append(f"{label} must define a source object")
            continue
        if source.get("source") != "local":
            errors.append(f"{label} source.source must be `local`")
        source_path = source.get("path")
        if not isinstance(source_path, str) or not source_path.startswith("./plugins/"):
            errors.append(f"{label} source.path must be a local ./plugins/... path")
            continue

        plugin_dir = resolve_repo_path(source_path, ROOT, MARKETPLACE_PATH)
        marketplace_dirs.add(plugin_dir)
        if not plugin_dir.is_dir():
            errors.append(f"{label} source.path does not exist: {source_path}")
            continue

        if name and category:
            validate_manifest(plugin_dir, name, category, errors)

    manifest_dirs = {path.parents[1].resolve() for path in ROOT.glob("plugins/*/.codex-plugin/plugin.json")}
    missing_from_marketplace = sorted(manifest_dirs - marketplace_dirs, key=lambda path: path.as_posix())
    for plugin_dir in missing_from_marketplace:
        errors.append(f"{repo_relative(plugin_dir)} has a plugin manifest but is not listed in marketplace.json")


def main() -> int:
    errors: list[str] = []
    try:
        validate_marketplace(errors)
    except ValueError as exc:
        errors.append(str(exc))

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print("Plugin catalog integrity checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
