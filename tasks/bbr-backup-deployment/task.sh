#!/bin/bash -eu

# tar -xvf bbr-release/bbr*.tar


om-linux \
    -t https://$OPS_MGR_HOST \
    -u $OPS_MGR_USR \
    -p $OPS_MGR_PWD \
    -k curl -p /api/v0/deployed/director/manifest > director_manifest.json

# BOSH_CLIENT="ops_manager"
# BOSH_CLIENT_SECRET=$(jq -r '.jobs[] | select(.name == "bosh") | .properties.uaa.clients.ops_manager.secret' director_manifest.json)
# export BOSH_CLIENT
# export BOSH_CLIENT_SECRET
BBR_CLIENT="bbr_client"
BBR_PASS=$(
  om-linux   \
  --target "$OPS_MGR_HOST"   \
  --username "$OPS_MGR_USR"   \
  --password "$OPS_MGR_PWD"     \
  --skip-ssl-validation     \
  curl --silent --path "/api/v0/deployed/director/credentials/uaa_bbr_client_credentials" | \
  jq -r '.[] | .value.password' )


if [ -z $BOSH_ADDRESS ]; then
  echo "Getting address of BOSH Director from Ops Manager"
  BOSH_ADDRESS=$(jq -r '.jobs[] | select(.name == "bosh") | .properties.director.address' director_manifest.json)
else
 echo "Using provided BOSH Address: $BOSH_ADDRESS"
fi

BOSH_CA_CERT_PATH="${PWD}/bosh.crt"
# jq -r '.jobs[] | select(.name == "bosh") | .properties.director.config_server.ca_cert' director_manifest.json > "${BOSH_CA_CERT_PATH}"

# OPSMGR_CA_CERT=$(
om-linux \
  -t https://$OPS_MGR_HOST \
  -u $OPS_MGR_USR \
  -p $OPS_MGR_PWD \
  -k curl -p /api/v0/security/root_ca_certificate | \
   jq --raw-output '.root_ca_certificate_pem' > "${BOSH_CA_CERT_PATH}"

DEPLOYMENTS=$(
  om-linux   \
  --target "$OPS_MGR_HOST"   \
  --username "$OPS_MGR_USR"   \
  --password "$OPS_MGR_PWD"     \
  --skip-ssl-validation     \
  curl --silent --path "/api/v0/deployed/products" | \
  jq -r '.[] | select (.type | contains("p-bosh") | not) | .guid')

datever=$(date +"%y%m%d%H%M%S")
# mkdir bbr-backup-artifact
for depl in $DEPLOYMENTS
do
  echo "Attempting to backup ${depl}"
  #pushd bbr-backup-artifact
    bbr-release/releases/bbr deployment --target "${BOSH_ADDRESS}" \
      --username "${BBR_CLIENT}" \
      --password "${BBR_PASS}" \
      --deployment "${depl}" \
      --ca-cert "${BOSH_CA_CERT_PATH}" \
      backup --with-manifest \
      --artifact-path ${PWD}/bbr-backup-artifact/${depl}-backup-$datever.tar
      # tar -cvf ${DEPLOYMENT_NAME}-backup-$datever.tar -- *
  #popd
done
