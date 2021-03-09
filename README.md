# Introduction

RHEL for Edge (RFE) introduces a new model for building and deploying RHEL. This repository (very much a work in progress) will contain necessary documentation and automation to support a GitOps approach to building and delivering RFE content at scale.

## Areas of Focus

Our design will focus on the following topics:

* Deployment of Image Builder
* Management of Blueprint Definitions
* Building RFE Images
* Managing/Hosting RFE Artifacts
  * Kickstarts
  * RFE Tarballs
* CI/CD Tooling/Process
* End to End Installation/Update of RFE Deployments
* Managing RFE Deployments at Scale
  * Aggregating Logging/Metrics Collection
  * Deploying Containerized Workloads

## Architecture

The overall architecture is still being defined. We have split out "Above Site" components (things like RFE build orchestration and CI/CD tooling) and "Below Site" (the actual RFE deployments). All Above Site components will be hosted on OpenShift.

![Overall Architecture](/images/overall-architecture.png)

## Deploying Above Site Components

All of the Above Site components (see [architecture](#architecture)) will be deployed on OpenShift. Most of these components will be deployed/configured by tools like [Argo CD](https://argoproj.github.io/argo-cd/) and [Resource Locker](https://github.com/redhat-cop/resource-locker-operator).
We also chose to use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to support our GitOps workflow.

### Creating an Ansible Service Account

We will need to create a Service Account so Ansible can interact with the cluster. Run the following command to do this:

```yaml
$ cat << EOF | oc create -f -
---
kind: ServiceAccount
apiVersion: v1
metadata:
  name: ansible-sa
  namespace: openshift-config
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ansible-sa-cluster-admin
  namespace: openshift-config
subjects:
  - kind: ServiceAccount
    name: ansible-sa
    namespace: openshift-config
roleRef:
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
  name: cluster-admin
EOF
```

The name of the service account is `ansible-sa` and it will be placed in the `openshift-config` namespace. A cluster role binding is also used to grant the service account the `cluster-admin` role.

### Deploying Sealed Secrets Controller

Ansible is used to deploy the Sealed Secrets controller on our Above Site OpenShift cluster. Before we start the installation we need to create our own RSA key pair. Some helper scripts are provided in `util/sealed-secrets` assist.
First modify the variables in `variables.sh` accordingly. The default values will result in the key pair being generated in your current working directory with the certificate set to expire in two years (i.e. 730 days).

```shell
$ ./generate-sealed-secrets.sh
Generating a RSA private key
..........++++
........................................++++
writing new private key to './tls.key'
-----
```

After running the `generate-sealed-secrets.sh` script, ensure the files `tls.key` and `tls.crt` are present. Next, create an Ansible vault and store base64 encoded contents of each file in the variables `sealed_secrets_keypair_crt` and `sealed_secrets_keypair_key`. Be sure to disable wrapping when encoding the files, for example:

```shell
base64 -w0 tls.key
```

### Additional Vault Variables

We need to provide the Ansible k8s module some additional variables. Add the following to your vault:

```yaml
openshift_api: https://api.cluster.local:6443
openshift_ansible_sa: ansible-sa
openshift_ansible_sa_token: eyJhbGciOiJSUzI...
```

You can find your API endpoint by running the `oc cluster-info` command. The token used to authenticate the service account is stored in a secret. To find the secret, run the following command:

```shell
$ oc get serviceaccount ansible-sa -n openshift-config -ojson | jq -r '.secrets[] | select(.name | contains("token")) | .name'
ansible-sa-token-qm66j
```

To extract the token from the secret, run the following:

```shell
oc get secret ansible-sa-token-qm66j -n openshift-config -ojson | jq -r .data.token | base64 -d
```

### Running Playbook

To deploy the Sealed Secrets controller, run the following:

```shell
ansible-playbook --ask-vault-pass -e @../local/vault.yaml deploy-sealed-secrets.yaml
```

Be sure to adjust the path to your `vault.yaml` accordingly.

[![Lint Code Base](https://github.com/redhat-cop/rhel-edge-automation-arch/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/redhat-cop/rhel-edge-automation-arch/actions)
