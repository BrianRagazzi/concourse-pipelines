#!/bin/bash

set -eu

# openssl s_client  -servername $NSX_API_MANAGERS \
#                   -connect ${NSX_API_MANAGERS}:443 \
#                   </dev/null 2>/dev/null \
#                   | openssl x509 -text \
#                   >  /tmp/complete_nsx_manager_cert.log
#
 #get IP address for FQDN, required as of NCP 2.1.2
 NSX_API_MANAGER_IP=$(
   getent hosts $NSX_API_MANAGERS | awk '{ print $1 }'
 )
#
# NSX_MANAGER_CERT_ADDRESS=`cat /tmp/complete_nsx_manager_cert.log \
#                         | grep Subject | grep "CN=" \
#                         | awk '{print $NF}' \
#                         | sed -e 's/CN=//g' `
#
# echo "Fully qualified domain name for NSX Manager: $NSX_API_MANAGERS"
# echo "Host name associated with NSX Manager cert: $NSX_MANAGER_CERT_ADDRESS"
#
# # Get all certs from the nsx manager
# openssl s_client -host $NSX_API_MANAGERS \
#                  -port 443 -prexit -showcerts \
#                  </dev/null 2>/dev/null  \
#                  >  /tmp/nsx_manager_all_certs.log
#
# # Get the very last CA cert from the showcerts result
# cat /tmp/nsx_manager_all_certs.log \
#                   |  awk '/BEGIN /,/END / {print }' \
#                   | tail -30                        \
#                   |  awk '/BEGIN /,/END / {print }' \
#                   >  /tmp/nsx_manager_cacert.log
#
# # Strip newlines and replace them with \r\n
# cat /tmp/nsx_manager_cacert.log | tr '\n' '#'| sed -e 's/#/\r\n/g'   > /tmp/nsx_manager_edited_cacert.log
# export NSX_API_CA_CERT=$(cat /tmp/nsx_manager_edited_cacert.log)

if [ "$NSX_PRODUCT_TILE_NAME" == "" ]; then
  export NSX_PRODUCT_TILE_NAME="nsx-cf-cni"
fi

nsx_t_properties=$(
  jq -n \
    --arg nsx_api_managers "$NSX_API_MANAGER_IP" \
    --arg nsx_api_user "$NSX_API_USER" \
    --arg nsx_api_password "$NSX_API_PASSWORD" \
    --arg nsx_api_ca_cert "$NSX_API_CA_CERT" \
    --arg subnet_prefix "$NSX_SUBNET_PREFIX" \
    --arg external_subnet_prefix "$NSX_EXTERNAL_SUBNET_PREFIX" \
    --arg log_dropped_traffic "$NSX_LOG_DROPPED_TRAFFIC" \
    --arg enable_snat "$NSX_ENABLE_SNAT" \
    --arg foundation_name "$NSX_FOUNDATION_NAME" \
    --arg ncp_debug_log "$NSX_NCP_DEBUG_LOG" \
    --arg nsx_auth "$NSX_AUTH_TYPE" \
    --arg nsx_client_cert_cert "$NSX_CLIENT_CERT_CERT" \
    --arg nsx_client_cert_private_key "$NSX_CLIENT_CERT_PRIVATE_KEY" \
    --arg overlay_tz "$OVERLAY_TZ" \
    --arg tier0_router "$TIER0_ROUTER" \
    --arg container_ip_blocks_name "$CONTAINER_IP_BLOCKS_NAME" \
    --arg external_ip_pools_name "$EXTERNAL_IP_POOLS_NAME" \
    '
    {
      ".properties.nsx_api_managers": {
        "value": $nsx_api_managers
      },
      ".properties.nsx_api_ca_cert": {
        "value": $nsx_api_ca_cert
      },
      ".properties.foundation_name": {
        "value": $foundation_name
      },
      ".properties.subnet_prefix": {
        "value": $subnet_prefix
      },
      ".properties.log_dropped_traffic": {
        "value": $log_dropped_traffic
      },
      ".properties.enable_snat": {
        "value": $enable_snat
      },
      ".properties.ncp_debug_log": {
        "value": $ncp_debug_log
      },
      ".properties.overlay_tz": {
        "value": $overlay_tz
      },
      ".properties.tier0_router": {
        "value": $tier0_router
      },
      ".properties.container_ip_blocks": {
        "value": [
          {
            "name": $container_ip_blocks_name
          }
        ]
      },
      ".properties.external_ip_pools": {
        "value": [
          {
            "name": $external_ip_pools_name
          }
        ]
      }
    }
    +


    if $nsx_auth == "simple" then
    {
      ".properties.nsx_auth": {
        "value" : "simple"
      },
      ".properties.nsx_auth.simple.nsx_api_user":  {
        "value": $nsx_api_user
      },
      ".properties.nsx_auth.simple.nsx_api_password":  {
        "value": {
          "secret": $nsx_api_password
        }
      }
    }
    else
    {
      ".properties.nsx_auth": {
        "value": "client_cert"
      },
      ".properties.nsx_auth.client_cert.nsx_api_client_cert": {
        "value": {
          "cert_pem": $nsx_client_cert_cert,
          "private_key_pem": $nsx_client_cert_private_key
        }
      }
    }
    end
    '
)


TILE_RELEASE=$(om-linux -t https://$OPS_MGR_HOST \
                          -u $OPS_MGR_USR \
                          -p $OPS_MGR_PWD \
                          -k available-products \
                          | grep -e "nsx-cf-cni\|VMware-NSX-T")

PRODUCT_NAME=`echo $TILE_RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $TILE_RELEASE | cut -d"|" -f3 | tr -d " "`

om-linux -t https://$OPS_MGR_HOST \
      -u $OPS_MGR_USR \
      -p $OPS_MGR_PWD \
      -k stage-product \
      -p $PRODUCT_NAME \
      -v $PRODUCT_VERSION


om-linux \
  --target https://$OPS_MGR_HOST \
  --username $OPS_MGR_USR \
  --password $OPS_MGR_PWD \
  --skip-ssl-validation \
  configure-product \
  --product-name $PRODUCT_NAME \
  --product-properties "$nsx_t_properties"
