#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi


FILE_PATH=`find ./pivnet-product -name *.pivotal`

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-product -p $FILE_PATH
