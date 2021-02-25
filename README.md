# Introduction

RHEL for Edge (RFE) introduces a new model for building and deploying RHEL. This repository (very much a work in progress) will contain necessary documentation and automation to support a GitOps approach to building and delivering RFE content at scale.

# Areas of Focus

Our design will focus on the following topics:

* Deployment of Image Builder
* Management of Blueprint Definitions
* Building RFE Images
* Managing/Hosting RFE Artifacts
	- Kickstarts
	- RFE Tarballs
* CI/CD Tooling/Process
* End to End Installation/Update of RFE Deployments
* Managing RFE Deployments at Scale
	- Aggregating Logging/Metrics Collection
	- Deploying Containerized Workloads

# Architecture

The overall architecture is still being defined. We have split out "Above Site" components (things like RFE build orchestration and CI/CD tooling) and "Below Site" (the actual RFE deployments). All Above Site components will be hosted on OpenShift.

![Above Site Architecture](/images/above-site-architecture.png)

# Deploying Above Site Components

All of the Above Site components (see [architecture](#architecture)) will be deployed on OpenShift. Most of these components will be deployed/configured by tools like [Argo CD](https://argoproj.github.io/argo-cd/). We also chose to use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to support secrets management in our GitOps automation.

## Argo CD

We will be using the Red Hat GitOps operator to provision Argo CD. To deploy the operator, run the following command from the root of the repository:

```
$ oc apply -k openshift/gitops/manifests/bootstrap/argocd-operator/base
```

Now we will deploy Argo CD using the GitOps operator:

```
$ until oc apply -k openshift/gitops/manifests/bootstrap/argocd/base; do sleep 2; done
```

## Bootstrapping Environment

Sealed Secrets are deployed as part of the GitOps automation. Several secrets will need to be encrypted before the GitOps automation is applied to the cluster.

### Creating RSA Keypair

First we will need to generate an RSA keypair to encrypted our secrets. To do this a helper script is provided.

First, move to the util/sealed-secrets directory. The helper scripts should be run in this directory only.

```
$ cd util/sealed-secrets
```

By default, our private key will be stored in `./tls.key` and `./tls.crt`. The certificate is also set to expire after two years. These settings can be modified in the `variables.sh` file.

To generate our RSA keypair, run the following:

```
$ ./generate-key-pair.sh
```

### Creating Keypair Secret

We will need to store this keypair in a `Secret` resource before deploying Sealed Secrets. Create a manifest for the secret using the following YAML as a template:

```yaml
apiVersion: v1
kind: Secret
metadata:
  labels:
    sealedsecrets.bitnami.com/sealed-secrets-key: active
  name: sealed-secrets-custom-key
  namespace: sealed-secrets
type: kubernetes.io/tls
data:
  tls.crt: LS0tLUtLS0tLQo=
  tls.key: LS0tLS1fe0tLQo=
```

The values of the keys should be the base64 encoded contents of the files we just created. For instance, the value of the `tls.crt` key should be the output of `base64 -w0 tls.crt`.

Once the manifest is finished, move the YAML file to `../../openshift/gitops/environments/overlays/bootstrap/sealed-secrets-secret.yaml`

### Creating a Sealed Secret for Image Builder SSH Private Key

The Tekton pipeline that handles the RFE builds will use Ansible to SSH into the Image Builder virtual machine. There is a helper script in the `util/sealed-secrets` directory to assist.

First, generate an SSH keypair. This can be done using as follows:

```
$ ssh-keygen -b 4096 -f ~/.ssh/image-builder -C cloud-user@cnv
```

Next we need to create a `Secret` to encrypt. First, make sure you are still in the `util/sealed-secrets` directory. Create a `Secret` with the name `image-builder-ssh-key.yaml` with the following format:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: image-builder-ssh-key
  namespace: rfe
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: LS0tLddw20tLQo=
```

The value for the `ssh-privatekey` key should be the base64 encoded contents of your SSH private key (i.e. `base64 -w0 ~/.ssh/image-builder`).

Next we need to encrypt the key. To do this we will use the provided helper script. To do this, run the following command:

```
./generate-sealed-secret.sh strict image-builder-ssh-key.yaml | yq -y > image-builder-ssh-key-sealed-secret.yaml
```

Finally, copy the file `image-builder-ssh-key-sealed-secret.yaml` to `../../openshift/gitops/manifests/rfe/image-builder-vm/base/image-builder-ssh-key-sealed-secret.yaml`

### Executing the Bootstrap

Now that all of our artifacts are in place we can bootstrap the environment. Run the following command from the root of the repository.

```
kustomize build openshift/gitops/clusters/overlays/rhpds/argocd/manager | oc apply -f-
```

## Accessing Argo CD

To watch Argo CD deploy the various manifests in real time, you can access it through the `Route` by running the following command:

```
oc get routes -n openshift-gitops argocd-cluster-server -o jsonpath=https://'{.spec.host}'
```

Login using your OpenShift credentials.