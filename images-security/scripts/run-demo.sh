#!/usr/bin/env bash
set -euo pipefail

ROX_CLUSTER=${ROX_CLUSTER:-my-cluster}
REGISTRY=image-registry.openshift-image-registry.svc:5000/images-security

submit() {
  local variant=$1 profile=$2
  local tag="${variant}-${profile}"
  oc -n images-security create -f - <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: images-security-${tag}-
spec:
  pipelineRef:
    name: images-security
  taskRunTemplate:
    serviceAccountName: pipeline
  params:
    - name: variant
      value: ${variant}
    - name: maven-profile
      value: ${profile}
    - name: image
      value: ${REGISTRY}/security-demo:${tag}
    - name: rox-cluster
      value: ${ROX_CLUSTER}
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 2Gi
YAML
}

case ${1:-all} in
  all)
    submit community unsafe
    submit community none
    submit ubi none
    submit rhhi none
    ;;
  rhhi)
    submit rhhi none
    ;;
  *)
    echo "Uso: $0 [all|rhhi]" >&2
    exit 2
    ;;
esac

oc -n images-security get pipelineruns
