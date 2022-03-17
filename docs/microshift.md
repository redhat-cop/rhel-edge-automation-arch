# MicroShift Example

Before using this guide, you should run through the [Basic Walkthrough](/docs/basic-walkthrough.md) to get familiar with the mechanics of building an RFE image using this project.

## Prerequisites

The following requirements must be satisfied prior to beginning the example:

1. OpenShift CLI Tool
2. Tekton CLI Tool
3. curl CLI Tool
4. jq CLI Tool
5. An OpenShift cluster provisioned with the tooling associated in this repository
6. Access to the OpenShift cluster as a user with `cluster-admin` privileges.

This build will use the MicroShift blueprint hosted in our repository in the `blueprints` branch [here](https://github.com/redhat-cop/rhel-edge-automation-arch/blob/blueprints/microshift/blueprint.toml). It has all of the packages required to run MicroShift as well as an initial user called `redhat` with the same password.

### Updating Default Password

For more secure installations, it is recommended you modify the blueprint and update the password hash. Using the following command to generate a new hash:

```shell
openssl passwd -6
```

Replace the hash in the `password` parameter of `customizations.user` with the hash generated above.

### Additional Content Sources

Create a file called `/tmp/microshift-additional-sources.json` with the following contents:

```json
{
  "sources": {
    "rhocp": {
      "id": "rhocp",
      "name": "rhocp",
      "type": "yum-baseurl",
      "url": "https://cdn.redhat.com/content/dist/layered/rhel8/x86_64/rhocp/4.8/os",
      "check_gpg": false,
      "check_ssl": true,
      "system": true,
      "rhsm": true
    },
    "microshift": {
      "id": "microshift",
      "name": "MicroShift",
      "type": "yum-baseurl",
      "url": "https://download.copr.fedorainfracloud.org/results/@redhat-et/microshift/epel-8-x86_64/",
      "check_gpg": false,
      "check_ssl": false,
      "system": false,
      "rhsm": false
    }
  }
}
```

This file contains the additional content sources Image Builder will need to install MicroShift RPMs and associated dependencies.

## Building a MicroShift Image

Log in to the OpenShift CLI and change into the `rfe` namespace:

```shell
oc project rfe
```

From the root of the project, execute the following command to execute the `rfe-oci-image-pipeline` pipeline to build the `microshift` blueprint:

```shell
tkn pipeline start rfe-oci-image-pipeline \
     --workspace name=shared-workspace,volumeClaimTemplateFile=examples/pipelines/volumeclaimtemplate.yaml \
     -s rfe-automation \
     --use-param-defaults \
     -p blueprint-dir=microshift \
     -p blueprints-git-url=https://github.com/redhat-cop/rhel-edge-automation-arch.git \
     -p blueprints-git-revision=blueprints \
     -p additional-content-sources='$(jq -c . /tmp/microshift-additional-sources.json | base64 -w0)'
```

If you updated the blueprint and saved it in your own git repository, change the  blueprint parameters to match your repository.

The output of the `tkn` command will display another command to view the progress of the build.

_Note: The process of building a image takes time.

### Pipeline Results

Each pipeline run returns four results:

* `build-commit` - The Build Commit ID from Image Builder
* `image-builder-host` - The Image Builder host used during pipeline execution
* `image-path` - Location in Quay registry of OCI container`
* `image-tags` - Tags applied to the container (JSON list)

To view the results, find the latest pipeline run. Use the following command as an example:

```shell
$ tkn pipelinerun list -n rfe --label tekton.dev/pipeline=rfe-oci-image-pipeline --limit 1
NAME                               STARTED     DURATION     STATUS
rfe-oci-image-pipeline-run-g8hzp   1 day ago   16 minutes   Succeeded
```

Then run the following to view the pipeline results:

```shell
$ oc get pipelinerun -n rfe rfe-oci-image-pipeline-run-g8hzp -ojsonpath='{.status.pipelineResults}'
[
  {
    "name": "build-commit",
    "value": "04b92863-ab80-492e-b331-815530e34f3b"
  },
  {
    "name": "image-path",
    "value": "quay-quay-quay.apps.cluster/rfe/microshift"
  },
  {
    "name": "image-builder-host",
    "value": "10.129.2.9"
  },
  {
    "name": "image-tags",
    "value": "[\"latest\", \"0.0.1\"]"
  }
]
```

## Staging OCI Container with OSTree Commit

Now that we have our OCI container from Image Builder with our OSTree Commit in Quay, we can run a pipeline to deploy it as a staging environment in OpenShift.

From the root of the project, execute the following command to execute the `rfe-oci-stage-pipeline` pipeline to deploy the OCI container built in the previous pipeline (`rfe-oci-image-pipeline`) run.

```shell
tkn pipeline start rfe-oci-stage-pipeline \
--workspace name=shared-workspace,volumeClaimTemplateFile=examples/pipelines/volumeclaimtemplate.yaml \
-s rfe-automation \
--use-param-defaults \
-p image-path=$(oc get route -n quay quay-quay -ojsonpath='{.spec.host}')/rfe/microshift \
-p image-tag=latest
```

This command is similar to the previous pipeline run, but the following parameters are used:

* `-p image-path=quay-quay-quay.apps.cluster.com/rfe/microshift` - The path to the OCI container stored in the Quay registry.
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
    "value": "http://microshift-latest-rfe.apps.cluster.com/repo"
  }
]
```

## Moving from Stage to Production

The next stage involves synchronizing our OSTree Commit from our staging environment to production.

From the root of the project, execute the following command to execute the `rfe-oci-publish-content-pipeline` pipeline:

```shell
tkn pipeline start rfe-oci-publish-content-pipeline \
--workspace name=shared-workspace,volumeClaimTemplateFile=examples/pipelines/volumeclaimtemplate.yaml \
-s rfe-automation \
--use-param-defaults \
-p image-path=$(oc get route -n quay quay-quay -ojsonpath='{.spec.host}')/rfe/microshift \
-p image-tag=latest 
```

This command is similar to the previous pipeline run, but the following parameters are used:

* `-p image-path=quay-quay-quay.apps.cluster.com/rfe/microshift` - The path to the OCI container stored in the Quay registry.
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
    "value": "http://httpd-rfe.apps.cluster.com/microshift/latest"
  }
]
```

## Creating the Kickstart File

A Tekton pipeline called `rfe-kickstart-pipeline` is responsible for publishing a Kickstart file to both Nexus and the HTTPD server. As the pipeline uses Ansible, Jinja based templating is available to inject key values (in particular, the location of the OSTree repository).

Using the location of the OSTree repository from the results of either the `rfe-oci-stage-pipeline` or `rfe-oci-publish-content-pipeline` pipelines, execute the following command:

```shell
tkn pipeline start rfe-kickstart-pipeline \
-s rfe-automation \
--workspace name=shared-workspace,volumeClaimTemplateFile=examples/pipelines/volumeclaimtemplate.yaml \
--use-param-defaults \
-p kickstart-path=microshift/kickstart.ks \
-p ostree-repo-url=file:///run/install/repo/ostree/repo
```

This command is similar to the previous pipeline run, but the following parameters are used:

To break down the preceding command:

* `-p kickstart-path=microshift/kickstart.ks` - The location of the kickstart to use in the referenced repository. By default, the _kickstarts_ branch of this repository will be used.
* `-p ostree-repo-url=file:///run/install/repo/ostree/repo` - The location of the OSTree repository. This kickstart will be embedded in the installer image during the next pipeline run, so the OSTree repository will be local to the ISO.

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
    "value": "https://nexus-rfe.apps.cluster.com/repository/rfe-kickstarts/microshift/kickstart.ks"
  },
  {
    "name": "serving-storage-url",
    "value": "https://httpd-rfe.apps.cluster.com/kickstarts/microshift/kickstart.ks"
  }
]
```

## Creating Auto Booting RFE Installer

One of the new features in Image Builder 8.4 is the ability to compose (using `image-type` `rhel-edge-installer`) installation media that has an OSTree commit embedded in the installer. The pipeline in this project goes a step further and embeds a kickstart file in the generated ISO and reconfigures `EFI/BOOT/grub.cfg`/`isolinux/isolinux.cfg` to automatically install RFE using the embedded kickstart.

From the root of the project, execute the following command to execute the `rfe-oci-iso-pipeline` pipeline:

```shell
tkn pipeline start rfe-oci-iso-pipeline \
--workspace name=shared-workspace,volumeClaimTemplateFile=examples/pipelines/volumeclaimtemplate.yaml \
-s rfe-automation \
--use-param-defaults \
-p kickstart-url=https://httpd-rfe.apps.cluster.com/kickstarts/microshift/kickstart.ks \
-p ostree-repo-url=http://httpd-rfe.apps.cluster.com/microshift/latest
```

This command is similar to the previous pipeline run, but the following parameters are used:

* `-p kickstart-url=https://httpd-rfe.apps.cluster.com/kickstarts/microshift/kickstart.ks` - The path to the kickstart to be embedded in the ISO.
* `-p ostree-repo-url=http://httpd-rfe.apps.cluster.com/microshift/latest` - The path to the OSTree repository that will be embedded in the ISO.

### Pipeline Results

Each pipeline run returns two results:

* `build-commit-id` - The Build Commit ID from Image Builder
* `image-builder-host` - The Image Builder host used during pipeline execution
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
    "value": "9b4b3af4-c4f4-45a3-a5e7-cd1994838d26"
  },
  {
    "name": "image-builder-host",
    "value": "10.129.2.8"
  },
  {
    "name": "iso-url",
    "value": "https://httpd-rfe.apps.cluster.com/9b4b3af4-c4f4-45a3-a5e7-cd1994838d26-auto.iso"
  }
]
```

## Deploying

Once the ISO pipeline finishes, simply pull the ISO linked in the `iso-url` result and boot it on a new system. Once the ISO boots it should automatically begin the installation without any prompts.
