#!/bin/bash
set -euo pipefail

SCHEDULER_NAME="my-scheduler"
SLEEP_INTERVAL="2"

main() {
    echo "Scheduling pods as $SCHEDULER_NAME every $SLEEP_INTERVAL seconds."
    while true; do
        get_pending_pods | while read -r pod; do
            schedule_pod "$pod"
        done
        sleep "$SLEEP_INTERVAL"
    done
}

get_pending_pods() {
    kubectl get pods --output=json \
        --field-selector="status.phase=Pending,spec.schedulerName=$SCHEDULER_NAME" |
        jq --compact-output '.items[]'
}

schedule_pod() {
    local pod=$1
    local pod_name
    pod_name=$(jq -r '.metadata.name' <<<"$pod")
    # Don't schedule if it has a node assigned.
    if [ "$(jq -r '.spec.nodeName == null' <<<"$pod")" == "false" ]; then
        return
    fi
    local node
    node="$(get_node "$pod")"
    bind_pod "$node" "$pod"
    echo "Scheduled: $pod_name on $node"
}

get_node() {
    local pod=$1
    # TODO Choose node with care
    kubectl get nodes --output=json |
        jq -r '.items[].metadata.name' |
        head -n1
}

bind_pod() {
    local node=$1
    local pod=$2
    local namespace
    namespace=$(jq -r '.metadata.namespace' <<<"$pod")
    local name
    name=$(jq -r '.metadata.name' <<<"$pod")
    kubectl create \
        --raw "/api/v1/namespaces/${namespace}/pods/${name}/binding" \
        -f - >/dev/null <<EOF
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
