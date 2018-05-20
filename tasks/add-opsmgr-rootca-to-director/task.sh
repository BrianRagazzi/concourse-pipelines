#!/bin/bash

set -eu

OPSMGR_CA_CERT=$(
  om-linux \
  -t https://$OPS_MGR_HOST \
  -u $OPS_MGR_USR \
  -p $OPS_MGR_PWD \
  -k curl -p /api/v0/security/root_ca_certificate | \
   jq --raw-output '.root_ca_certificate_pem' )


if [-n ${TRUSTED_CERTIFICATES}]; then
  TRUSTED_CERTIFICATES="$TRUSTED_CERTIFICATES"'\n'"${OPSMGR_CA_CERT}"
else
  TRUSTED_CERTIFICATES="$OPSMGR_CA_CERT"
fi

# echo $TRUSTED_CERTIFICATES

  security_configuration=$(
    jq -n \
      --arg trusted_certificates "$TRUSTED_CERTIFICATES" \
      '
      {
        "trusted_certificates": $trusted_certificates
      }'
  )

#echo "$security_configuration"
echo "Configuring Network and Security..."
om-linux \
    --target https://$OPS_MGR_HOST \
    --skip-ssl-validation \
    --username "$OPS_MGR_USR" \
    --password "$OPS_MGR_PWD" \
    configure-director \
    --security-configuration "$security_configuration"
