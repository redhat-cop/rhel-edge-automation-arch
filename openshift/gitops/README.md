# GitOps

The contents of this directory makes use of GitOps principles to configure an OpenShift cluster and associated resources.

## Argo CD Deployment

[Argo CD](https://argoproj.github.io/argo-cd/) is the GitOps tool for this implementation and is delivered through Red Hat GitOps.

Deploy Red Hat GitOps by executing the following command:

```
oc apply -k manifests/bootstrap/argocd-operator/base
```

Now, deploy Argo CD:

```
until oc apply -k manifests/bootstrap/argocd/base; do sleep 2; done

```

## Bootstrap GitOps

### Prerequisites

Sealed Secrets are deployed as part of the GitOps automation. Currently, this requires a public/private keypair to have been previously created and placed within a secret called `sealed-secrets-custom-key`. 

Place this secret into a file located at `environments/overlays/bootstrap/sealed-secrets-secret.yaml`

### Execute the Bootstrap

Bootstrap the environment by executing the following command:

```
kustomize build clusters/overlays/shared/argocd/manager | oc apply -f-
```

## Accessing Argo CD

You can locate the URL exposed by Argo CD by executing the following:

```
oc get routes -n openshift-gitops argocd-cluster-server -o jsonpath=https://'{.spec.host}'
```

Login with your OpenShift credentials.