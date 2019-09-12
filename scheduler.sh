#!/bin/bash
set -euo pipefail

get_pending_pods() {
    scheduler=$1
    kubectl get pods -ojson \
        --field-selector="status.phase=Pending,spec.schedulerName=$scheduler" |
        jq --compact-output '.items[]'
}

get_node() {
    # TODO Choose node with care
    kubectl get node -ojson | jq -r '.items | first | .metadata.name'
}

bind_pod() {
    node=$1
    namespace=$2
    name=$3
    kubectl create \
        --raw "/api/v1/namespaces/${namespace}/pods/${name}/binding" -f - <<EOF
{
  "apiVersion": "v1",
  "kind": "Binding",
  "metadata": {
    "name": "$name"
  },
  "target": {
    "apiVersion": "v1",
    "kind": "Node",
    "name": "$node"
  }
}
EOF
}

schedule_pod() {
    pod=$1
    namespace=$(jq -r '.metadata.namespace' <<<"$pod")
    name=$(jq -r '.metadata.name' <<<"$pod")
    node="$(get_node)"
    bind_pod "$node" "$namespace" "$pod"
}

main() {
    while true; do
        get_pending_pods "my-scheduler" | while read -r pod; do
            schedule_pod "$pod"
        done
        sleep 10
    done
}

main
