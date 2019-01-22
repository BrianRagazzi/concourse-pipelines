#!/bin/bash -eu

# tar -xvf bbr-release/bbr*.tar
# cp releases/bbr binary/


# source "$(dirname $BASH_SOURCE)"/om-cmd



# BOSH_CLIENT="ops_manager"
# BOSH_CLIENT_SECRET=$(jq -r '.jobs[] | select(.name == "bosh") | .properties.uaa.clients.ops_manager.secret' director_manifest.json)

if [ -z $BOSH_ADDRESS ]; then
  echo "Getting address of BOSH Director from Ops Manager"
  om-linux \
      -t https://$OPS_MGR_HOST \
      -u $OPS_MGR_USR \
      -p $OPS_MGR_PWD \
      -k curl -p /api/v0/deployed/director/manifest > director_manifest.json
  BOSH_ADDRESS=$(jq -r '.jobs[] | select(.name == "bosh") | .properties.director.address' director_manifest.json)
fi

# BOSH_CA_CERT_PATH="${PWD}/bosh.crt"
# jq -r '.jobs[] | select(.name == "bosh") | .properties.director.config_server.ca_cert' director_manifest.json > "${BOSH_CA_CERT_PATH}"

# Get CF deployment guid
# om_cmd curl -p /api/v0/deployed/products > deployed_products.json
# ERT_DEPLOYMENT_NAME=$(jq -r '.[] | select( .type | contains("cf")) | .guid' "deployed_products.json")

# Get UAA BBR Credentials
om-linux \
    -t https://$OPS_MGR_HOST \
    -u $OPS_MGR_USR \
    -p $OPS_MGR_PWD \
    -k curl -p /api/v0/deployed/director/credentials/bbr_ssh_credentials > bbr_keys.json
BBR_PRIVATE_KEY=$(jq -r '.credential.value.private_key_pem' bbr_keys.json)

# export BOSH_CLIENT
# export BOSH_CLIENT_SECRET
# export BOSH_CA_CERT_PATH
# export BOSH_ADDRESS
# export ERT_DEPLOYMENT_NAME
# export BBR_PRIVATE_KEY


# om-linux \
#     -t https://$OPS_MGR_HOST \
#     -u $OPS_MGR_USR \
#     -p $OPS_MGR_PWD \
#     -k curl -p /api/v0/deployed/director/credentials/bbr_ssh_credentials > bbr_keys.json
# BOSH_PRIVATE_KEY=$(jq -r '.credential.value.private_key_pem' bbr_keys.json)

pushd director-backup-artifact
  pwd
  ../releases/bbr director --host "${BOSH_ADDRESS}" \
  --username bbr \
  --private-key-path <(echo "${BBR_PRIVATE_KEY}") \
  backup
  ls -al
  df -h
  datever=$(date +"%y%m%d%H%M%S")
  tar -cvf director-backup-$datever.tar -- *
popd
