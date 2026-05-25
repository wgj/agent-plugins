#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage: status.sh [project-path]

Shows Kubernetes resources managed by the kubernetes-deploy skill for the app.
Set K8S_DEPLOY_NAMESPACE to target a specific namespace.
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

if [ -n "${K8S_DEPLOY_NAMESPACE:-}" ]; then
  NAMESPACES=$(k8s_dns_label "$K8S_DEPLOY_NAMESPACE")
else
  NAMESPACES=$(kubectl get namespace \
    -l "app.kubernetes.io/managed-by=codex,codex.openai.com/app=${APP}" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
fi

if [ -z "$NAMESPACES" ]; then
  k8s_die "No Codex-managed Kubernetes resources found for app '$APP'. Set K8S_DEPLOY_NAMESPACE if needed."
fi

k8s_info "Kubernetes deployment status"
k8s_info "  context: $CURRENT_CONTEXT"
k8s_info "  app:     $APP"
k8s_info ""

FIRST_JSON=true
JSON_NAMESPACES=""

while IFS= read -r NAMESPACE; do
  [ -n "$NAMESPACE" ] || continue
  k8s_info "Namespace: $NAMESPACE"
  kubectl get deployment,service,ingress -n "$NAMESPACE" -l "$SELECTOR" -o wide >&2 || true
  k8s_info ""
  kubectl rollout status "deployment/${APP}" -n "$NAMESPACE" --timeout=10s >&2 || true

  SERVICE_PORT=$(kubectl get svc "$APP" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)
  [ -n "$SERVICE_PORT" ] || SERVICE_PORT="${K8S_SERVICE_PORT:-3000}"
  LOCAL_PORT="${K8S_PORT_FORWARD_PORT:-$SERVICE_PORT}"
  PORT_FORWARD_COMMAND="kubectl port-forward -n ${NAMESPACE} svc/${APP} ${LOCAL_PORT}:${SERVICE_PORT}"

  INGRESS_HOST=$(kubectl get ingress "$APP" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)
  LB_HOST=$(kubectl get svc "$APP" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$LB_HOST" ] || LB_HOST=$(kubectl get svc "$APP" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

  JSON_ENTRY="{"
  JSON_ENTRY="${JSON_ENTRY}\"namespace\":\"$(k8s_json_escape "$NAMESPACE")\","
  JSON_ENTRY="${JSON_ENTRY}\"portForwardCommand\":\"$(k8s_json_escape "$PORT_FORWARD_COMMAND")\","
  JSON_ENTRY="${JSON_ENTRY}\"localUrl\":\"http://localhost:$(k8s_json_escape "$LOCAL_PORT")\","
  JSON_ENTRY="${JSON_ENTRY}\"ingressHost\":\"$(k8s_json_escape "$INGRESS_HOST")\","
  JSON_ENTRY="${JSON_ENTRY}\"loadBalancer\":\"$(k8s_json_escape "$LB_HOST")\""
  JSON_ENTRY="${JSON_ENTRY}}"

  if [ "$FIRST_JSON" = true ]; then
    JSON_NAMESPACES="$JSON_ENTRY"
  else
    JSON_NAMESPACES="${JSON_NAMESPACES},${JSON_ENTRY}"
  fi
  FIRST_JSON=false
done <<EOF
$NAMESPACES
EOF

printf '{"context":"%s","app":"%s","namespaces":[%s]}\n' \
  "$(k8s_json_escape "$CURRENT_CONTEXT")" \
  "$(k8s_json_escape "$APP")" \
  "$JSON_NAMESPACES"
