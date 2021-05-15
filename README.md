# RHEL for Edge Automation Architecture

## Introduction

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

All of the Above Site components (see [architecture](#architecture)) will be deployed on OpenShift. Most of these components will be deployed/configured by tools like [Argo CD](https://argoproj.github.io/argo-cd/).
We also chose to use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to support our GitOps workflow. We leverage an "app of apps" methodology to deploy all of the components and two overlays are provided. The `shared` overylay is used to provision a shared development environment, but most users will want to leverage the `byo` overlay.

### Deploying BYO Overlay

To deploy the above site components we first need to deploy Argo CD. Argo CD is installed using the GitOps operator in OpenShift. If Argo CD is already installed, you can skip to the next [section](#bootstrapping-environment)

#### Argo CD

From the root of the repository, run the following command to install the operator:

```shell
oc apply -k openshift/gitops/manifests/bootstrap/argocd-operator/base
```

Then run the following to deploy an instance of Argo CD.

```shell
until oc apply -k openshift/gitops/manifests/bootstrap/argocd/base; do sleep 2; done
```

#### Bootstrapping Environment

Some secrets will need to be created to support the deployment. We will use the Kustomize Secrets Generator to source specific values from files. An SSH key will be needed as well as credentials for the Red Hat Portal. A table of the specific components are laid out below:

| Component                    | Description                                                             |
|:-----------------------------|:------------------------------------------------------------------------|
| SSH Key                      | Use to support key based authentication to the Image Builder VM         |
| Red Hat Portal Username      | Username to subscribe Image Builder VM                                  |
| Red Hat Portal Password      | Password to subscribe Image Builder VM                                  |
| Pool ID                      | Pool ID use to map the appropriate subscription to the Image Builder VM |
| Red Hat Portal Offline Token | Token used to access the Red Hat API and download RHEL images           |

To generate an SSH key, run the following command:

```shell
ssh-keygen -t rsa -b 4096 -C cloud-user@image-builder -f ~/.ssh/image-builder
```

Create symlinks to key you just created into the project:

```shell
ln -s ~/.ssh/image-builder openshift/gitops/clusters/overlays/byo/bootstrap/image-builder-ssh-private-key
ln -s ~/.ssh/image-builder.pub openshift/gitops/clusters/overlays/byo/bootstrap/image-builder-ssh-public-key
```

Next, modify `openshift/gitops/clusters/overlays/byo/bootstrap/redhat-portal-credentials` and add the Red Hat Portal Username, Password, Pool ID and Offline Token to the appropriate variables. More information about generating an Offline Token can be found [here](https://access.redhat.com/articles/3626371).

We are now ready to bootstrap the environment. To do this, run:

```shell
kustomize build --load_restrictor=LoadRestrictionsNone openshift/gitops/clusters/overlays/byo/bootstrap/ | oc apply -f -
```

#### Deploying

Finally, deploy all of the above site components by running the following:

```shell
kustomize build openshift/gitops/clusters/overlays/byo/argocd/manager | oc apply -f -
```

## Basic Walkthrough

A basic workthrough to demonstrate the end to end flow of building RHEL for Edge content and using it to create a RHEL for Edge instance can be found below:

* [Basic Walkthrough](docs/basic-walkthrough.md)
