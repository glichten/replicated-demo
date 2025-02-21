#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPLICATED_DIR="$( cd ${SCRIPT_DIR}/../ &> /dev/null && pwd )"
REPO_DIR="$( cd ${HELPERS_DIR}/../ &> /dev/null && pwd )"

kubectl create namespace umbrella
kubectl apply -f ${SCRIPT_DIR}/secrets.yaml -n umbrella

# Set variables
NEW_LABEL_KEY="nvidia.com/gpu.present"
NEW_LABEL_VALUE="true"
NEW_TAINT_KEY="nvidia.com/gpu"
NEW_TAINT_VALUE="present"
NEW_TAINT_EFFECT="NoSchedule"

# Get the list of nodes
NODES=$(kubectl get nodes -o json)

# Loop through each node
echo "${NODES}" | jq -c '.items[]' | while read -r NODE; do
  NODE_NAME=$(echo "${NODE}" | jq -r '.metadata.name')
  INSTANCE_TYPE=$(echo "${NODE}" | jq -r '.metadata.labels["node.kubernetes.io/instance-type"]')

  # Check if the node instance type contains "g4dn"
  if [[ "${INSTANCE_TYPE}" == *g4dn* ]]; then
    echo "Processing node: ${NODE_NAME} (Instance type: ${INSTANCE_TYPE})"

    # Add the label
    kubectl label node "${NODE_NAME}" "${NEW_LABEL_KEY}=${NEW_LABEL_VALUE}" --overwrite
    echo "Added label: ${NEW_LABEL_KEY}=${NEW_LABEL_VALUE} to node ${NODE_NAME}"

    # Add the taint
    kubectl taint nodes "${NODE_NAME}" "${NEW_TAINT_KEY}=${NEW_TAINT_VALUE}:${NEW_TAINT_EFFECT}" --overwrite
    echo "Added taint: ${NEW_TAINT_KEY}=${NEW_TAINT_VALUE}:${NEW_TAINT_EFFECT} to node ${NODE_NAME}"
  else
    echo "Skipping node: ${NODE_NAME} (Instance type: ${INSTANCE_TYPE})"
  fi
done

helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm upgrade -i nvdp nvdp/nvidia-device-plugin --namespace nvidia-device-plugin  --create-namespace  --version 0.17.0
