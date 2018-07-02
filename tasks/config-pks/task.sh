#!/bin/bash

set -eu

#properties changed from 1.0.2 to 1.0.3, have to chec the version staged and assign appropriate properties

RELEASE_NAME=`om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep pivotal-container-service`
PKS_VERSION=`echo $RELEASE_NAME | cut -d"|" -f3 | tr -d " " | cut -d "-" -f1`
PKS_MAJOR_VERSION=`echo $PKS_VERSION | cut -d "." -f1 | cut -d "-" -f1`
PKS_MID_VERSION=`echo $PKS_VERSION | cut -d "." -f2 | cut -d "-" -f1`
PKS_MINOR_VERSION=`echo $PKS_VERSION | cut -d "." -f3 | cut -d "-" -f1`
#expect PKS_VERSION to be 1.0.0, 1.0.1, 1.0.2, 1.0.3... 1.10.1

if [ -z $VCENTER_USR_WORKER ]; then
  VCENTER_USR_WORKER=$VCENTER_USR
fi

if [ -z $VCENTER_PWD_WORKER ]; then
  VCENTER_PWD_WORKER=$VCENTER_PWD
fi

domains="*.${SYSTEM_DOMAIN} *.${UAA_DOMAIN}"
data=$(echo $domains | jq --raw-input -c '{"domains": (. | split(" "))}')
certificates=$(om-linux \
     --target "https://${OPS_MGR_HOST}" \
     --username "$OPS_MGR_USR" \
     --password "$OPS_MGR_PWD" \
     --skip-ssl-validation \
     curl \
     --silent \
     --path "/api/v0/certificates/generate" \
     -x POST \
     -d $data
   )
SSL_CERT=`echo $certificates | jq --raw-output '.certificate'`
SSL_PRIVATE_KEY=`echo $certificates | jq --raw-output '.key'`

pks_network=$(
  jq -n \
    --arg az_1_name "$AZ_1_NAME" \
    --arg infra_network_name "$INFRA_NETWORK_NAME" \
    --arg services_network_name "$SERVICES_NETWORK_NAME" \
  '
  {
    "singleton_availability_zone": {
      "name": $az_1_name
    },
    "other_availability_zones": [
      {
        "name": $az_1_name
      }
    ],
    "network": {
      "name": $infra_network_name
    },
    "service_network": {
      "name": $services_network_name
    }
  }
  '
)

#.properties.cloud_provider.vsphere.vcenter_creds is replaced with
# .properties.cloud_provider.vsphere.vcenter_master_creds in PKS 1.0.3
pks_properties=$(
  jq -n \
    --arg ops "$OPS_MGR_HOST" \
    --arg az_1_name "$AZ_1_NAME" \
    --arg vcenter_host "$VCENTER_HOST" \
    --arg vcenter_usr "$VCENTER_USR" \
    --arg vcenter_pwd "$VCENTER_PWD" \
    --arg vcenter_usr_worker "$VCENTER_USR_WORKER" \
    --arg vcenter_pwd_worker "$VCENTER_PWD_WORKER" \
    --arg vcenter_data_center "$VCENTER_DATA_CENTER" \
    --arg om_data_store "$OM_DATA_STORE" \
    --arg bosh_vm_folder "$BOSH_VM_FOLDER" \
    --arg uaa_url "$UAA_URL" \
    --arg SSL_PRIVATE_KEY "$SSL_PRIVATE_KEY" \
    --arg SSL_CERT "$SSL_CERT" \
    --arg nsx_address "$NSX_ADDRESS" \
    --arg nsx_username "$NSX_USERNAME" \
    --arg nsx_password "$NSX_PASSWORD" \
    --arg az_1_name "$AZ_1_NAME" \
    --arg nsxt_t0_routerid "$NSXT_T0_ROUTERID" \
    --arg nxst_ip_block_id "$NSXT_IP_BLOCK_ID" \
    --arg nsxt_nodes_ip_block_id "$NSXT_NODES_IP_BLOCK_ID"
    --arg nsxt_floating_ip_pool_id "$NSXT_FLOATING_IP_POOL_ID" \
    --arg nsxt_cloud_config_dns "$NSXT_CLOUD_CONFIG_DNS" \
    --arg nsxt_vcenter_cluster "$NSXT_VCENTER_CLUSTER" \
    --arg nsxt_superuser_certificate "$NSXT_SUPERUSER_CERTIFICATE" \
    --arg nsxt_superuser_private_key "$NSXT_SUPERUSER_PRIVATE_KEY" \
    --arg nsxt_telemetry_selector "$TELEMETRY_SELECTOR" \
    --arg syslog_enabled ${SYSLOG_ENABLED:-"false"} \
    --arg syslog_address "$SYSLOG_ADDRESS" \
    --arg syslog_tls_enabled "$SYSLOG_TLS_ENABLED" \
    --arg syslog_port "$SYSLOG_PORT" \
    --arg syslog_ssl_ca_certificate "$SYSLOG_SSL_CA_CERTIFICATE" \
    --arg syslog_transport_protocol "$SYSLOG_TRANSPORT_PROTOCOL" \
    --arg pks_major_version "$PKS_MAJOR_VERSION" \
    --arg pks_mid_version "$PKS_MID_VERSION" \
    --arg pks_minor_version "$PKS_MINOR_VERSION" \
  '
  {
    ".properties.cloud_provider": {
      "value": "vSphere"
    },
    ".properties.cloud_provider.vsphere.vcenter_ip": {
      "value": $vcenter_host
    },
    ".properties.cloud_provider.vsphere.vcenter_dc": {
      "value": $vcenter_data_center
    },
    ".properties.cloud_provider.vsphere.vcenter_ds": {
      "value": $om_data_store
    },
    ".properties.cloud_provider.vsphere.vcenter_vms": {
      "value": $bosh_vm_folder
    },
    ".properties.network_selector": {
      "value": "nsx"
    },
    ".properties.plan1_selector": {
      "value": "Plan Active"
    },
    ".properties.plan1_selector.active.name": {
      "value": "small"
    },
    ".properties.plan1_selector.active.description": {
      "value": "Default small plan for K8s cluster",
    },
    ".properties.plan1_selector.active.az_placement": {
      "value": $az_1_name
    },
    ".properties.plan1_selector.active.authorization_mode": {
      "value": "rbac"
    },
    ".properties.plan1_selector.active.master_vm_type": {
      "value": "medium"
    },
    ".properties.plan1_selector.active.master_persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan1_selector.active.worker_vm_type": {
      "value": "medium"
    },
    ".properties.plan1_selector.active.persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan1_selector.active.worker_instances": {
      "value": 2
    },
    ".properties.plan1_selector.active.errand_vm_type": {
      "value": "micro"
    },
    ".properties.plan1_selector.active.addons_spec": {
      "value": null
    },
    ".properties.plan1_selector.active.allow_privileged_containers": {
      "value": false
    },
    ".properties.plan2_selector": {
      "value": "Plan Active"
    },
    ".properties.plan2_selector.active.name": {
      "value": "medium"
    },
    ".properties.plan2_selector.active.description": {
      "value": "Medium workloads",
    },
    ".properties.plan2_selector.active.az_placement": {
      "value": $az_1_name
    },
    ".properties.plan2_selector.active.authorization_mode": {
      "value": "rbac",
    },
    ".properties.plan2_selector.active.master_vm_type": {
      "value": "large"
    },
    ".properties.plan2_selector.active.master_persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan2_selector.active.worker_vm_type": {
      "value": "medium"
    },
    ".properties.plan2_selector.active.persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan2_selector.active.worker_instances": {
      "value": 3
    },
    ".properties.plan2_selector.active.errand_vm_type": {
      "value": "micro"
    },
    ".properties.plan2_selector.active.addons_spec": {
      "value": null
    },
    ".properties.plan2_selector.active.allow_privileged_containers": {
      "value": false
    },
    ".properties.plan3_selector": {
      "value": "Plan Inactive",
      "optional": false
    },
    ".properties.network_selector.nsx.nsx-t-host": {
      "value":  $nsx_address
    },
    ".properties.network_selector.nsx.credentials": {
      "value": {
        "identity": $nsx_username,
        "password": $nsx_password
      }
    },
    ".properties.network_selector.nsx.nsx-t-ca-cert": {
      "value": ""
    },
    ".properties.network_selector.nsx.vcenter_cluster": {
      "value": $az_1_name
    },
    ".properties.network_selector.nsx.nsx-t-insecure": {
      "value": true
    },
    ".properties.network_selector.nsx.t0-router-id": {
      "value": $nsxt_t0_routerid
    },
    ".properties.network_selector.nsx.ip-block-id": {
      "value": $nxst_ip_block_id
    },
    ".properties.network_selector.nsx.nodes-ip-block-id": {
      "value": $nxst_nodes_ip_block_id
    },
    ".properties.network_selector.nsx.cloud-config-dns": {
      "value": $nsxt_cloud_config_dns
    },
    ".properties.network_selector.nsx.vcenter_cluster": {
      "value": $nsxt_vcenter_cluster
    },
    ".properties.network_selector.nsx.nsx-t-superuser-certificate": {
      "cert.pem": $nsxt_superuser_certificate,
      "private_key_pem": $nsxt_superuser_private_key
    },
    ".properties.telemetry_selector": {
      "value": "disabled"
    },
    ".properties.network_selector.nsx.floating-ip-pool-ids": {
      "value": $nsxt_floating_ip_pool_id
    },
    ".properties.uaa_url": {
      "value": $uaa_url
    },
    ".properties.uaa_pks_cli_access_token_lifetime": {
      "value": 86400
    },
    ".properties.uaa_pks_cli_refresh_token_lifetime": {
      "value": 172800
    },
    ".pivotal-container-service.pks_tls": {
      "value": {
        "private_key_pem": $SSL_PRIVATE_KEY,
        "cert_pem": $SSL_CERT
      }
    }
  }
  +
  if $pks_major_version == "1" and $pks_mid_version == "0" and $pks_minor_version == "3" then
    {
      ".properties.cloud_provider.vsphere.vcenter_master_creds": {
        "value": {
          "identity": $vcenter_usr,
          "password": $vcenter_pwd
         }
       },
       ".properties.cloud_provider.vsphere.vcenter_worker_creds": {
         "value": {
           "identity": $vcenter_usr,
           "password": $vcenter_pwd
         }
       }
     }
  else
     {
       ".properties.cloud_provider.vsphere.vcenter_creds": {
         "value": {
           "identity": $vcenter_usr,
           "password": $vcenter_pwd
         }
       }
     }
  end

  +
  if $syslog_enabled == "true" then
    {
      ".properties.syslog_migration_selector": {
        "value": "enabled"
      },
      ".properties.syslog_migration_selector.enabled.address": {
        "value": $syslog_address
      },
      ".properties.syslog_migration_selector.enabled.tls_enabled": {
        "value": $syslog_tls_enabled
      },
      ".properties.syslog_migration_selector.enabled.port": {
        "value": $syslog_port
      },
      ".properties.syslog_migration_selector.enabled.ca_cert": {
        "value": $syslog_ssl_ca_certificate
      },
      ".properties.syslog_migration_selector.enabled.transport_protocol": {
        "value": $syslog_transport_protocol
      }
    }
  else
    {
      ".properties.syslog_migration_selector": {
        "value": "disabled"
      }
    }
  end

  '
)

om-linux --target "https://${OPS_MGR_HOST}" \
  --skip-ssl-validation \
  --username "${OPS_MGR_USR}" \
  --password "${OPS_MGR_PWD}" \
  configure-product \
  --product-name pivotal-container-service \
  --product-network "$pks_network"

om-linux --target "https://${OPS_MGR_HOST}" \
  --skip-ssl-validation \
  --username "${OPS_MGR_USR}" \
  --password "${OPS_MGR_PWD}" \
  configure-product \
  --product-name pivotal-container-service \
  --product-properties "$pks_properties"
