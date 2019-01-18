#!/bin/bash

set -eu

printf "Waiting for %s to come up" "$OPS_MGR_HOST"
 until $(curl --output /dev/null --silent --head --fail -k https://${OPS_MGR_HOST}); do
  printf '.'
  sleep 5
 done
printf '\n'

file_path=`find ./om-backup-artifact/ -name installation-*.zip`

om-linux --target "https://${OPS_MGR_HOST}" \
  --skip-ssl-validation \
  --request-timeout 86400 \
  import-installation \
  --installation "${file_path}" \
  --decryption-passphrase "${OPSMAN_PASSPHRASE}"
