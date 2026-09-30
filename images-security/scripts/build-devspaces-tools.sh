#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
oc apply -f "$repo_root/images-security/openshift/devspaces-tools.yaml"
oc -n admin-devspaces start-build images-security-devtools \
  --from-dir="$repo_root/images-security/containers" --follow --wait
