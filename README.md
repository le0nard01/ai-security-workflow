# AI Security Workflow

This repository contains:

- `resources/apps/quarkus-vulnerable-app/`: a small Quarkus REST app with deliberately vulnerable dependencies for scanner demonstrations.
- `resources/openshift/pipelines/`: OpenShift Pipelines resources that build the app from Red Hat Hardened OpenJDK images and push it to the local OpenShift registry.

## Red Hat Hardened Image Base

The sample app uses a multi-stage `Containerfile`:

```text
Build:   registry.access.redhat.com/ubi9/openjdk-17:latest
Runtime: registry.access.redhat.com/hi/openjdk:latest-runtime
```

The pipeline pushes by default to:

```text
image-registry.openshift-image-registry.svc:5000/$(context.pipelineRun.namespace)/quarkus-vuln-demo:latest
```

## Run In OpenShift

No local Maven or container build is required. The pipeline clones this repository, runs a multi-stage Buildah build, and pushes the result to the OpenShift internal registry.

```sh
oc apply -f resources/openshift/pipelines/quarkus-vulnerable-app-pipeline.yaml
```

Create the `PipelineRun` after setting the `git-url` value to the remote URL for this repository:

```sh
oc apply -f resources/openshift/pipelines/quarkus-vulnerable-app-pipelinerun.yaml
```

If your cluster requires registry credentials for Red Hat images, attach your Red Hat pull secret to the `pipeline` service account:

```sh
oc secrets link pipeline redhat-pull-secret --for=pull
```

Create a RHACS token secret before running the pipeline:

```sh
oc create secret generic rox-api-token --from-literal=token='<RHACS_API_TOKEN>'
```

Set `rox-central-endpoint` in the `PipelineRun` to your RHACS Central endpoint. The pipeline runs:

```sh
roxctl image check -c Custom --image <built-image>
```

If the RHACS policy check fails, `roxctl` exits non-zero and the pipeline fails.
