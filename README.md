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

## Above Site Components

OpenShift is used to host all of the above site components. These components include:

* Helm/Argo CD for GitOps based deployment and configuration
* OpenShift Virtualization for RHEL Image Builder
* OpenShift Pipelines driving Ansible playbooks
* Nexus for artifact storage
* OpenShift Data Foundation (NooBaa only) for general object storage
* Red Hat Quay to host RFE OSTree content

## Deploying Above Site Components

[Helm](https://helm.sh) and [Argo CD](https://argoproj.github.io/argo-cd/) are used to deploy and manage project components. Helm is used to dynamically generate an app of apps pattern in Argo CD, which in turn will pull in all the necessary Helm charts to deploy the specific components needed in the target environment.

Before beginning, make sure you have the latest versions of `oc`/`kubectl`, `git`, `tkn` and `helm` clients installed. You will also need to generate SSH key pairs (example using `ssh-keygen` documented below).

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
| Pool ID                      | Red Hat Subscription Manager Pool ID use to map the appropriate subscription to the Image Builder VM |
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

The rest of the values will be defined in a Helm values file. In the root of the repository, create a file called `examples/values/local/bootstrap.yaml` and add the following:

```yaml
rhsm:
  portal:
    secretName: redhat-portal-credentials
    offlineToken: "Opij2qw3eCf890ujjwec8j..."
    password: "changeme"
    poolId: "ssa77eke7ahs0123djsdf92340p9okjd"
    username: "alice"
```

Be sure to change the values of `offlineToken`, `poolId`, `username`, and `password` to match the details for your account. If you are not sure how to generate an offline token for the Red Hat API, it is documented [here](https://access.redhat.com/articles/3626371#bgenerating-a-new-offline-tokenb-3).

#### Deploy OpenShift GitOps Operator and Argo CD

Once the SSH keypair and values file are in place, we can begin to deploy. Run the following script to install the OpenShift GitOps Operator and Argo CD.

```shell
./setup/init.sh
```


### Deploying

To deploy a reference environment in an empty OpenShift cluster, run the following command:

```shell
helm upgrade -i -n rfe-gitops bootstrap charts/bootstrap/ -f examples/values/local/bootstrap.yaml -f examples/values/deployment/default.yaml
```

The default installation will deploy and configure all of the managed components on the cluster. An HTPasswd identity provider is configured for 5 users (`user{1-5}`) with `openshift` as the password.

You can track the progress of the deployment on the Argo CD dashboard. To get the URL run the following command:

```shell
oc get route argocd-server -n rfe-gitops -ojsonpath='https://{.spec.host}'
```

The parent application is `rfe-automation`. To verify everything is deployed, `rfe-automation` should show Sycned/Healthy:

```shell
$ oc get application rfe-automation -n rfe-gitops
NAME             SYNC STATUS   HEALTH STATUS
rfe-automation   Synced        Healthy
```

### Customizing the Deployment

Helm and Argo CD are used to deploy and manage all of the project components. From a high level, a Helm chart called [application-manager](https://github.com/redhat-cop/rhel-edge-automation-arch/main/helm-migration/charts/application-manager) is used to dynamically build a nested app of apps pattern in Argo CD. Each application in Argo CD is a pointer to a Helm chart that installs and configures a specific project component. When bootstrapping the deployment, a Helm values file is used to tell the application manager which components should be deployed and how they should be configured. Using this pattern gives us a significant amount of flexibility when tailoring deployments to specific environments.

#### Disabling Components

If you want to disable the deployment/management of certain components (for example, if you want to bring your own cluster that has ODF already installed), set `disabled: true` in the chart's values file. For example, to disable ODF, create the following file in `examples/values/deployment/disable-odf.yaml`:

```yaml
# Dynamically Generated Charts
application-manager:
  charts:
    # Top Level RFE App of App Chart
    rfe-automation:
      values:
        charts:
          # Cluster Configuration App of App Chart
          cluster-configs:
            values:
              charts:
                # OpenShift Data Foundations
                odf:
                  disabled: true
 
                 # Operators App of App Chart
                operators:
                  values:
                    charts:
                      odf-operator:
                        disabled: true
```

Pass this values file to helm when deploying the project. For example:

```shell
helm upgrade -i -n rfe-gitops bootstrap charts/bootstrap/ -f examples/values/deployment/default.yaml -f examples/values/deployment/disable-odf.yaml
```

#### Customizing Components

Each chart in the `charts/` directory has a default values file. These values can be overwritten using the same pattern shown above in [Disabling Components](#disabling-components).

For example, to enable processor emulation for OpenShift Virtualization, set `useEmulation: true` in the chart's values file. Store the following file in `examples/values/local/cnv-processor-emulation.yaml`:

```yaml
---
# Dynamically Generated Charts
application-manager:
  charts:
    # Top Level RFE App of App Chart
    rfe-automation:
      values:
        charts:
          # Cluster Configuration App of App Chart
          cluster-configs:
            values:
              charts:
                # OpenShift Virtualization
                cnv:
                  values:
                    cnv:
                      debug:
                        useEmulation: "true"
```

Pass this values file to helm when deploying the project. For example:

```shell
helm upgrade -i -n rfe-gitops bootstrap charts/bootstrap/ -f examples/values/local/bootstrap.yaml -f examples/values/deployment/default.yaml -f examples/values/deployment/cnv-processor-emulation.yaml
```

#### Using Fedora as image-builder VM
It is also possible to use Fedora instead of RHEL as the image builder OS create your custom OS images. Simply use the yaml located in `examples/values/deployment/useFedora.yaml`:

```yaml
application-manager:
  charts:
    # Top Level RFE App of App Chart
    rfe-automation:
      values:
        charts:
          # RFE App of App Chart
          rfe:
            values:
              charts:
                # Image Builder VM
                image-builder-vm:
                  values:
                    osDistribution: fedora
```

## Basic Walkthrough

A basic walkthrough to demonstrate the end to end flow of building RHEL for Edge content and using it to create a RHEL for Edge instance can be found below:

* [Basic Walkthrough](docs/basic-walkthrough.md)
