#!/usr/bin/env bash
set -euo pipefail

workspace_name=${1:-images-security}
workspace_namespace=${2:-admin-devspaces}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
workspace_id=$(oc -n "$workspace_namespace" get devworkspace "$workspace_name" -o jsonpath='{.status.devworkspaceId}')
if [[ -z "$workspace_id" ]]; then
  echo "DevWorkspace sem ID: ${workspace_namespace}/${workspace_name}" >&2
  exit 1
fi

oc apply -f "$repo_root/images-security/openshift/devspaces-demo-access.yaml"
oc -n images-security create rolebinding images-security-devspaces-demo \
  --role=images-security-devspaces-demo \
  --serviceaccount="${workspace_namespace}:${workspace_id}-sa" \
  --dry-run=client -o yaml | oc apply -f -
