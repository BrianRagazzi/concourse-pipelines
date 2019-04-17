#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

export ROOT_DIR=`pwd`

wget "https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-3.0.1-linux-amd64" -O $ROOT_DIR/bosh
chmod +x ./bosh
mv ./bosh /usr/local/bin

# DIRECTOR_IP=$(
#   om-linux \
#     --target https://$OPS_MGR_HOST \
#     --username "$OPS_MGR_USR" \
#     --password "$OPS_MGR_PWD" \
#     --skip-ssl-validation \
#     curl --silent --path "/api/v0/deployed/director/manifest" | \
#     jq -r '.jobs[] | select(.name == "bosh") | .networks[0].static_ips[0]'
# )
# but wait, there's an easier way:
echo "Connecting to [$OPS_MGR_HOST] to get BOSH details"

BOSH_CREDS=$(
om-linux   \
--target https://$OPS_MGR_HOST   \
--username "$OPS_MGR_USR"   \
--password "$OPS_MGR_PWD"     \
--skip-ssl-validation     \
curl --silent --path "/api/v0/deployed/director/credentials/bosh_commandline_credentials"
)

# sample BOSH_CREDS:
# { "credential": "BOSH_CLIENT=ops_manager BOSH_CLIENT_SECRET=CtzLT32MKvTDXtQ2Qe56IG0TqX-7BCZ6 BOSH_CA_CERT=/var/tempest/workspaces/default/root_ca_certificate BOSH_ENVIRONMENT=192.13.51.11 bosh " }
if [[ -z $DIRECTOR_IP ]]; then
  DIRECTOR_IP=$(echo $BOSH_CREDS | jq -r '.credential' | cut -d" " -f4 | cut -d"=" -f2)
fi

export BOSH_CLIENT_SECRET=$(echo $BOSH_CREDS | jq -r '.credential' | cut -d" " -f2 | cut -d"=" -f2)

export BOSH_CLIENT=$(echo $BOSH_CREDS | jq -r '.credential' | cut -d" " -f1 | cut -d"=" -f2)

#get cert from OPsMgr
om-linux \
  -t https://$OPS_MGR_HOST \
  -u $OPS_MGR_USR \
  -p $OPS_MGR_PWD \
  -k curl -p /api/v0/security/root_ca_certificate | \
   jq --raw-output '.root_ca_certificate_pem' > $ROOT_DIR/root_ca_cert

# cat $ROOT_DIR/root_ca_cert
echo "Connecting to BOSH Director [$DIRECTOR_IP]"

#Connect to BOSH DIrector, this will use the BOSH_CLIENT* creds
bosh alias-env bosh1 -e $DIRECTOR_IP --ca-cert $ROOT_DIR/root_ca_cert
#bosh -e bosh1 env
logged_in_as=$(bosh -e bosh1 env --json | jq -r '.Tables[].Rows[] | .user')
if [[ "$logged_in_as" != "$BOSH_CLIENT" ]]; then
  echo "FAILED to login"
  exit 1
fi

#make a folder to put the logs into
if [ -d $ROOT_DIR/logs ]; then
  echo "logs folder exists"
else
  mkdir $ROOT_DIR/logs
fi

LOGS_DIR=$ROOT_DIR/logs


#list deployments:
DEPLOYMENTS=$(bosh -e bosh1 deployments --json | jq -r '.Tables[].Rows[] | .name')

for depl in $DEPLOYMENTS
do
  bosh -e bosh1 -d "$depl" logs --dir $LOGS_DIR
done

if [ -d ./out ]; then
  echo "out folder exists"
else
  mkdir ./out
fi

datever=$(date +"%y%m%d%H%M%S")
tar -cvzf ./out/bundle-$OPS_MGR_HOST-$datever.tgz $ROOT_DIR/logs/
