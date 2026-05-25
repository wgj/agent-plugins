#!/usr/bin/env bash

k8s_die() {
  echo "Error: $*" >&2
  exit 1
}

k8s_info() {
  echo "$*" >&2
}

k8s_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || k8s_die "Required command not found: $1"
}

k8s_abs_path() {
  local raw_path="${1:-.}"
  [ -d "$raw_path" ] || k8s_die "Project path is not a directory: $raw_path"
  (cd "$raw_path" && pwd)
}

k8s_sanitize_name() {
  local value="${1:-app}"
  value=$(printf '%s' "$value" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  [ -n "$value" ] || value="app"
  printf '%s' "$value"
}

k8s_dns_label() {
  local value
  value=$(k8s_sanitize_name "$1")
  value=${value:0:63}
  value=$(printf '%s' "$value" | sed -E 's/^-+//; s/-+$//')
  [ -n "$value" ] || value="app"
  printf '%s' "$value"
}

k8s_preview_slug() {
  local project_path="$1"
  local slug=""
  if command -v git >/dev/null 2>&1 && git -C "$project_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    slug=$(git -C "$project_path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    [ "$slug" = "HEAD" ] && slug=$(git -C "$project_path" rev-parse --short HEAD 2>/dev/null || true)
  fi
  [ -n "$slug" ] || slug=$(date -u +%Y%m%d%H%M%S)
  k8s_dns_label "$slug"
}

k8s_preview_namespace() {
  local prefix="$1"
  local app="$2"
  local slug="$3"
  local hash
  if command -v shasum >/dev/null 2>&1; then
    hash=$(printf '%s-%s' "$app" "$slug" | shasum | awk '{print $1}')
  elif command -v sha1sum >/dev/null 2>&1; then
    hash=$(printf '%s-%s' "$app" "$slug" | sha1sum | awk '{print $1}')
  else
    hash=$(printf '%s-%s' "$app" "$slug" | cksum | awk '{print $1}')
  fi
  hash=${hash:0:8}
  prefix=$(k8s_dns_label "$prefix")
  app=$(k8s_dns_label "$app")
  slug=$(k8s_dns_label "$slug")

  local suffix_budget=$((63 - ${#prefix} - ${#hash} - 3))
  if [ "$suffix_budget" -lt 8 ]; then
    k8s_die "K8S_PREVIEW_NAMESPACE_PREFIX is too long; use 44 characters or fewer"
  fi

  local app_budget=$((suffix_budget / 2))
  local slug_budget=$((suffix_budget - app_budget - 1))
  app=${app:0:$app_budget}
  slug=${slug:0:$slug_budget}
  app=$(printf '%s' "$app" | sed -E 's/^-+//; s/-+$//')
  slug=$(printf '%s' "$slug" | sed -E 's/^-+//; s/-+$//')

  printf '%s-%s-%s-%s' "$prefix" "$app" "$slug" "$hash" | sed -E 's/-+/-/g; s/-+$//'
}

k8s_namespace_has_preview_prefix() {
  local namespace="$1"
  local prefix="$2"
  [ "$namespace" = "$prefix" ] || [[ "$namespace" == "$prefix"-* ]]
}

k8s_namespace_is_generated_preview() {
  local namespace="$1"
  local prefix="$2"
  [[ "$namespace" == "$prefix"-* ]]
}

k8s_image_tag() {
  local project_path="$1"
  local tag=""
  if command -v git >/dev/null 2>&1 && git -C "$project_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tag=$(git -C "$project_path" rev-parse --short HEAD 2>/dev/null || true)
  fi
  [ -n "$tag" ] || tag=$(date -u +%Y%m%d%H%M%S)
  k8s_dns_label "$tag"
}

k8s_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

k8s_current_context() {
  kubectl config current-context 2>/dev/null || true
}

k8s_cluster_server() {
  kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true
}

k8s_check_context_guard() {
  local current_context expected_context
  current_context=$(k8s_current_context)
  [ -n "$current_context" ] || k8s_die "No active Kubernetes context. Configure kubectl first."
  expected_context="${K8S_DEPLOY_CONTEXT:-}"
  if [ -n "$expected_context" ] && [ "$current_context" != "$expected_context" ]; then
    k8s_die "Active context '$current_context' does not match K8S_DEPLOY_CONTEXT='$expected_context'"
  fi
}

k8s_selector() {
  local app="$1"
  printf 'app.kubernetes.io/name=%s,app.kubernetes.io/managed-by=codex' "$app"
}
