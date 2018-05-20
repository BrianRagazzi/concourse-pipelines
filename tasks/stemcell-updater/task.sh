#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

# PIVNET_CLI=`find ./pivnet-cli -name "*linux-amd64*"`
# chmod +x $PIVNET_CLI

# chmod +x om-cli/om-linux
#CMD=om-linux

SC_VERSIONS=$(
  om-linux   \
  --target "$OPS_MGR_HOST"   \
  --username "$OPS_MGR_USR"   \
  --password "$OPS_MGR_PWD"     \
  --skip-ssl-validation     \
  curl --silent --path "/api/v0/pivotal_network/stemcell_updates" | \
  jq -r '.stemcell_updates[] | .stemcell_version')

for sc in $SC_VERSIONS
do
  echo "Need to upload v$sc"
  STEMCELL_NAME=bosh-stemcell-$sc-$IAAS_TYPE-esxi-ubuntu-trusty-go_agent.tgz
  DIAGNOSTIC_REPORT=$(om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k curl -p /api/v0/diagnostic_report)
  STEMCELL_EXISTS=$(echo $DIAGNOSTIC_REPORT | jq -r --arg STEMCELL_NAME $STEMCELL_NAME '.stemcells | contains([$STEMCELL_NAME])')
  # echo $DIAGNOSTIC_REPORT
  # echo $STEMCELL_EXISTS
  if [ $STEMCELL_EXISTS == "true" ]; then
    echo "Stemcell $sc already exists with Ops Manager, hence skipping this step"
  else
    echo "Downloading stemcell $sc"
    # $PIVNET_CLI login --api-token="$PIVNET_API_TOKEN"

    # set +e
    # RESPONSE=`$PIVNET_CLI releases -p stemcells | grep $SC_VERSION`
    # set -e

    # if [[ -z "$RESPONSE" ]]; then
      wget https://s3.amazonaws.com/bosh-core-stemcells/vsphere/$STEMCELL_NAME
    # else
    #  $PIVNET_CLI download-product-files -p stemcells -r $SC_VERSION -g "*$IAAS_TYPE*" --accept-eula
    # fi

    SC_FILE_PATH=`find ./ -name *.tgz`

    om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-stemcell -s $SC_FILE_PATH
      if [ ! -f "$SC_FILE_PATH" ]; then
          echo "Stemcell file not found!"
      else
        echo "Removing downloaded stemcell $sc"
        rm $SC_FILE_PATH
      fi
  fi
done
