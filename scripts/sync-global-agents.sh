#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-global-agents.sh [apply|check|diff|pull]

Commands:
  apply  Copy global/AGENTS.md to ${CODEX_HOME:-$HOME/.codex}/AGENTS.md. Default.
  check  Exit 0 when the repo copy and global file match; otherwise show a diff.
  diff   Show a unified diff between the repo copy and global file.
  pull   Copy ${CODEX_HOME:-$HOME/.codex}/AGENTS.md back into global/AGENTS.md.

Environment:
  CODEX_HOME      Override the Codex home directory. Defaults to $HOME/.codex.
  AGENTS_SOURCE   Override the repo source file path.
  AGENTS_TARGET   Override the global target file path.
USAGE
}

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home="${CODEX_HOME:-$HOME/.codex}"
source_path="${AGENTS_SOURCE:-$repo_root/global/AGENTS.md}"
target_path="${AGENTS_TARGET:-$codex_home/AGENTS.md}"
command="${1:-apply}"

require_file() {
  local path="$1"
  local label="$2"

  if [[ ! -f "$path" ]]; then
    echo "$label does not exist: $path" >&2
    exit 2
  fi
}

show_diff() {
  require_file "$source_path" "Source AGENTS.md"
  if [[ ! -f "$target_path" ]]; then
    echo "Target AGENTS.md does not exist: $target_path" >&2
    exit 1
  fi

  diff -u "$source_path" "$target_path"
}

case "$command" in
  apply|sync|install)
    require_file "$source_path" "Source AGENTS.md"
    mkdir -p "$(dirname -- "$target_path")"
    cp "$source_path" "$target_path"
    echo "Synced $source_path -> $target_path"
    ;;
  check)
    require_file "$source_path" "Source AGENTS.md"
    if [[ ! -f "$target_path" ]]; then
      echo "Target AGENTS.md does not exist: $target_path" >&2
      exit 1
    fi

    if cmp -s "$source_path" "$target_path"; then
      echo "AGENTS.md is in sync."
    else
      echo "AGENTS.md is out of sync:" >&2
      diff -u "$source_path" "$target_path" || true
      exit 1
    fi
    ;;
  diff)
    show_diff
    ;;
  pull)
    require_file "$target_path" "Target AGENTS.md"
    mkdir -p "$(dirname -- "$source_path")"
    cp "$target_path" "$source_path"
    echo "Synced $target_path -> $source_path"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
