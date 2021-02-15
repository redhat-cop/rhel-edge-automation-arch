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

The overall architecture is still being defined. We have split out "Above Site" components (things like RFE build orchestration and CI/CD tooling) and "Below Site" (the actual RFE deployments). Our plan is to host all Above Site components on OpenShift.

![Above Site Architecture](/images/above-site-architecture.png)