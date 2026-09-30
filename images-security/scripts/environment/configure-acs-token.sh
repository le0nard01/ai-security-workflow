#!/usr/bin/env bash
set -euo pipefail

if oc -n images-security get secret rox-api-token >/dev/null 2>&1; then
  echo 'rox-api-token já existe em images-security.'
  exit 0
fi

central_host=$(oc -n rhacs-operator get route central -o jsonpath='{.spec.host}')
admin_password=$(oc -n rhacs-operator get secret central-htpasswd -o jsonpath='{.data.password}' | base64 --decode)
response=$(curl --fail --silent --show-error --insecure \
  -u "admin:${admin_password}" \
  -H 'Content-Type: application/json' \
  -d '{"name":"images-security-pipeline","roles":["Continuous Integration"]}' \
  "https://${central_host}/v1/apitokens/generate")
unset admin_password
token=$(printf '%s' "$response" | jq -er '.token')
unset response
oc -n images-security create secret generic rox-api-token --from-literal="token=${token}" >/dev/null
unset token
echo 'Token do ACS criado com papel Continuous Integration e guardado no Secret rox-api-token.'
