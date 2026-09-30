#!/usr/bin/env bash

submit_pipeline_run() {
  local variant=$1 profile=$2
  local tag="${variant}-${profile}"
  local registry=image-registry.openshift-image-registry.svc:5000/images-security
  local rox_cluster=${ROX_CLUSTER:-my-cluster}

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
      value: ${registry}/security-demo:${tag}
    - name: rox-cluster
      value: ${rox_cluster}
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
