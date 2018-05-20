#!/bin/bash

set -eu

iaas_configuration=$(
  jq -n \
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
      "name": "$AZ_1",
      "cluster": "$AZ_1_CLUSTER_NAME",
      "resource_pool": "$AZ_1_RP_NAME"
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
    --arg main_network_name "$MAIN_NETWORK_NAME" \
    --arg main_vcenter_network "$MAIN_VCENTER_NETWORK" \
    --arg main_network_cidr "$MAIN_NW_CIDR" \
    --arg main_reserved_ip_ranges "$MAIN_EXCLUDED_RANGE" \
    --arg main_dns "$MAIN_NW_DNS" \
    --arg main_gateway "$MAIN_NW_GATEWAY" \
    --arg main_availability_zones "$MAIN_NW_AZS" \
    '
    {
      "icmp_checks_enabled": $icmp_checks_enabled,
      "networks": [
        {
          "name": $infra_network_name,
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $infra_vcenter_network,
              "cidr": $infra_network_cidr,
              "reserved_ip_ranges": $infra_reserved_ip_ranges,
              "dns": $infra_dns,
              "gateway": $infra_gateway,
              "availability_zone_names": ($infra_availability_zones | split(","))
            }
          ]
        },
        {
          "name": $main_network_name,
          "service_network": true,
          "subnets": [
            {
              "iaas_identifier": $main_vcenter_network,
              "cidr": $main_network_cidr,
              "reserved_ip_ranges": $main_reserved_ip_ranges,
              "dns": $main_dns,
              "gateway": $main_gateway,
              "availability_zone_names": ($main_availability_zones | split(","))
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
  --security-configuration "$security_configuration"
