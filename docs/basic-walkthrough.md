# Basic Walkthrough

This guide will help familiarize yourself with the process of building your first RHEL for Edge image using this architecture. By the end of this walkthrough, you will

* Understand the primary components in the architecture
* Build a RHEL for Edge Image from a Blueprint
* Publish a Kickstart file referencing the previously built RHEL for Edge Image

## Prerequisites

The following requirements must be satisfied prior to beginning the walkthrough:

1. OpenShift Command Line tool
2. Tekton Command Line Tool
3. An OpenShift cluster provisioned with the tooling associated in this repository
3. Access to the OpenShift Cluster as a user with `cluster-admin` access.

## Use Case Overview

This walkthrough will illustrate the ease of building, publishing and consuming RHEL for Edge content. For the sample use case, an edge node with the [IBM Developer Model Asset Exchange: Weather Forecaster](https://github.com/IBM/MAX-Weather-Forecaster) application running in a container will be built and deployed. This process consists of the following

* Building a RHEL for Edge node
* Creating a Kickstart file referencing the previously built RHEL for Edge Image with the configuration to run the container workload

## Building a RHEL for Edge Image

The process of building a RHEL for edge image involves composing a Blueprint containing list of packages to include, entry modules for packages, as well as any customizations to the resulting image. The architecture includes a Tekton pipeline with the purpose of building an RHEL for Edge Image from an existing blueprint. Sample blueprints are found on the [blueprints](https://github.com/redhat-cop/rhel-edge-automation-arch/tree/blueprints) branch of this repository.

For the most basic configurations, a sample [hello-world](https://github.com/redhat-cop/rhel-edge-automation-arch/tree/blueprints/hello-world) blueprint is available and provides necessary configuration to run the containerized application.

All of the content for managing RHEL for Edge applications are located in the `rfe` namespace within the OpenShift cluster.

Log in to the OpenShift CLI and change into the `rfe` namespace:

```shell
oc project rfe
```

The `rfe-tarball-pipeline` Tekton pipeline is responsible for building new RHEL for Edge images, storing the resulting .tar file in Nexus and uploading the contents to the HTTPD server.

From the root of the project, execute the following command to instantiate the `rfe-tarball-pipeline` to build the `hello-world` blueprint:

```shell
tkn pipeline start rfe-tarball-pipeline --workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml --use-param-defaults -p blueprint-dir=hello-world -s rfe-automation
```

To break down the preceding command:

1. `tkn` - Tekton CLI
2. `pipeline` - Resource to manage
3. `start` - Action to perform. Starts a pipeline
4. `--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml` - Specifies that a PersistentVolumeClaim should be used to back the Tekton workspace using a template found in the file [https://github.com/redhat-cop/rhel-edge-automation-arch/blob/main/openshift/resources/pipelines/volumeclaimtemplate.yaml](openshift/resources/pipelines/volumeclaimtemplate.yaml).
5. `--use-param-default` - The default Pipeline parameters will be applied unless explicitly specified
6. `-p blueprint-dir=hello-world` - The directory containing the blueprint file in the cloned repository. By default, the _blueprints_ branch of this repository will be used
7. `-s rfe-automation` - THe name of the Service Account to run the pipeline as

The output of the command will provide a command to view the progress of the build.

_Note: The process of building a RHEL for Edge image takes time_

### Verification

Once the pipeline completes, the assets can then be verified in both Nexus and HTTPD.

First, obtain the URL of the Nexus Route and login with your OpenShift credentials

```shell
oc get routes -n rfe nexus -o jsonpath=http://'{ .spec.host }'
```

Once logged in, select the *Browse* button on the left hand navigation bar and then select the *rfe-tarballs* repository.

The list of uploaded tarballs will be displayed.

To verify the extracted contents of the RHEL for Edge tarball in the HTTPD server, first execute the following command to obtain a remote shell session on the server:

```shell
oc rsh -n rfe $(oc get pods -l=deployment=httpd -o jsonpath='{.items[0].metadata.name }')
```

List all of the tarballs in the HTTPD server and then exit the remote session

```shell
ls -l /opt/rh/httpd24/root/var/www/html/tarballs
exit
```

The PipelineRun resource also provides the externally facing location for these assets in both Nexus and HTTPD as execution results. The most important resource, which will be needed in the subsequent section is the location of the extracted RHEL for Edge image in HTTPD. This can be extracted by executing the following command:

```shell
oc get pipelinerun $(oc get pipelinerun -l=tekton.dev/pipeline=rfe-tarball-pipeline --sort-by=".status.completionTime" -o jsonpath='{ .items[-1].metadata.name }') -o jsonpath='{ .status.pipelineResults[?(@.name=="serving-storage-url")].value }'
```

## Creating the Kickstart File

A Tekton pipeline similar to the `rfe-tarball-pipeline` pipeline called `rfe-kickstart-pipeline` is responsible for publishing a Kickstart file to both Nexus and the HTTPD server. As the pipeline uses Ansible, Jinja based templating is available to inject key values (in particular, the location of the extracted rpm-ostree tarball in the HTTPD server).

Using the location of the extracted RHEL for Edge image produced by the pipeline in the previous section, execute the following command from the root of the repository to start the `rfe-kickstart-pipeline` pipeline.

```shell
tkn pipeline start rfe-kickstart-pipeline --workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml --use-param-defaults -p kickstart-path=ibm-weather-forecaster/kickstart.ks -s rfe-automation -p rfe-tarball-url=$(oc get pipelinerun $(oc get pipelinerun -l=tekton.dev/pipeline=rfe-tarball-pipeline --sort-by=".status.completionTime" -o jsonpath='{ .items[-1].metadata.name }') -o jsonpath='{ .status.pipelineResults[?(@.name=="serving-storage-url")].value }')
```

To break down the preceding command:

1. `tkn` - Tekton CLI
2. `pipeline` - Resource to manage
3. `start` - Action to perform. Starts a pipeline
4. `--workspace name=shared-workspace,volumeClaimTemplateFile=openshift/resources/pipelines/volumeclaimtemplate.yaml` - Specifies that a PersistentVolumeClaim should be used to back the Tekton workspace using a template found in the file [openshift/resources/pipelines/volumeclaimtemplate.yaml](openshift/resources/pipelines/volumeclaimtemplate.yaml).
5. `--use-param-default` - The default Pipeline parameters will be applied unless explicitly specified
6. `-p ibm-weather-forecaster/kickstart.ks` - The location of the kickstart to use in the referenced repository. By default, the _kickstarts_ branch of this repository will be used
7. `-s rfe-automation` - THe name of the Service Account to run the pipeline as
8. `rfe-tarball-url=<URL_FROM_PRIOR_PIPELINE>` - The location of the kickstart to use in the referenced repository. By default, the _kickstarts_ branch of this repository will be used

The output of the command will provide a command to view the progress of the build.

### Verification

Once the pipeline completes, the assets can then be verified in both Nexus and HTTPD.

First, obtain the URL of the Nexus Route and login with your OpenShift credentials

```shell
oc get routes -n rfe nexus -o jsonpath=http://'{ .spec.host }'
```

Once logged in, select the *Browse* button on the left hand navigation bar and then select the *rfe-kickstarts* repository.

The list of uploaded kickstarts separated by directory will be displayed.

To verify the kickstart in the HTTPD server, first execute the following command to obtain a remote shell session on the server:

```shell
oc rsh -n rfe $(oc get pods -l=deployment=httpd -o jsonpath='{.items[0].metadata.name }')
```

Display the content of the kickstart file

```shell
cat /opt/rh/httpd24/root/var/www/html/kickstarts/ibm-weather-forecaster/kickstart.ks
exit
```

The PipelineRun resource also provides the externally facing location for these assets in both Nexus and HTTPD as execution results. The most important resource in this section is the location of the uploaded kickstart file which can be found by executing the following command:

```shell
oc get pipelinerun $(oc get pipelinerun -l=tekton.dev/pipeline=rfe-kickstart-pipeline --sort-by=".status.completionTime" -o jsonpath='{ .items[-1].metadata.name }') -o jsonpath='{ .status.pipelineResults[?(@.name=="serving-storage-url")].value }'
```

## Creating a RHEL for Edge Node

Now that the the Kickstart and the contents of the rpm-ostree tarball are available in the HTTPD server, create a new RHEL for Edge Node by booting a new machine using the RHEL 8 boot image.

At the boot menu, hit the tab key and add the following to the list of boot arguments:

```shell
inst.ks=<URL_OF_KICKSTART_FILE>
```

Hit enter to boot the machine using the Kickstart. The machine will retrieve the rpm-ostree content and prepare the machine to run the sample application. Once complete, the machine will reboot

### Verify the application

Once the machine has been rebooted, login as the user created as part of the node installation.

_Note: By default, this example specifies the following `core` as the user and `edge` as the password.

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
