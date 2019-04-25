#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

PIVNET_CLI=`find ./pivnet-cli -name "*linux-amd64*"`
chmod +x $PIVNET_CLI

# chmod +x om-cli/om-linux
CMD=om-linux

SC_VERSION=`cat ./pivnet-product/metadata.json | jq -r '.Dependencies[] | select(.Release.Product.Name | contains("Stemcells")) | .Release.Version' | head -1`
SC_SLUG=`cat ./pivnet-product/metadata.json | jq -r '.Dependencies[] | select(.Release.Product.Name | contains("Stemcells")) | .Release.Product.Slug' | head -1`

# echo "looking for stemcell version $SC_VERSION-$IAAS_TYPE"

# The meta data does not always specify the required stemcell, but the report in Ops Manager will...
# In lieu of passing a product name, we'll just find the product that does not yet have a deployed stemcell assigned
if [ -z $SC_VERSION ]; then
  echo "No stemcell specified in manifest, checking in OpsManager"
  if [ -z $PRODUCT_IDENTIFIER ]; then
    echo "Checking staged products that are missing a stemcell"
    SC_VERSION=$(
      om-linux --target https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k \
        curl --silent --path "/api/v0/stemcell_assignments" | \
        jq -r '.products[] | select(.deployed_stemcell_version == null) | .required_stemcell_version'
    )
    SC_OS=$(
      om-linux --target https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k \
        curl --silent --path "/api/v0/stemcell_assignments" | \
        jq -r '.products[] | select(.deployed_stemcell_version == null) | .required_stemcell_os'
    )
  else
    echo "Checking for $PRODUCT_IDENTIFIER stemcell"
    SC_VERSION=$(
      om-linux --target https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k \
        curl --silent --path "/api/v0/stemcell_assignments" | \
        jq --arg prod_id "$PRODUCT_IDENTIFIER" \
        -r '.products[] | select(.identifier == $prod_id) | .required_stemcell_version'
    )
    SC_OS=$(
      om-linux --target https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k \
        curl --silent --path "/api/v0/stemcell_assignments" | \
        jq -r '.products[] | select(.deployed_stemcell_version == null) | .required_stemcell_os'
    )
  fi
fi

if [ -z $SC_OS ]; then
  SC_OS="ubuntu-trusty"
fi

if [ -z $SC_SLUG ]; then
  if [ $SC_OS ="ubuntu-xenial" ]; then
    SC_SLUG="stemcells-ubuntu-xenial"
  else
    SC_SLUG="stemcells"
  fi
fi

STEMCELL_NAME=bosh-stemcell-$SC_VERSION-$IAAS_TYPE-esxi-$SC_OS-go_agent.tgz

DIAGNOSTIC_REPORT=$($CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k curl -p /api/v0/diagnostic_report)

if [ -z $SC_VERSION ] || [ $SC_VERSION = "null" ]; then
  echo "No Stemcell required?"
else
  STEMCELL_EXISTS=$(echo $DIAGNOSTIC_REPORT | jq -r --arg STEMCELL_NAME $STEMCELL_NAME '.stemcells | contains([$STEMCELL_NAME])')
  if [ $STEMCELL_EXISTS == "true" ] ; then
    echo "Stemcell already exists with Ops Manager, hence skipping this step"
  else
    echo "Downloading stemcell $SC_VERSION"
    $PIVNET_CLI login --api-token="$PIVNET_API_TOKEN"

    set +e
    RESPONSE=`$PIVNET_CLI releases -p $SC_SLUG | grep $SC_VERSION`
    set -e

    if [[ -z "$RESPONSE" ]]; then
      wget https://s3.amazonaws.com/bosh-core-stemcells/vsphere/$STEMCELL_NAME
    else
      $PIVNET_CLI download-product-files -p $SC_SLUG -r $SC_VERSION -g "*$IAAS_TYPE*" --accept-eula
    fi

    SC_FILE_PATH=`find ./ -name *.tgz`

    $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-stemcell -s $SC_FILE_PATH
    if [ ! -f "$SC_FILE_PATH" ]; then
        echo "Stemcell file not found!"
    else
      echo "Removing downloaded stemcell $SC_VERSION"
      rm $SC_FILE_PATH
    fi
  fi
fi
