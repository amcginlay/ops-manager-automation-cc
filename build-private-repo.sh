#!/bin/bash

SCRIPTDIR=$(cd $(dirname "$0") && pwd -P)

source ~/.env

rm -rf ~/${GITHUB_PRIVATE_REPO_NAME}/*

mkdir -p ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars
mkdir -p ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/env

cp -r ${SCRIPTDIR}/ci/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/
cp -r ${SCRIPTDIR}/download-product-configs/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/
cp -r ${SCRIPTDIR}/config/ ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/

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

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/env/env.yml << EOF
---
target: ((om-target))
username: ((om-username))
password: ((om-password))
# connect-timeout: 30
# request-timeout: 1800
skip-ssl-validation: true
EOF

cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/config/auth.yml << EOF
---
username: ((om-username))
password: ((om-password))
decryption-passphrase: ((om-decryption-passphrase))
EOF

echo "---" > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars/director-vars.yml
# cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars/director-vars.yml << EOF
# ---
# gcp-credentials: |
# $(cat ~/gcp_credentials.json | sed 's/^/  /')
# gcp-project-id: $(gcloud config get-value core/project)
# subdomain-name: ${PKS_SUBDOMAIN_NAME}
# EOF

echo "---" > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars/pivotal-container-service-vars.yml
# cat > ~/${GITHUB_PRIVATE_REPO_NAME}/${PKS_SUBDOMAIN_NAME}/vars/pivotal-container-service-vars.yml << EOF
# ---
# gcp-project-id: $(gcloud config get-value core/project)
# subdomain-name: ${PKS_SUBDOMAIN_NAME}
# domain-name: ${PKS_DOMAIN_NAME}
# domain-crt: |
# $(cat ~/certs/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.crt | sed 's/^/  /g')
# domain-key: |
# $(cat ~/certs/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key | sed 's/^/  /g')
# EOF
