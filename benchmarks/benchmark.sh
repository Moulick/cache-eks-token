#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <kubeconfig> <aws-profile> <namespace>" >&2
  exit 1
fi

readonly KUBECONFIG="$1"
export AWS_PROFILE="$2"
readonly NAMESPACE="$3"
readonly RESULTS="benchmarks/results/2026-07-24"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sed 's|command: ../cache-eks-token/cached-aws-eks-token.sh|command: aws|' \
  "$KUBECONFIG" >"$TMP/direct.kubeconfig"

mkdir -p "$RESULTS"

hyperfine --warmup 1 --runs 5 \
  --command-name "kubectl with aws exec" \
  "KUBECONFIG='$TMP/direct.kubeconfig' kubectl get pods -n '$NAMESPACE' --request-timeout=30s -o name" \
  --command-name "kubectl with cached exec" \
  "KUBECONFIG='$KUBECONFIG' kubectl get pods -n '$NAMESPACE' --request-timeout=30s -o name" \
  --export-json "$RESULTS/kubectl.json"
