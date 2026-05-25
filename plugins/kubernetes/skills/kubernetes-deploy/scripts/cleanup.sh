#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage: cleanup.sh [project-path]

Deletes Codex-managed preview resources for an app.

By default, this refuses to delete non-preview namespaces. To delete resources
outside a codex-preview-* namespace, set K8S_CONFIRM_PRODUCTION_CLEANUP=1.
USAGE
}

PROJECT_ARG="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      PROJECT_ARG="$1"
      shift
      ;;
  esac
done

k8s_require_cmd kubectl
[ "${K8S_SKIP_CONTEXT_GUARD:-0}" = "1" ] || k8s_check_context_guard

PROJECT_PATH=$(k8s_abs_path "$PROJECT_ARG")
APP=$(k8s_dns_label "${K8S_DEPLOY_APP:-$(basename "$PROJECT_PATH")}")
SELECTOR=$(k8s_selector "$APP")
CURRENT_CONTEXT=$(k8s_current_context)
DELETE_NAMESPACE="${K8S_DELETE_NAMESPACE:-auto}"
PREVIEW_PREFIX=$(k8s_dns_label "${K8S_PREVIEW_NAMESPACE_PREFIX:-codex-preview}")

if [ -n "${K8S_DEPLOY_NAMESPACE:-}" ]; then
  NAMESPACES=$(k8s_dns_label "$K8S_DEPLOY_NAMESPACE")
else
  NAMESPACES=$(kubectl get namespace \
    -l "app.kubernetes.io/managed-by=codex,codex.openai.com/app=${APP},codex.openai.com/deploy-mode=preview" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
fi

if [ -z "$NAMESPACES" ]; then
  k8s_die "No Codex-managed preview namespaces found for app '$APP'. Set K8S_DEPLOY_NAMESPACE to target one."
fi

k8s_info "Kubernetes cleanup"
k8s_info "  context: $CURRENT_CONTEXT"
k8s_info "  app:     $APP"
k8s_info ""

DELETED_NAMESPACES=""
DELETED_RESOURCES=""

while IFS= read -r NAMESPACE; do
  [ -n "$NAMESPACE" ] || continue
  MANAGED=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)

  IS_PREVIEW_NAMESPACE=false
  k8s_namespace_has_preview_prefix "$NAMESPACE" "$PREVIEW_PREFIX" && IS_PREVIEW_NAMESPACE=true

  if [ "$IS_PREVIEW_NAMESPACE" != true ] && [ "${K8S_CONFIRM_PRODUCTION_CLEANUP:-0}" != "1" ]; then
    k8s_die "Refusing to clean namespace '$NAMESPACE' because it does not start with K8S_PREVIEW_NAMESPACE_PREFIX='$PREVIEW_PREFIX'. Set K8S_CONFIRM_PRODUCTION_CLEANUP=1 if this is intentional."
  fi

  k8s_info "Cleaning namespace: $NAMESPACE"
  kubectl delete deployment,service,ingress -n "$NAMESPACE" -l "$SELECTOR" --ignore-not-found >&2
  DELETED_RESOURCES="${DELETED_RESOURCES}${NAMESPACE} "

  if [ "$DELETE_NAMESPACE" = "1" ] || { [ "$DELETE_NAMESPACE" = "auto" ] && [ "$IS_PREVIEW_NAMESPACE" = true ] && [ "$MANAGED" = "codex" ]; }; then
    k8s_info "Deleting preview namespace: $NAMESPACE"
    kubectl delete namespace "$NAMESPACE" --ignore-not-found >&2
    DELETED_NAMESPACES="${DELETED_NAMESPACES}${NAMESPACE} "
  else
    k8s_info "Leaving namespace in place: $NAMESPACE"
  fi
done <<EOF
$NAMESPACES
EOF

printf '{'
printf '"context":"%s",' "$(k8s_json_escape "$CURRENT_CONTEXT")"
printf '"app":"%s",' "$(k8s_json_escape "$APP")"
printf '"deletedResourceNamespaces":"%s",' "$(k8s_json_escape "$DELETED_RESOURCES")"
printf '"deletedNamespaces":"%s"' "$(k8s_json_escape "$DELETED_NAMESPACES")"
printf '}\n'
