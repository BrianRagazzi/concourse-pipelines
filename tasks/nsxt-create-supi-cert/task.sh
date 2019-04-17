#!/bin/bash

set -eu

NODE_ID=$(cat /proc/sys/kernel/random/uuid)

# Create Certificate
openssl req \
        -newkey rsa:2048 \
        -x509 \
        -nodes \
        -keyout "$NSX_SUPERUSER_KEY_FILE" \
        -new \
        -out "$NSX_SUPERUSER_CERT_FILE" \
        -subj /CN=pks-nsx-t-superuser \
        -extensions client_server_ssl \
        -config <(
                cat /etc/ssl/openssl.cnf \
                <(printf '[client_server_ssl]\nextendedKeyUsage = clientAuth\n')
                ) \
        -sha256 \
        -days $DAYS_VALID

#Register the Certificate - Create Request
cert_request=$(cat <<END
  {
  "display_name": "$PI_NAME",
  "pem_encoded": "$(awk '{printf "%s\\n", $0}' $NSX_SUPERUSER_CERT_FILE)"
  }
END
)

#Register the Certificate - POST Request
CERTIFICATE_ID=$(curl -k -X POST \
    "https://${NSX_API_MANAGERS}/api/v1/trust-management/certificates?action=import" \
    -u "$NSX_API_USER:$NSX_API_PASSWORD" \
    -H 'content-type: application/json' \
    -d "$cert_request" \
    | jq -r '.results[]|.id'
)


#Register Pricipal Identity - Create Request
pi_request=$(cat <<END
  {
    "display_name": "$PI_NAME",
    "name": "$PI_NAME",
    "permission_group": "superusers",
    "certificate_id": "$CERTIFICATE_ID",
    "node_id": "$NODE_ID"
  }
END
)

#Register Pricipal Identity - POST Request
curl -k -X POST \
  "https://${NSX_API_MANAGERS}/api/v1/trust-management/principal-identities" \
  -u "$NSX_API_USER:$NSX_API_PASSWORD" \
  -H 'content-type: application/json' \
  -d "$pi_request"

# Verify Certificate and Key
VERIFY_DISPLAYNAME=$(curl -k -X GET \
  "https://${NSX_API_MANAGER}/api/v1/trust-management/principal-identities" \
  --cert $(pwd)/"$NSX_SUPERUSER_CERT_FILE" \
  --key $(pwd)/"$NSX_SUPERUSER_KEY_FILE" \
  | jq -r '.display_name'
  )

if [$VERIFY_DISPLAYNAME == "pks-nsx-t-superuser"] then
  echo "Successfully created Super User Principal Identity"
fi

cp $NSX_SUPERUSER_CERT_FILE ./cert-files/
cp $NSX_SUPERUSER_KEY_FILE ./cert-files/
