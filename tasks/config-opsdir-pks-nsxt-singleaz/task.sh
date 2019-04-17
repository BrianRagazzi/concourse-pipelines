#!/bin/bash

set -eu

iaas_configuration=$(
  jq -n \
  --arg name "$VCENTER_HOST" \
  --arg vcenter_host "$VCENTER_HOST" \
  --arg vcenter_username "$VCENTER_USR" \
  --arg vcenter_password "$VCENTER_PWD" \
  --arg datacenter "$VCENTER_DATA_CENTER" \
  --arg disk_type "$VCENTER_DISK_TYPE" \
  --arg ephemeral_datastores_string "$EPHEMERAL_STORAGE_NAMES" \
  --arg persistent_datastores_string "$PERSISTENT_STORAGE_NAMES" \
  --arg bosh_vm_folder "$BOSH_VM_FOLDER" \
  --arg bosh_template_folder "$BOSH_TEMPLATE_FOLDER" \
  --arg bosh_disk_path "$BOSH_DISK_PATH" \
  --arg ssl_verification_enabled false \
  --arg nsx_networking_enabled $NSX_NETWORKING_ENABLED \
  --arg nsx_mode "$NSX_MODE" \
  --arg nsx_address "$NSX_ADDRESS" \
  --arg nsx_username "$NSX_USERNAME" \
  --arg nsx_password "$NSX_PASSWORD" \
  --arg nsx_ca_certificate "$NSX_CA_CERTIFICATE" \
  '
  {
    "name": $name,
    "vcenter_host": $vcenter_host,
    "vcenter_username": $vcenter_username,
    "vcenter_password": $vcenter_password,
    "datacenter": $datacenter,
    "disk_type": $disk_type,
    "ephemeral_datastores_string": $ephemeral_datastores_string,
    "persistent_datastores_string": $persistent_datastores_string,
    "bosh_vm_folder": $bosh_vm_folder,
    "bosh_template_folder": $bosh_template_folder,
    "bosh_disk_path": $bosh_disk_path,
    "ssl_verification_enabled": $ssl_verification_enabled,
    "nsx_networking_enabled": $nsx_networking_enabled,
    "nsx_mode": $nsx_mode,
    "nsx_address": $nsx_address,
    "nsx_username": $nsx_username,
    "nsx_password": $nsx_password,
    "nsx_ca_certificate": $nsx_ca_certificate
  }'
)

az_configuration=$(cat <<-EOF
 [
    {
      "name": "$PKS_AZ_1",
      "cluster": "$PKS_AZ_1_CLUSTER_NAME",
      "resource_pool": "$PKS_AZ_1_RP_NAME"
    },
    {
      "name": "$MGMT_AZ",
      "cluster": "$MGMT_AZ_CLUSTER_NAME",
      "resource_pool": "$MGMT_AZ_RP_NAME"
    }
 ]
EOF
)

network_configuration=$(
  jq -n \
    --argjson icmp_checks_enabled $ICMP_CHECKS_ENABLED \
    --arg infra_network_name "$INFRA_NETWORK_NAME" \
    --arg infra_vcenter_network "$INFRA_VCENTER_NETWORK" \
    --arg infra_network_cidr "$INFRA_NW_CIDR" \
    --arg infra_reserved_ip_ranges "$INFRA_EXCLUDED_RANGE" \
    --arg infra_dns "$INFRA_NW_DNS" \
    --arg infra_gateway "$INFRA_NW_GATEWAY" \
    --arg infra_availability_zones "$INFRA_NW_AZS" \
    --arg mgmt_network_name "$MGMT_NETWORK_NAME" \
    --arg mgmt_vcenter_network "$MGMT_VCENTER_NETWORK" \
    --arg mgmt_network_cidr "$MGMT_NW_CIDR" \
    --arg mgmt_reserved_ip_ranges "$MGMT_EXCLUDED_RANGE" \
    --arg mgmt_dns "$MGMT_NW_DNS" \
    --arg mgmt_gateway "$MGMT_NW_GATEWAY" \
    --arg mgmt_availability_zones "$MGMT_NW_AZS" \
    '
    {
      "icmp_checks_enabled": $icmp_checks_enabled,
      "networks": [
        {
          "name": $mgmt_network_name,
          "service_network": true,
          "subnets": [
            {
              "iaas_identifier": $mgmt_vcenter_network,
              "cidr": $mgmt_network_cidr,
              "reserved_ip_ranges": $mgmt_reserved_ip_ranges,
              "dns": $mgmt_dns,
              "gateway": $mgmt_gateway,
              "availability_zone_names": ($mgmt_availability_zones | split(","))
            }
          ]
        }
      ]
    }'
)

director_config=$(cat <<-EOF
{
  "ntp_servers_string": "$NTP_SERVERS",
  "resurrector_enabled": $ENABLE_VM_RESURRECTOR,
  "post_deploy_enabled": true,
  "max_threads": $MAX_THREADS,
  "database_type": "internal",
  "blobstore_type": "local",
  "director_hostname": "$OPS_DIR_HOSTNAME"
}
EOF
)

security_configuration=$(
  jq -n \
    --arg trusted_certificates "$TRUSTED_CERTIFICATES" \
    '
    {
      "trusted_certificates": $trusted_certificates,
      "vm_password_type": "generate"
    }'
)

syslog_configuration=$(
  jq -n \
  --arg  syslog_enabled "$SYSLOG_ENABLED" \
  --arg  syslog_address "$SYSLOG_ADDRESS" \
  --arg  syslog_port "$SYSLOG_PORT" \
  --arg  syslog_tls_enabled $SYSLOG_TLS_ENABLED \
  --arg  syslog_permitted_peer "$SYSLOG_PERMITTED_PEER" \
  --arg  syslog_ssl_ca_certificate "$SYSLOG_SSL_CA_CERTIFICATE" \
  --arg  syslog_transport_protocol "$SYSLOG_TRANSPORT_PROTOCOL" \
  '
  if $syslog_enabled == "true" then
    {
    "enabled": true,
    "address": $syslog_address,
    "transport_protocol": $syslog_transport_protocol,
    "port": $syslog_port
    }
  else
    {
    "enabled": false
    }
  end
  +
  if $syslog_tls_enabled == "true" then
    {
    "tls_enabled": true,
    "ssl_ca_certificate": $syslog_ssl_ca_certificate,
    "permitted_peer": $syslog_permitted_peer
    }
  else
    {
    "tls_enabled": false
    }
  end
  '
)

network_assignment=$(
jq -n \
  --arg infra_availability_zones "$INFRA_NW_AZS" \
  --arg network "$INFRA_NETWORK_NAME" \
  '
  {
  "singleton_availability_zone": {
    "name": ($infra_availability_zones | split(",") | .[0])
  },
  "network": {
    "name": $network
  }
  }'
)

echo "Configuring IaaS, AZ and Director..."
om-linux \
  --target https://$OPS_MGR_HOST \
  --skip-ssl-validation \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  configure-director \
  --iaas-configuration "$iaas_configuration" \
  --director-configuration "$director_config" \
  --az-configuration "$az_configuration"

echo "Configuring Network and Security..."
om-linux \
  --target https://$OPS_MGR_HOST \
  --skip-ssl-validation \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  configure-director \
  --networks-configuration "$network_configuration" \
  --network-assignment "$network_assignment" \
  --security-configuration "$security_configuration" \
  --syslog-configuration "$syslog_configuration"
