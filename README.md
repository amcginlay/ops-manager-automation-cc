# ops-manager-automation-cc

## Create your jumpbox from your local machine or Google Cloud Shell

```bash
GCP_PROJECT_ID=<TARGET_GCP_PROJECT_ID>
gcloud auth login --project ${GCP_PROJECT_ID} --quiet

gcloud services enable compute.googleapis.com \
  --project "${GCP_PROJECT_ID}"

gcloud compute instances create "jbox-cc" \
  --image-project "ubuntu-os-cloud" \
  --image-family "ubuntu-1804-lts" \
  --boot-disk-size "200" \
  --machine-type=g1-small \
  --project "${GCP_PROJECT_ID}" \
  --zone "us-central1-a"
```

## Move to the jumpbox and log in to GCP

```bash
gcloud compute ssh ubuntu@jbox-cc \
  --project "${GCP_PROJECT_ID}" \
  --zone "us-central1-a"
```
  
```bash
gcloud auth login --quiet
```

All following commands should be executed from the jumpbox unless otherwsie instructed.

## Prepare your environment file

```bash
echo "# *** your environment-specific variables will go here ***" > ~/.env

echo "PRODUCT_SLUG=pivotal-container-service" > ~/.env                       # indicates the target platform (TODO cf)

echo "PIVNET_UAA_REFRESH_TOKEN=CHANGE_ME_PIVNET_UAA_REFRESH_TOKEN" >> ~/.env # e.g. xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-r
echo "PKS_DOMAIN_NAME=CHANGE_ME_DOMAIN_NAME" >> ~/.env                       # e.g. pal.pivotal.io
echo "PKS_SUBDOMAIN_NAME=CHANGE_ME_SUBDOMAIN_NAME" >> ~/.env                 # e.g. maroon
echo "GITHUB_PUBLIC_REPO=CHANGE_ME_GITHUB_PUBLIC_REPO" >> ~/.env             # e.g. https://github.com/amcginlay/ops-manager-automation-cc.git

echo "export OM_TARGET=https://pcf.\${PKS_SUBDOMAIN_NAME}.\${PKS_DOMAIN_NAME}" >> ~/.env
echo "export OM_USERNAME=admin" >> ~/.env
echo "export OM_PASSWORD=$(uuidgen)" >> ~/.env
echo "export OM_DECRYPTION_PASSPHRASE=\${OM_PASSWORD}" >> ~/.env
echo "export OM_SKIP_SSL_VALIDATION=true" >> ~/.env
```

__Before__ continuing, open the `.env` file and update the `CHANGE_ME` values accordingly.

Ensure these variables get set into the shell every time the ubuntu user connects to the jumpbox:

```bash
echo "source ~/.env" >> ~/.bashrc
```

Load the variables into your shell with the source command so we can use them immediately:

```bash
source ~/.env
```

## Prepare jumpbox and generate service account

```bash
gcloud services enable iam.googleapis.com --async
gcloud services enable cloudresourcemanager.googleapis.com --async
gcloud services enable dns.googleapis.com --async
gcloud services enable sqladmin.googleapis.com --async

sudo apt update --yes && \
sudo apt install --yes jq && \
sudo apt install --yes build-essential && \
sudo apt install --yes ruby-dev && \
sudo apt install --yes awscli && \
sudo apt install --yes tree
```

```bash
cd ~

FLY_VERSION=5.0.0
wget -O fly.tgz https://github.com/concourse/concourse/releases/download/v${FLY_VERSION}/fly-${FLY_VERSION}-linux-amd64.tgz && \
  tar -xvf fly.tgz && \
  sudo mv fly /usr/local/bin && \
  rm fly.tgz
  
CT_VERSION=0.3.0
wget -O control-tower https://github.com/EngineerBetter/control-tower/releases/download/${CT_VERSION}/control-tower-linux-amd64 && \
  chmod +x control-tower && \
  sudo mv control-tower /usr/local/bin/

OM_VERSION=0.51.0
wget -O om https://github.com/pivotal-cf/om/releases/download/${OM_VERSION}/om-linux && \
  chmod +x om && \
  sudo mv om /usr/local/bin/

PN_VERSION=0.0.55
wget -O pivnet https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PN_VERSION}/pivnet-linux-amd64-${PN_VERSION} && \
  chmod +x pivnet && \
  sudo mv pivnet /usr/local/bin/

BOSH_VERSION=5.4.0
wget -O bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSH_VERSION}-linux-amd64 && \
  chmod +x bosh && \
  sudo mv bosh /usr/local/bin/
  
CHUB_VERSION=2.2.1
wget -O credhub.tgz https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${CHUB_VERSION}/credhub-linux-${CHUB_VERSION}.tgz && \
  tar -xvf credhub.tgz && \
  sudo mv credhub /usr/local/bin && \
  rm credhub.tgz

TF_VERSION=0.11.13
wget -O terraform.zip https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
  unzip terraform.zip && \
  sudo mv terraform /usr/local/bin && \
  rm terraform.zip
  
TGCP_VERSION=0.74.0
wget -O terraforming-gcp.tar.gz https://github.com/pivotal-cf/terraforming-gcp/releases/download/v${TGCP_VERSION}/terraforming-gcp-v${TGCP_VERSION}.tar.gz && \
  tar -zxvf terraforming-gcp.tar.gz && \
  rm terraforming-gcp.tar.gz
```

```bash
gcloud iam service-accounts create p-service --display-name "Pivotal Service Account"

gcloud projects add-iam-policy-binding $(gcloud config get-value core/project) \
  --member "serviceAccount:p-service@$(gcloud config get-value core/project).iam.gserviceaccount.com" \
  --role 'roles/owner'

cd ~
gcloud iam service-accounts keys create 'gcp_credentials.json' \
  --iam-account "p-service@$(gcloud config get-value core/project).iam.gserviceaccount.com"
```

## Clone this repo

The scripts, pipelines and config you need to complete the following steps are inside this repo, so clone it to your jumpbox:

```bash
git clone ${GITHUB_PUBLIC_REPO} ~/ops-manager-automation-cc
```

## Create a self-signed certificate

Run the following script to create a certificate and key for the installation:

```bash
DOMAIN=${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} ~/ops-manager-automation-cc/bin/mk-ssl-cert-key.sh
```

## Terraform the infrastructure

```bash
cd ~/terraforming/terraforming-pks

cat > terraform.tfvars <<-EOF
dns_suffix          = "${PKS_DOMAIN_NAME}"
env_name            = "${PKS_SUBDOMAIN_NAME}"
region              = "us-central1"
zones               = ["us-central1-b", "us-central1-a", "us-central1-c"]
project             = "$(gcloud config get-value core/project)"
opsman_image_url    = ""
opsman_vm           = 0
create_gcs_buckets  = "false"
external_database   = 0
isolation_segment   = "false"
service_account_key = <<SERVICE_ACCOUNT_KEY
$(cat ~/gcp_credentials.json)
SERVICE_ACCOUNT_KEY
EOF

terraform init
terraform apply --auto-approve
```

Note the `opsman_image_url != ""` and `opsman_vm = 0` settings which prohibit Terraform from downloading and deploying the Ops Manager VM.
The Concourse pipelines will take responsibility for this.

This will take about 5-10 mins to complete.

## Install Concourse

```bash
GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower deploy \
    --region us-central1 \
    --iaas gcp \
    --workers 3 \
    ${PKS_SUBDOMAIN_NAME}
```

This will take about 20 mins to complete.

## Persist a few credentials

```bash
INFO=$(GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower info \
    --region us-central1 \
    --iaas gcp \
    --json \
    ${PKS_SUBDOMAIN_NAME}
)

echo "CC_ADMIN_PASSWD=$(echo ${INFO} | jq --raw-output .config.concourse_password)" >> ~/.env
echo "CREDHUB_CA_CERT='$(echo ${INFO} | jq --raw-output .config.credhub_ca_cert)'" >> ~/.env
echo "CREDHUB_CLIENT=credhub_admin" >> ~/.env
echo "CREDHUB_SECRET=$(echo ${INFO} | jq --raw-output .config.credhub_admin_client_secret)" >> ~/.env
echo "CREDHUB_SERVER=$(echo ${INFO} | jq --raw-output .config.credhub_url)" >> ~/.env
echo 'eval "$(GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower info \
    --region us-central1 \
    --iaas gcp \
    --env ${PKS_SUBDOMAIN_NAME})"' >> ~/.env

source ~/.env
```

## Verify BOSH and Credhub connectivity

```bash
bosh env
credhub --version
```

## Check Concourse targets and check the pre-configured pipeline:

```bash
fly targets
fly -t control-tower-${PKS_SUBDOMAIN_NAME} pipelines
```

Navigate to the `url` shown for `fly targets`.

Use `admin` user and the value of `CC_ADMIN_PASSWD` to login and see the pre-configured pipeline.

__Note__ `control-tower` will log you in but valid access tokens will expire every 24 hours. The command to log back in is:

```bash
fly -t control-tower-${PKS_SUBDOMAIN_NAME} login --insecure --username admin --password ${CC_ADMIN_PASSWD}
```

## Set up dedicated GCS bucket for downloads

```bash
gsutil mb -c regional -l us-central1 gs://${PKS_SUBDOMAIN_NAME}-concourse-resources
gsutil versioning set on gs://${PKS_SUBDOMAIN_NAME}-concourse-resources
```

## Store secrets in Credhub

```bash
credhub set -n pivnet-api-token -t value -v "${PIVNET_UAA_REFRESH_TOKEN}"
credhub set -n domain-name -t value -v "${PKS_DOMAIN_NAME}"
credhub set -n subdomain-name -t value -v "${PKS_SUBDOMAIN_NAME}"
credhub set -n gcp-project-id -t value -v "$(gcloud config get-value core/project)"
credhub set -n opsman-public-ip -t value -v "$(dig +short pcf.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME})"
credhub set -n gcp-credentials -t value -v "$(cat ~/gcp_credentials.json)"
credhub set -n om-target -t value -v "${OM_TARGET}"
credhub set -n om-skip-ssl-validation -t value -v "${OM_SKIP_SSL_VALIDATION}"
credhub set -n om-username -t value -v "${OM_USERNAME}"
credhub set -n om-password -t value -v "${OM_PASSWORD}"
credhub set -n om-decryption-passphrase -t value -v "${OM_DECRYPTION_PASSPHRASE}"
credhub set -n domain-crt -t value -v "$(cat ~/certs/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.crt)"
credhub set -n domain-key -t value -v "$(cat ~/certs/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key)"
```

## Build the pipeline

Create a `private.yml` to contain your secrets:

```bash
cat > ~/private.yml << EOF
---
config-uri: ${GITHUB_PUBLIC_REPO}
gcp-credentials: |
$(cat ~/gcp_credentials.json | sed 's/^/  /')
gcs-bucket: ${PKS_SUBDOMAIN_NAME}-concourse-resources
pivnet-token: ${PIVNET_UAA_REFRESH_TOKEN}
credhub-ca-cert: |
$(echo $CREDHUB_CA_CERT | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/CERTIFICATE/! s/ /\n/g' | sed 's/^/  /')
credhub-client: ${CREDHUB_CLIENT}
credhub-secret: ${CREDHUB_SECRET}
credhub-server: ${CREDHUB_SERVER}
EOF
```

Set and unpause the pipeline:

```bash
fly -t control-tower-${PKS_SUBDOMAIN_NAME} set-pipeline -p ${PRODUCT_SLUG} -n \
  -c ~/ops-manager-automation-cc/ci/${PRODUCT_SLUG}/pipeline.yml \
  -l ~/private.yml

fly -t control-tower-${PKS_SUBDOMAIN_NAME} unpause-pipeline -p ${PRODUCT_SLUG}
```

This should begin to execute in ~60 seconds.

Be aware that you may be required to manually accept the PivNet EULAs before a product can be downloaded
so watch for pipeline failures which contain the necessary URLs to follow.

You may also observe that on the first run, the `export-installation` job will fail because the Ops Manager
is missing.
Run this job manually once the `install-opsman` job has run successfully.

## Add a dummy state file

The `state,.yml` file is produced by the `create-vm` task and serves as a flag to indicate that an Ops Manager exists.
We currently store the `state.yml` file in GCS.
The `install-opsman` job also consumes this file so it can short-circuit the `create-vm` task if an Ops Manager does exist.
The mandatory input does not exist by default so we create a dummy `state.yml` file to kick off proceedings.
Storing the `state.yml` file in git may work around this edge case but, arguably, GCS/S3 is a more appropriate home.

```bash
echo "---" > ~/state.yml
gsutil cp ~/state.yml gs://${PKS_SUBDOMAIN_NAME}-concourse-resources/
```

If required, be aware that versioned buckets require you to use `gsutil rm -a` to take files fully out of view.

## Teardown

When you're done with your platform, use the installation dashboard to delete the installation and manually delete the Ops Manager VM, then execute the following:

```bash
cd ~/terraforming/terraforming-pks
terraform destroy --auto-approve
```

```bash
GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower destroy \
    --region us-central1 \
    --iaas gcp \
    ${PKS_SUBDOMAIN_NAME}
```
