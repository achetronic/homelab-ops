#!/bin/sh
# Post-renderer for the upstream Temporal Helm chart.
#
# The chart (temporal-1.2.0) does not template a 'visibility:' section in its
# server ConfigMap, so there is no values knob for
# 'visibility.persistenceCustomSearchAttributes'. This script surgically
# appends that block to the 'temporal-config' ConfigMap rendered by Helm and
# leaves every other resource untouched.
#
# Wired in via 'postRenderer' on the temporal release in
# kubernetes/helmfile/kubernetes-01.yaml. Drop this file once the upstream
# chart exposes the knob natively.
# Tracking: https://github.com/temporalio/helm-charts/issues/<TBD>

set -eu

command -v yq >/dev/null 2>&1 || {
  echo "postrender.sh: yq (v4+) is required but not found in PATH" >&2
  exit 1
}

# Bump from the hard-coded default of 3 so Postiz can register its custom
# Text search attributes. Companion DDL for text04..text10 columns lives in
# the post-install Job under values.yaml's extraObjects.
export PATCH='
visibility:
  persistenceCustomSearchAttributes:
    Text: 10
'

yq eval '
  (
    select(.kind == "ConfigMap" and .metadata.name == "temporal-config")
    | .data["config_template.yaml"]
  ) |= . + strenv(PATCH)
' -
