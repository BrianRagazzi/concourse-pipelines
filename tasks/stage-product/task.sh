#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

echo "staging $PRODUCT_IDENTIFIER"



if [ ! -f "pivnet-product/metadata.json" ]; then
  echo "Getting version from version file"
  VERSION=`cat pivnet-product/version`  
else
  echo "Getting version from PivNet Metadata"
  VERSION=`cat pivnet-product/metadata.json | jq '.Release.Version' | tr -d '"'`
fi

RELEASE_NAME=`om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep $PRODUCT_IDENTIFIER | grep $VERSION`

PRODUCT_NAME=`echo $RELEASE_NAME | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $RELEASE_NAME | cut -d"|" -f3 | tr -d " "`

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION
