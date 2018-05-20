#!/bin/bash -eu

#!/usr/bin/env bash


datever=$(date +"%y%m%d%H%M%S")

om-linux \
    -t https://$OPS_MGR_HOST \
    -u $OPS_MGR_USR \
    -p $OPS_MGR_PWD \
    -k --request-timeout 7200 \
    export-installation \
    --output-file om-installation/installation-${datever}.zip
