#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage: deploy.sh [project-path] [--production]

Deploys a project or existing image to Kubernetes.

Preview is the default. Production requires --production, K8S_DEPLOY_NAMESPACE,
and K8S_DEPLOY_CONTEXT unless K8S_SKIP_CONTEXT_GUARD=1 is set.
USAGE
}

MODE="preview"
PROJECT_ARG="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --production|--prod)
      MODE="production"
      shift
      ;;
    --preview)
      MODE="preview"
      shift
      ;;
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
TAG=$(k8s_dns_label "${K8S_DEPLOY_TAG:-$(k8s_image_tag "$PROJECT_PATH")}")
PREVIEW_SLUG=$(k8s_preview_slug "$PROJECT_PATH")
PREVIEW_PREFIX=$(k8s_dns_label "${K8S_PREVIEW_NAMESPACE_PREFIX:-codex-preview}")

if [ "$MODE" = "production" ]; then
  [ -n "${K8S_DEPLOY_NAMESPACE:-}" ] || k8s_die "Production deploys require K8S_DEPLOY_NAMESPACE"
  [ -n "${K8S_DEPLOY_CONTEXT:-}" ] || [ "${K8S_SKIP_CONTEXT_GUARD:-0}" = "1" ] || \
    k8s_die "Production deploys require K8S_DEPLOY_CONTEXT as a context guard"
  NAMESPACE=$(k8s_dns_label "$K8S_DEPLOY_NAMESPACE")
else
  if [ -n "${K8S_DEPLOY_NAMESPACE:-}" ]; then
    NAMESPACE=$(k8s_dns_label "$K8S_DEPLOY_NAMESPACE")
    if ! k8s_namespace_has_preview_prefix "$NAMESPACE" "$PREVIEW_PREFIX"; then
      k8s_die "Preview namespace '$NAMESPACE' must start with K8S_PREVIEW_NAMESPACE_PREFIX='$PREVIEW_PREFIX'"
    fi
  else
    NAMESPACE=$(k8s_preview_namespace "$PREVIEW_PREFIX" "$APP" "$PREVIEW_SLUG")
  fi
fi

EXPOSE_MODE=$(k8s_sanitize_name "${K8S_EXPOSE_MODE:-port-forward}")
case "$EXPOSE_MODE" in
  port-forward|none|ingress|loadbalancer) ;;
  *) k8s_die "K8S_EXPOSE_MODE must be one of: port-forward, none, ingress, loadbalancer" ;;
esac

CONTAINER_PORT="${K8S_CONTAINER_PORT:-3000}"
SERVICE_PORT="${K8S_SERVICE_PORT:-$CONTAINER_PORT}"
LOCAL_PORT="${K8S_PORT_FORWARD_PORT:-$SERVICE_PORT}"
REPLICAS="${K8S_REPLICAS:-1}"
ROLLOUT_TIMEOUT="${K8S_ROLLOUT_TIMEOUT:-180s}"
IMAGE_PULL_POLICY="${K8S_IMAGE_PULL_POLICY:-IfNotPresent}"
SERVICE_TYPE="ClusterIP"
[ "$EXPOSE_MODE" = "loadbalancer" ] && SERVICE_TYPE="LoadBalancer"

case "$CONTAINER_PORT$SERVICE_PORT$LOCAL_PORT$REPLICAS" in
  *[!0-9]*) k8s_die "K8S_CONTAINER_PORT, K8S_SERVICE_PORT, K8S_PORT_FORWARD_PORT, and K8S_REPLICAS must be integers" ;;
esac

if [ "$EXPOSE_MODE" = "ingress" ]; then
  [ -n "${K8S_INGRESS_HOST:-}" ] || k8s_die "K8S_INGRESS_HOST is required when K8S_EXPOSE_MODE=ingress"
fi

IMAGE_REF="${K8S_DEPLOY_IMAGE:-}"
BUILT_IMAGE="false"
PUSHED_IMAGE="false"

if [ -z "$IMAGE_REF" ]; then
  k8s_require_cmd docker
  DOCKERFILE="${K8S_DOCKERFILE:-Dockerfile}"
  DOCKERFILE_PATH="$PROJECT_PATH/$DOCKERFILE"
  [ -f "$DOCKERFILE_PATH" ] || k8s_die "No K8S_DEPLOY_IMAGE set and no Dockerfile found at $DOCKERFILE_PATH"
  [ -n "${K8S_DEPLOY_REGISTRY:-}" ] || k8s_die "K8S_DEPLOY_REGISTRY is required when building an image"
  REGISTRY=${K8S_DEPLOY_REGISTRY%/}
  IMAGE_REF="${REGISTRY}/${APP}:${TAG}"
  k8s_info "Building image: $IMAGE_REF"
  docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_REF" "$PROJECT_PATH" >&2
  BUILT_IMAGE="true"
  if [ "${K8S_DEPLOY_SKIP_PUSH:-0}" != "1" ]; then
    k8s_info "Pushing image: $IMAGE_REF"
    docker push "$IMAGE_REF" >&2
    PUSHED_IMAGE="true"
    if [ "${K8S_USE_IMAGE_DIGEST:-1}" = "1" ]; then
      DIGEST_REF=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_REF" 2>/dev/null || true)
      [ -n "$DIGEST_REF" ] && IMAGE_REF="$DIGEST_REF"
    fi
  else
    k8s_info "Skipping docker push because K8S_DEPLOY_SKIP_PUSH=1"
  fi
fi

TEMP_DIR=$(mktemp -d)
cleanup_temp() {
  rm -rf "$TEMP_DIR"
}
trap cleanup_temp EXIT

NAMESPACE_YAML="$TEMP_DIR/namespace.yaml"
WORKLOAD_YAML="$TEMP_DIR/workload.yaml"

cat >"$NAMESPACE_YAML" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: codex
    codex.openai.com/app: ${APP}
    codex.openai.com/deploy-mode: ${MODE}
    codex.openai.com/preview-prefix: ${PREVIEW_PREFIX}
YAML

cat >"$WORKLOAD_YAML" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${APP}
    app.kubernetes.io/managed-by: codex
    codex.openai.com/deploy-mode: ${MODE}
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${APP}
      app.kubernetes.io/managed-by: codex
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${APP}
        app.kubernetes.io/managed-by: codex
        codex.openai.com/deploy-mode: ${MODE}
    spec:
      containers:
        - name: ${APP}
          image: ${IMAGE_REF}
          imagePullPolicy: ${IMAGE_PULL_POLICY}
          ports:
            - containerPort: ${CONTAINER_PORT}
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${APP}
    app.kubernetes.io/managed-by: codex
    codex.openai.com/deploy-mode: ${MODE}
spec:
  type: ${SERVICE_TYPE}
  selector:
    app.kubernetes.io/name: ${APP}
    app.kubernetes.io/managed-by: codex
  ports:
    - name: http
      port: ${SERVICE_PORT}
      targetPort: ${CONTAINER_PORT}
YAML

if [ "$EXPOSE_MODE" = "ingress" ]; then
  INGRESS_PATH="${K8S_INGRESS_PATH:-/}"
  {
    cat <<YAML
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${APP}
    app.kubernetes.io/managed-by: codex
    codex.openai.com/deploy-mode: ${MODE}
YAML
    if [ -n "${K8S_INGRESS_CLASS:-}" ]; then
      cat <<YAML
  annotations:
    kubernetes.io/ingress.class: ${K8S_INGRESS_CLASS}
YAML
    fi
    cat <<YAML
spec:
YAML
    if [ -n "${K8S_INGRESS_CLASS:-}" ]; then
      cat <<YAML
  ingressClassName: ${K8S_INGRESS_CLASS}
YAML
    fi
    if [ -n "${K8S_INGRESS_TLS_SECRET:-}" ]; then
      cat <<YAML
  tls:
    - hosts:
        - ${K8S_INGRESS_HOST}
      secretName: ${K8S_INGRESS_TLS_SECRET}
YAML
    fi
    cat <<YAML
  rules:
    - host: ${K8S_INGRESS_HOST}
      http:
        paths:
          - path: ${INGRESS_PATH}
            pathType: Prefix
            backend:
              service:
                name: ${APP}
                port:
                  number: ${SERVICE_PORT}
YAML
  } >>"$WORKLOAD_YAML"
fi

CURRENT_CONTEXT=$(k8s_current_context)
CLUSTER_SERVER=$(k8s_cluster_server)

k8s_info "Kubernetes deployment preflight"
k8s_info "  mode:       $MODE"
k8s_info "  context:    $CURRENT_CONTEXT"
k8s_info "  cluster:    ${CLUSTER_SERVER:-unknown}"
k8s_info "  namespace:  $NAMESPACE"
k8s_info "  app:        $APP"
k8s_info "  image:      $IMAGE_REF"
k8s_info "  exposure:   $EXPOSE_MODE"
k8s_info ""

k8s_info "Validating manifests with kubectl dry-run..."
if [ "$MODE" = "preview" ]; then
  kubectl apply --dry-run=server -f "$NAMESPACE_YAML" >/dev/null
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    kubectl apply --dry-run=server -f "$WORKLOAD_YAML" >/dev/null
  else
    kubectl apply --dry-run=client -f "$WORKLOAD_YAML" >/dev/null
    k8s_info "Namespace does not exist yet; workload server-side dry-run will run after namespace creation."
  fi
else
  kubectl get namespace "$NAMESPACE" >/dev/null || k8s_die "Production namespace does not exist: $NAMESPACE"
  kubectl apply --dry-run=server -f "$WORKLOAD_YAML" >/dev/null
fi

if [ "${K8S_DRY_RUN:-0}" = "1" ]; then
  k8s_info "K8S_DRY_RUN=1 set; not applying resources."
else
  if [ "$MODE" = "preview" ]; then
    kubectl apply -f "$NAMESPACE_YAML" >&2
    kubectl apply --dry-run=server -f "$WORKLOAD_YAML" >/dev/null
  fi
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    k8s_info "Showing kubectl diff when supported..."
    set +e
    kubectl diff -f "$WORKLOAD_YAML" >&2
    DIFF_STATUS=$?
    set -e
    if [ "$DIFF_STATUS" -gt 1 ]; then
      k8s_info "kubectl diff was not available or failed; continuing after server-side dry-run."
    fi
  fi
  kubectl apply -f "$WORKLOAD_YAML" >&2
  kubectl rollout status "deployment/${APP}" -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT" >&2
fi

PORT_FORWARD_COMMAND="kubectl port-forward -n ${NAMESPACE} svc/${APP} ${LOCAL_PORT}:${SERVICE_PORT}"
LOCAL_URL="http://localhost:${LOCAL_PORT}"
PUBLIC_URL=""

if [ "$EXPOSE_MODE" = "ingress" ]; then
  SCHEME="http"
  [ -n "${K8S_INGRESS_TLS_SECRET:-}" ] && SCHEME="https"
  PUBLIC_URL="${SCHEME}://${K8S_INGRESS_HOST}${K8S_INGRESS_PATH:-/}"
elif [ "$EXPOSE_MODE" = "loadbalancer" ]; then
  PUBLIC_URL=$(kubectl get svc "$APP" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$PUBLIC_URL" ] || PUBLIC_URL=$(kubectl get svc "$APP" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "$PUBLIC_URL" ] && PUBLIC_URL="http://${PUBLIC_URL}:${SERVICE_PORT}"
fi

k8s_info ""
if [ "$EXPOSE_MODE" = "port-forward" ]; then
  k8s_info "Port-forward command:"
  k8s_info "  $PORT_FORWARD_COMMAND"
  k8s_info "Local URL after starting port-forward: $LOCAL_URL"
elif [ -n "$PUBLIC_URL" ]; then
  k8s_info "Deployment URL: $PUBLIC_URL"
else
  k8s_info "No public URL is available for exposure mode: $EXPOSE_MODE"
fi

printf '{'
printf '"mode":"%s",' "$(k8s_json_escape "$MODE")"
printf '"context":"%s",' "$(k8s_json_escape "$CURRENT_CONTEXT")"
printf '"namespace":"%s",' "$(k8s_json_escape "$NAMESPACE")"
printf '"app":"%s",' "$(k8s_json_escape "$APP")"
printf '"image":"%s",' "$(k8s_json_escape "$IMAGE_REF")"
printf '"builtImage":%s,' "$BUILT_IMAGE"
printf '"pushedImage":%s,' "$PUSHED_IMAGE"
printf '"exposeMode":"%s",' "$(k8s_json_escape "$EXPOSE_MODE")"
printf '"localUrl":"%s",' "$(k8s_json_escape "$LOCAL_URL")"
printf '"portForwardCommand":"%s",' "$(k8s_json_escape "$PORT_FORWARD_COMMAND")"
printf '"publicUrl":"%s"' "$(k8s_json_escape "$PUBLIC_URL")"
printf '}\n'
