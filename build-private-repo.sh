#!/bin/bash

SCRIPTDIR=$(cd $(dirname "$0") && pwd -P)

source ~/.env

rm -rf ~/${GITHUB_PRIVATE_REPO_NAME}/*

mkdir ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/

cp -r ${SCRIPTDIR}/ci/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/
cp -r ${SCRIPTDIR}/config/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/ci/pivotal-container-service/pipeline-vars.yml << EOF
---
config:
  private_key: |
$(cat ~/.ssh/id_rsa | sed 's/^/    /')
  uri: git@github.com:${GITHUB_ORG}/${GITHUB_PRIVATE_REPO_NAME}.git
gcp_credentials: |
$(cat ~/gcp_credentials.json | sed 's/^/  /')
gcs:
  buckets:
    pivnet_products: ${PKS_SUBDOMAIN_NAME}-concourse-resources
    installation: ${PKS_SUBDOMAIN_NAME}-concourse-resources
pivnet_token: ${PIVNET_UAA_REFRESH_TOKEN}
credhub-ca-cert: |
$(echo $CREDHUB_CA_CERT | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/CERTIFICATE/! s/ /\n/g' | sed 's/^/  /')
credhub-client: ${CREDHUB_CLIENT}
credhub-secret: ${CREDHUB_SECRET}
credhub-server: ${CREDHUB_SERVER}
foundation: ${PKS_SUBDOMAIN_NAME}
EOF
