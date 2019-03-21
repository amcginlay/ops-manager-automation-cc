#!/bin/bash

SCRIPTDIR=$(cd $(dirname "$0") && pwd -P)

source ~/.env

rm -rf ~/${GITHUB_PRIVATE_REPO_NAME}/*
cp -r ${SCRIPTDIR}/ci/ ~/${GITHUB_PRIVATE_REPO_NAME}/
cp -r ${SCRIPTDIR}/download-product-configs/ ~/${GITHUB_PRIVATE_REPO_NAME}/
cp -r ${SCRIPTDIR}/config/ ~/${GITHUB_PRIVATE_REPO_NAME}/

cp -r ${SCRIPTDIR}/state/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/
mkdir -p ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars
mkdir -p ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/env
mkdir -p ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/config

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/ci/pipeline-vars.yml << EOF
---
configuration:
  private_key: |
$(cat ~/.ssh/id_rsa | sed 's/^/    /')
  uri: git@github.com:${GITHUB_ORG}/${GITHUB_PRIVATE_REPO_NAME}.git
variable:
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
opsman_image_s3_versioned_regexp: OpsManager(.*)onGCP.yml
foundation: ${PKS_SUBDOMAIN_NAME}
EOF

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars/opsman-vars.yml << EOF
---
gcp-credentials: |
$(cat ~/gcp_credentials.json | sed 's/^/  /')
opsman-public-ip: $(dig +short pcf.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME})
gcp-project-id: $(gcloud config get-value core/project)
subdomain-name: ${PKS_SUBDOMAIN_NAME}
EOF

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/env/env.yml << EOF
---
target: ${OM_TARGET}
connect-timeout: 30
request-timeout: 1800
skip-ssl-validation: ${OM_SKIP_SSL_VALIDATION}
username: ${OM_USERNAME}
password: ${OM_PASSWORD}
decryption-passphrase: ${OM_DECRYPTION_PASSPHRASE}
EOF

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/config/auth.yml << EOF
---
username: ${OM_USERNAME}
password: ${OM_PASSWORD}
decryption-passphrase: ${OM_DECRYPTION_PASSPHRASE}
EOF

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars/director-vars.yml << EOF
---
gcp-credentials: |
$(cat ~/gcp_credentials.json | sed 's/^/  /')
gcp-project-id: $(gcloud config get-value core/project)
subdomain-name: ${PKS_SUBDOMAIN_NAME}
EOF

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars/pivotal-container-service-vars.yml << EOF
---
gcp-project-id: $(gcloud config get-value core/project)
subdomain-name: ${PKS_SUBDOMAIN_NAME}
domain-name: ${PKS_DOMAIN_NAME}
domain-crt: |
$(cat ~/certs/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.crt | sed 's/^/  /g')
domain-key: |
$(cat ~/certs/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key | sed 's/^/  /g')
EOF
