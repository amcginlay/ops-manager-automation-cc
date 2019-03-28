#!/bin/bash

SCRIPTDIR=$(cd $(dirname "$0") && pwd -P)

source ~/.env

rm -rf ~/${GITHUB_PRIVATE_REPO_NAME}/*

mkdir -p ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/settings/vars
mkdir -p ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/settings/env

cp -r ${SCRIPTDIR}/ci/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/
cp -r ${SCRIPTDIR}/download-product-configs/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/settings/
cp -r ${SCRIPTDIR}/config/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/settings/

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/ci/pipeline-vars.yml << EOF
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

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/settings/env/env.yml << EOF
---
target: ((om-target))
username: ((om-username))
password: ((om-password))
skip-ssl-validation: true
EOF

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/settings/config/auth.yml << EOF
---
username: ((om-username))
password: ((om-password))
decryption-passphrase: ((om-decryption-passphrase))
EOF
