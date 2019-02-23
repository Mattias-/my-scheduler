#!/bin/bash
set -euo pipefail

API_URL="https://$(minikube ip):8443/api/v1"
BINDING_PAYLOAD='{
  "apiVersion": "v1",
  "kind": "Binding",
  "metadata": {"name": "PODNAME"},
  "target": {"apiVersion": "v1", "kind": "Node", "name": "NODENAME"}
}'

get_pods() {
    scheduler=$1
    kubectl get pods -ojson \
        --field-selector="status.phase=Pending,spec.schedulerName=$scheduler" |
        jq -r '.items[].metadata | "\(.namespace) \(.name)"'
}

get_nodes() {
    kubectl get node -ojson |
        jq -r '.items[].metadata.name'
}

bind_pod() {
    node=$1
    namespace=$2
    name=$3
    echo "$BINDING_PAYLOAD" |
        jq ".metadata.name = \"$name\" | .target.name = \"$node\"" |
        curl -sk \
            -X POST \
            -H "Content-Type: application/json" \
            --cert "$HOME/.minikube/client.crt" \
            --key "$HOME/.minikube/client.key" \
            --url "${API_URL}/namespaces/${namespace}/pods/${name}/binding" \
            -d @-
}

schedule_pod() {
    namespace=$1
    pod=$2
    # TODO Choose node with care
    node=$(get_nodes | head -1)
    bind_pod "$node" "$namespace" "$pod"
}

while true; do
    get_pods "my-scheduler" | while read np; do
        echo "$np"
        schedule_pod $np
    done
    sleep 10
done
