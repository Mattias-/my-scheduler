#!/bin/bash
set -euo pipefail

SCHEDULER_NAME="my-scheduler"

main() {
    while true; do
        get_pending_pods | while read -r pod; do
            schedule_pod "$pod"
        done
        sleep 10
    done
}

get_pending_pods() {
    kubectl get pods --output=json \
        --field-selector="status.phase=Pending,spec.schedulerName=$SCHEDULER_NAME" |
        jq --compact-output '.items[]'
}

schedule_pod() {
    pod=$1
    node="$(get_node "$pod")"
    bind_pod "$node" "$pod"
}

get_node() {
    pod=$1
    # TODO Choose node with care
    kubectl get nodes --output=json |
        jq -r '.items[0].metadata.name'
}

bind_pod() {
    node=$1
    pod=$2
    namespace=$(jq -r '.metadata.namespace' <<<"$pod")
    name=$(jq -r '.metadata.name' <<<"$pod")
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

main
