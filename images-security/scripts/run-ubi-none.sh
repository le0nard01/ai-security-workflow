#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/submit-pipelinerun.sh"
submit_pipeline_run ubi none
