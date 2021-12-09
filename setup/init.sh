#!/bin/bash

SCRIPT_BASE_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Installs OpenShift GitOps and Deploys ArgoCD
echo "Deploying OpenShit GitOps..."
helm upgrade -i -n openshift-operators openshift-gitops "${SCRIPT_BASE_DIR}/../charts/operator" -f "${SCRIPT_BASE_DIR}/values-init.yaml" --dependency-update

echo "Waiting for OpenShift GitOps to Deploy..."
# Wait for ArgoCD Resource to become established
until kubectl wait crd/argocds.argoproj.io --for condition=established &>/dev/null; do sleep 5; done

echo "Creating RFE GitOps Namespace"
helm upgrade -i -n openshift-operators rfe-gitops-namespace "${SCRIPT_BASE_DIR}/../charts/namespaces" -f "${SCRIPT_BASE_DIR}/values-init.yaml" --dependency-update

echo "Deploying ArgoCD.."
helm upgrade -i -n rfe-gitops argocd "${SCRIPT_BASE_DIR}/../charts/argocd" --dependency-update