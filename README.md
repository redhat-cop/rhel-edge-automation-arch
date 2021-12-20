# RHEL for Edge Automation Architecture

## Introduction

RHEL for Edge (RFE) introduces a new model for building and deploying RHEL. This repository contains necessary documentation and automation to support a GitOps approach to building and delivering RFE content at scale.

## Areas of Focus

Our design will focus on the following topics:

* Deployment of Image Builder
* Management of Blueprint Definitions
* Building RFE Images
* Managing/Hosting RFE Artifacts
  * Kickstarts
  * RFE OSTree Content
* CI/CD Tooling/Process
* End to End Installation/Update of RFE Deployments
* Managing RFE Deployments at Scale
  * Aggregating Logging/Metrics Collection
  * Deploying Containerized Workloads

## Architecture

The overall architecture is still being defined. We have split out "Above Site" components (things like RFE build orchestration and CI/CD tooling) and "Below Site" (the actual RFE deployments). All Above Site components will be hosted on OpenShift.

![Overall Architecture](/images/overall-architecture.png)

## Deploying Above Site Components

[Helm](https://helm.sh) and [Argo CD](https://argoproj.github.io/argo-cd/) are used to deploy and manage project components. Helm is used to dynamically generate an app of apps pattern in Argo CD, which in turn will pull in all the necessary Helm charts to deploy the specific components needed in the target environment.

Before beginning, make sure you have the latest versions of `oc`/`kubectl`, `git` and `helm` clients installed.

### Bootstrapping Environment

First clone the repository by running the following command:

```shell
git clone https://github.com/redhat-cop/rhel-edge-automation-arch.git
```

#### Prepare Values File & SSH Keypair

Several secrets are created during the deployment. We will need to provide values for those as part of the bootstrap process. A table of the specific components are laid out below:

| Component                    | Description                                                             |
|:-----------------------------|:------------------------------------------------------------------------|
| SSH Key                      | Use to support key based authentication to the Image Builder VM         |
| Red Hat Portal Username      | Username to subscribe Image Builder VM                                  |
| Red Hat Portal Password      | Password to subscribe Image Builder VM                                  |
| Pool ID                      | Pool ID use to map the appropriate subscription to the Image Builder VM |
| Red Hat Portal Offline Token | Token used to access the Red Hat API and download RHEL images           |

To generate the SSH keypair, run the following command:

```shell
ssh-keygen -t rsa -b 4096 -C cloud-user@image-builder -f ~/.ssh/image-builder
```

From the root of the repository, create symlinks to the key pair you just created:

```shell
ln -s ~/.ssh/image-builder charts/bootstrap/files/ssh/image-builder-ssh-private-key
ln -s ~/.ssh/image-builder.pub charts/bootstrap/files/ssh/image-builder-ssh-public-key
```

The rest of the values will be defined in a Helm values file. In the root of the repository, create a file called `local/bootstrap.yaml` and add the following:

```yaml
rhsm:
  portal:
    secretName: redhat-portal-credentials
    offlineToken: "Opij2qw3eCf890ujjwec8j..."
    password: "changeme"
    poolId: "ssa77eke7ahs0123djsdf92340p9okjd"
    username: "alice"

global:
  git:
    url: https://github.com/redhat-cop/rhel-edge-automation-arch.git
    ref: main
```

Be sure to change the values of `offlineToken`, `poolId`, `username`, and `password`. If you are not sure how to generate an offline token for the Red Hat API, it is documented [here](https://access.redhat.com/articles/3626371#bgenerating-a-new-offline-tokenb-3).

#### Deploy OpenShift GitOps Operator and Argo CD

Once the SSH keypair and values file are in place, we can begin to deploy. Run the following script to install the OpenShift GitOps Operator and Argo CD.

```shell
./setup/init.sh
```


### Deploying

Deploy the components using the following command:

```shell
helm upgrade -i -n rfe-gitops bootstrap charts/bootstrap/ -f local/bootstrap.yaml -f helm/examples/deploy-all.yaml
```

## Basic Walkthrough

A basic workthrough to demonstrate the end to end flow of building RHEL for Edge content and using it to create a RHEL for Edge instance can be found below:

* [Basic Walkthrough](docs/basic-walkthrough.md)
