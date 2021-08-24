# Basic Walkthrough

This guide will help familiarize yourself with the process of building your first RHEL for Edge image using this architecture. By the end of this walk-through, you will:

* Understand the primary components in the architecture
* Build a RHEL for Edge image from a Blueprint
* Publish a Kickstart file referencing the previously built RHEL for Edge image

## Prerequisites

The following requirements must be satisfied prior to beginning the walk-through:

1. OpenShift CLI Tool
2. Tekton CLI Tool
3. curl CLI Tool
4. An OpenShift cluster provisioned with the tooling associated in this repository
5. Access to the OpenShift cluster as a user with `cluster-admin` privileges.

## Use Case Overview

This walk-through will illustrate the ease of building, publishing and consuming RHEL for Edge content. For the sample use case, an edge node with the [IBM Developer Model Asset Exchange: Weather Forecaster](https://github.com/IBM/MAX-Weather-Forecaster) application running in a container will be built and deployed. This process consists of the following:

* Execute a series of pipelines that:
  + Use Image Builder to create a custom RHEL for Edge image (OSTree commit) using compose image type `rhel-edge-container`
  + Push generated OCI container to Quay
  + Deploy OCI container on OpenShift for staging
  + Synchronize OStree content from web server running on OpenShift for production promotion
* Creating a Kickstart file with the configuration to run the container workload
* Generate auto-booting RHEL for Edge installer ISO with embedded OSTree commit and Kickstart

## Building a RHEL for Edge Image

The process of building a RHEL for edge image involves composing a Blueprint containing a list of packages, entry modules for packages, as well as any customizations to the resulting image. The architecture includes a Tekton pipeline with the purpose of building an RHEL for Edge image from an existing blueprint. Sample blueprints are found on the [blueprints](https://github.com/redhat-cop/rhel-edge-automation-arch/tree/blueprints) branch of this repository.

For the most basic configurations, a sample [hello-world](https://github.com/redhat-cop/rhel-edge-automation-arch/tree/blueprints/hello-world) blueprint is available and provides the necessary configuration to run the containerized application.

All of the content for managing RHEL for Edge applications are located in the `rfe` namespace within the OpenShift cluster.

Log in to the OpenShift CLI and change into the `rfe` namespace:

```shell
oc project rfe
```

The `rfe-oci-image-pipeline` Tekton pipeline is responsible for building new RHEL for Edge images and storing the resulting OCI container with the OSTree Commit in Quay.

From the root of the project, execute the following command to execute the `rfe-oci-image-pipeline` pipeline to build the `hello-world` blueprint:

```shell
tkn pipeline start rfe-oci-image-pipeline \
--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml \
-s rfe-automation \
--use-param-defaults \
-p blueprint-dir=hello-world 
```

To break down the preceding command:

* `tkn` - Tekton CLI
* `pipeline` - Resource to manage.
* `start` - Action to perform. Starts a pipeline run.
* `--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml` - Specifies that a PersistentVolumeClaim should be used to back the Tekton workspace using a template found in the file [openshift/resources/pipelines/volumeclaimtemplate.yaml](https://github.com/redhat-cop/rhel-edge-automation-arch/blob/main/openshift/resources/pipelines/volumeclaimtemplate.yaml).
* `-s rfe-automation` - The name of the Service Account used to run the pipeline.
* `--use-param-default` - The default Pipeline parameters will be applied unless explicitly specified.
* `-p blueprint-dir=hello-world` - The directory containing the blueprint file in the cloned repository. By default, the _blueprints_ branch of this repository will be used.

The output of the command will provide a command to view the progress of the build.

_Note: The process of building a RHEL for Edge image takes time!_

### Pipeline Results

Each pipeline run returns three results:

* `build-commit` - The Build Commit ID from Image Builder
* `image-path` - Location in Quay registry of OCI container
* `image-tags` - Tags applied to the container (JSON list)

To view the results, find the latest pipeline run. Use the following command as an example:

```shell
$ tkn pipelinerun list -n rfe --label tekton.dev/pipeline=rfe-oci-image-pipeline --limit 1
NAME                               STARTED     DURATION     STATUS
rfe-oci-image-pipeline-run-2lpwc   1 day ago   13 minutes   Succeeded
```

Then run the following to view the pipeline results:

```shell
$ oc get pipelinerun -n rfe rfe-oci-image-pipeline-run-2lpwc -ojsonpath='{.status.pipelineResults}'
[
  {
    "name": "build-commit",
    "value": "ab07f144-43a7-49b3-93de-99e1562435f9"
  },
  {
    "name": "image-path",
    "value": "quay-quay-quay.apps.cluster.com/rfe/hello-world"
  },
  {
    "name": "image-tags",
    "value": "[\"latest\", \"0.0.1\"]"
  }
]
```

### Verification

Once the pipeline completes, the OCI container generated by Image Builder should be stored in Quay. To verify, obtain the route to Quay by running the following command:

```shell
oc get quayregistry quay -n quay -ojsonpath='{.status.registryEndpoint}'
```

Quay is not setup to use external authentication, so the username can be found by running:

```shell
oc get secret quay-rfe-setup -n rfe -o go-template='{{ .data.username | base64decode }}'
```

And the password by running:

```shell
oc get secret quay-rfe-setup -n rfe -o go-template='{{ .data.password | base64decode }}'
```

Once logged in to Quay, click on the RFE organization to the right of the page under _Users and Organizations_ and then select the repository name associated with your blueprint.

To the left of the screen, click the _Tags_ icon to view associated tags. Each pipeline run will create two tags:

* A _latest_ tag that points to the most recent image.
* A tag with the version specified in the blueprint.

At this point, you could manually pull/deploy the container for use in the deployment of RFE content.

## Staging OCI Container with OSTree Commit

Now that we have our OCI container from Image Builder with our OSTree Commit in Quay, we can run a pipeline to deploy it as a staging environment in OpenShift.

From the root of the project, execute the following command to execute the `rfe-oci-stage-pipeline` pipeline to deploy the OCI container built in the previous pipeline (`rfe-oci-image-pipeline`) run.

```shell
tkn pipeline start rfe-oci-stage-pipeline \
--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml \
-s rfe-automation \
--use-param-defaults \
-p image-path=$(oc get route -n quay quay-quay -ojsonpath='{.spec.host}')/rfe/hello-world \
-p image-tag=latest
```

This command is similar to the previous pipeline run, but the following parameters are used:

* `-p image-path=quay-quay-quay.apps.cluster.com/rfe/hello-world` - The path to the OCI container stored in the Quay registry.
* `-p image-tag=latest` - Use the image with the tag _latest_.

### Pipeline Results

Each pipeline run returns one result:

* `content-path` - The path to the OSTree repository.

To view the results, find the latest pipeline run. Use the following command as an example:

```shell
$ tkn pipelinerun list -n rfe --label tekton.dev/pipeline=rfe-oci-stage-pipeline --limit 1
NAME                               STARTED     DURATION     STATUS
rfe-oci-stage-pipeline-run-cxkxq   1 day ago   13 minutes   Succeeded
```

Then run the following to view the pipeline results:

```shell
$ oc get pipelinerun -n rfe rfe-oci-stage-pipeline-run-cxkxq -ojsonpath='{.status.pipelineResults}'
[
  {
    "name": "content-path",
    "value": "http://hello-world-latest-rfe.apps.cluster.com/repo"
  }
]
```

### Verification

Once the pipeline runs, an ImageStream, Deployment, Service and Route are configured in the `rfe` namespace. To verify the deployment, we can query the hash of the OSTree Commit. Run `curl` using the `content-path` result in the previous `rfe-oci-stage-pipeline` pipeline run and append "/refs/heads/rhel/8/x86_64/edge". For example:

```
$ curl http://hello-world-latest-rfe.apps.cluster.com/repo/refs/heads/rhel/8/x86_64/edge
ed9e194df0c2f70c49942c00696edbdcd86f7c06e1b930c2ed3cb0a0a99a87c5
```

## Moving from Stage to Production

The next stage involves synchronizing our OSTree Commit from our staging environment to production.

From the root of the project, execute the following command to execute the `rfe-oci-publish-content-pipeline` pipeline:

```shell
tkn pipeline start rfe-oci-publish-content-pipeline \
--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml \
-s rfe-automation \
--use-param-defaults \
-p image-path=$(oc get route -n quay quay-quay -ojsonpath='{.spec.host}')/rfe/hello-world \
-p image-tag=latest 
```

This command is similar to the previous pipeline run, but the following parameters are used:

* `-p image-path=quay-quay-quay.apps.cluster.com/rfe/hello-world` - The path to the OCI container stored in the Quay registry.
* `-p image-tag=latest` - Use the image with the tag _latest_.

### Pipeline Results

Each pipeline run returns one result:

* `content-path` - The path to the OSTree repository.

To view the results, find the latest pipeline run. Use the following command as an example:

```shell
$ tkn pipelinerun list -n rfe --label tekton.dev/pipeline=rfe-oci-publish-content-pipeline --limit 1
NAME                                         STARTED     DURATION   STATUS
rfe-oci-publish-content-pipeline-run-ptrpx   1 day ago   1 minute   Succeeded
```

Then run the following to view the pipeline results:

```shell
$ oc get pipelinerun -n rfe rfe-oci-publish-content-pipeline-run-ptrpx -ojsonpath='{.status.pipelineResults}'
[
  {
    "name": "content-path",
    "value": "http://httpd-rfe.apps.cluster.com/hello-world/latest"
  }
]
```

### Verification

Once the pipeline executes, the OSTree Commit is synchronized to the production webserver. Verify the hash by running the following command:

Run `curl` using the `content-path` result in the previous `rfe-oci-publish-content-pipeline` pipeline run and append "/refs/heads/rhel/8/x86_64/edge". For example:

```shell
$ curl http://httpd-rfe.apps.cluster.com/hello-world/latest/refs/heads/rhel/8/x86_64/edge
ed9e194df0c2f70c49942c00696edbdcd86f7c06e1b930c2ed3cb0a0a99a87c5
```

The hash for this repository should now match the hash from the repository generated during the `rfe-oci-stage-pipeline` pipeline run.

## Creating the Kickstart File

A Tekton pipeline called `rfe-kickstart-pipeline` is responsible for publishing a Kickstart file to both Nexus and the HTTPD server. As the pipeline uses Ansible, Jinja based templating is available to inject key values (in particular, the location of the OSTree repository).

Using the location of the OSTree repository from the results of either the `rfe-oci-stage-pipeline` or `rfe-oci-publish-content-pipeline` pipelines, execute the following command:

```shell
tkn pipeline start rfe-kickstart-pipeline \
-s rfe-automation \
--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml \
--use-param-defaults \
-p kickstart-path=ibm-weather-forecaster/kickstart.ks \
-p ostree-repo-url=http://httpd-rfe.apps.cluster.com/hello-world/latest
```

This command is similar to the previous pipeline run, but the following parameters are used:

To break down the preceding command:

* `-p kickstart-path=ibm-weather-forecaster/kickstart.ks` - The location of the kickstart to use in the referenced repository. By default, the _kickstarts_ branch of this repository will be used.
* `-p ostree-repo-url=http://httpd-rfe.apps.cluster.com/hello-world/latest` - The location of the OSTree repository.

The output of the `tkn pipeline` command will provide another command to view the progress of the build.

### Pipeline Results

Each pipeline run returns two results:

* `artifact-repository-storage-url` - The location of the kickstart on the Nexus server.
* `serving-storage-url` - The location of the kickstart on the HTTPD server.

To view the results, find the latest pipeline run. Use the following command as an example:

```shell
$ tkn pipelinerun list -n rfe --label tekton.dev/pipeline=rfe-kickstart-pipeline --limit 1
NAME                               STARTED          DURATION   STATUS
rfe-kickstart-pipeline-run-kqp5n   18 minutes ago   1 minute   Succeeded
```

Then run the following to view the pipeline results:

```shell
$ oc get pipelinerun rfe-kickstart-pipeline-run-kqp5n -ojsonpath='{.status.pipelineResults}'
[
  {
    "name": "artifact-repository-storage-url",
    "value": "https://nexus-rfe.apps.cluster.com/repository/rfe-kickstarts/ibm-weather-forecaster/kickstart.ks"
  },
  {
    "name": "serving-storage-url",
    "value": "https://httpd-rfe.apps.cluster.com/kickstarts/ibm-weather-forecaster/kickstart.ks"
  }
]
```

### Verification

To verify, simply pull the kickstart files using the URLs defined in the `artifact-repository-storage-url` and `serving-storage-url` pipeline results.

## Creating Auto Booting RFE Installer

One of the new features in Image Builder 8.4 is the ability to compose (using `image-type` `rhel-edge-installer`) installation media that has an OSTree commit embedded in the installer. The pipeline in this project goes a step further and embeds a kickstart file in the generated ISO and reconfigures `EFI/BOOT/grub.cfg`/`isolinux/isolinux.cfg` to automatically install RFE using the embedded kickstart.

From the root of the project, execute the following command to execute the `rfe-oci-iso-pipeline` pipeline:

```shell
tkn pipeline start rfe-oci-iso-pipeline \
--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml \
-s rfe-automation \
--use-param-defaults \
-p kickstart-url=https://httpd-rfe.apps.cluster.com/kickstarts/ibm-weather-forecaster/kickstart.ks \
-p ostree-repo-url=http://hello-world-latest-rfe.apps.cluster.com/repo
```

This command is similar to the previous pipeline run, but the following parameters are used:

* `-p kickstart-url=https://httpd-rfe.apps.cluster.com/kickstarts/ibm-weather-forecaster/kickstart.ks` - The path to the kickstart to be embedded in the ISO.
* `-p ostree-repo-url=http://hello-world-latest-rfe.apps.cluster.com/repo` - The path to the OSTree repository that will be embedded in the ISO.

### Important Information Regarding Kickstarts

If you are providing your own kickstart file, the following line for the `ostreesetup` command should be used (notice `--url` is pointing to the OSTree repo embedded in the installer, but it can point to any OSTree repository):

```shell
ostreesetup --nogpg --url=file:///ostree/repo/ --osname=rhel --remote=edge --ref=rhel/8/x86_64/edge
```

Like traditional RHEL installations, Anaconda is used to install RHEL for Edge. However, not all Anaconda modules are enabled. The following modules are available:

* org.fedoraproject.Anaconda.Modules.Network
* org.fedoraproject.Anaconda.Modules.Payloads
* org.fedoraproject.Anaconda.Modules.Storage

Common tasks like creating a user via the kickstart will not work. These actions should be included in the blueprint file used to build the OSTree commit. However, other tasks like `%post` should still work.

### Pipeline Results

Each pipeline run returns two results:

* `build-commit-id` - The Build Commit ID from Image Builder
* `iso-url` - The location of the autobooting ISO

To view the results, find the latest pipeline run. Use the following command as an example:

```shell
$ tkn pipelinerun list -n rfe --label tekton.dev/pipeline=rfe-oci-iso-pipeline --limit 1
NAME                             STARTED      DURATION     STATUS
rfe-oci-iso-pipeline-run-2lpwc   3 days ago   13 minutes   Succeeded
```

Then run the following to view the pipeline results:

```shell
$ oc get pipelinerun -n rfe rfe-oci-iso-pipeline-run-2lpwc -ojsonpath='{.status.pipelineResults}'
[
  {
    "name": "build-commit-id",
    "value": "2cbce183-4a18-4e47-97bd-47e983b5652c"
  },
  {
    "name": "iso-url",
    "value": "https://httpd-rfe.apps.cluster.com/2cbce183-4a18-4e47-97bd-47e983b5652c-auto.iso"
  }
]
```

### Verification

To verify, simply pull the ISO using the URL defined in the `iso-url` pipeline result.

## Creating a RHEL for Edge Node

### Using Auto Booting ISO

The auto booting ISO is self contained and configured to automatically install the RHEL for Edge not w/o user input. Simply boot off the ISO to install.

### Manually Using Kickstart File

Now that the the Kickstart and OSTree repository are setup, create a new RHEL for Edge Node by booting a new machine using the RHEL 8 boot image.

At the boot menu, hit the tab key and add the following to the list of boot arguments:

```shell
inst.ks=<URL_OF_KICKSTART_FILE>
```

Hit enter to boot the machine using the Kickstart. The machine will retrieve the OSTree content and prepare the machine to run the sample application. Once complete, the machine will reboot

### Verify the Application

Once the machine has been rebooted, login as the user created as part of the node installation.

_Note: By default, this example specifies the following `core` as the user and `edge` as the password._

Once logged in, confirm the application container is running:

```shell
sudo podman ps
```

Finally, confirm that the application Swagger endpoint responds to requests:

```shell
curl localhost:5000
```

Additional details on interacting with the application can be found in the [project repository](https://github.com/IBM/MAX-Weather-Forecaster)

You have now successfully completed the walkthrough!

