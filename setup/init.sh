#!/bin/bash

SCRIPT_BASE_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Installs OpenShift GitOps and Deploys ArgoCD
echo "Deploying OpenShit GitOps..."
helm dependency update "${SCRIPT_BASE_DIR}/../charts/operator"
helm upgrade -i -n openshift-operators openshift-gitops "${SCRIPT_BASE_DIR}/../charts/operator" -f "${SCRIPT_BASE_DIR}/values-init.yaml"

echo "Waiting for OpenShift GitOps to Deploy..."
# Wait for ArgoCD Resource to become established
until kubectl wait crd/argocds.argoproj.io --for condition=established &>/dev/null; do sleep 5; done

echo "Creating RFE GitOps Namespace"
helm dependency update "${SCRIPT_BASE_DIR}/../charts/namespaces"
helm upgrade -i -n openshift-operators rfe-gitops-namespace "${SCRIPT_BASE_DIR}/../charts/namespaces" -f "${SCRIPT_BASE_DIR}/values-init.yaml"

echo "Deploying ArgoCD.."
helm dependency update "${SCRIPT_BASE_DIR}/../charts/argocd"
helm upgrade -i -n rfe-gitops argocd "${SCRIPT_BASE_DIR}/../charts/argocd"