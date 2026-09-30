#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
archive=$(mktemp /tmp/images-security-source.XXXXXX.tgz)
trap 'rm -f "$archive"' EXIT

tar -C "$repo_root" --exclude='images-security/app/target' -czf "$archive" \
  images-security/app images-security/containers
oc -n images-security create configmap images-security-source \
  --from-file="source.tgz=${archive}" --dry-run=client -o yaml | oc apply -f -
echo 'Snapshot da aplicação e dos Containerfiles publicado no cluster.'
