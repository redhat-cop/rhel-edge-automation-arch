#!/usr/bin/env python

import json
import os
import sys

cluster_oauth = os.environ.get('CLUSTER_OAUTH_LOCATION', '/config/cluster-oauth.yaml')
gitops_oauth = os.environ.get('GITOPS_OAUTH_LOCATION', '/config/gitops-oauth.yaml')

gitops_idenity_providers = []
cluster_identity_providers = []


def read_json_file(filename):
    with open(filename) as json_file:
        return json.load(json_file)


def merge_identity_provider(cluster_identity_providers, gitops_provider):
    for identity_provider_idx in range(len(cluster_identity_providers)):

        if gitops_provider['name'] == cluster_identity_providers[identity_provider_idx]['name']:
            cluster_identity_providers[identity_provider_idx] = gitops_provider
            return

    cluster_identity_providers.append(gitops_provider)


if not os.path.exists(cluster_oauth):
    print("Cannot locate Cluster OAuth")
    sys.exit(1)

if not os.path.exists(gitops_oauth):
    print("GitOps Configuration File Not Found. Exiting")
    sys.exit(0)


cluster_oauth_file = read_json_file(cluster_oauth)

gitops_oauth_file = read_json_file(gitops_oauth)


if 'identityProviders' in cluster_oauth_file['spec']:
    cluster_identity_providers = cluster_oauth_file['spec']['identityProviders']

if 'identityProviders' in gitops_oauth_file['spec']:
    gitops_identity_providers = gitops_oauth_file['spec']['identityProviders']

if len(gitops_identity_providers) > 0:
    for gitops_identity_provider in gitops_identity_providers:
        merge_identity_provider(cluster_identity_providers, gitops_identity_provider)

if len(cluster_identity_providers):
    cluster_oauth_file['spec']['identityProviders'] = cluster_identity_providers

with open(cluster_oauth, 'w') as outfile:
    json.dump(cluster_oauth_file, outfile)
