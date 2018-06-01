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
    },
    {
      "name": "$AZ_2",
      "cluster": "$AZ_2_CLUSTER_NAME",
      "resource_pool": "$AZ_2_RP_NAME"
    },
    {
      "name": "$AZ_3",
      "cluster": "$AZ_3_CLUSTER_NAME",
      "resource_pool": "$AZ_3_RP_NAME"
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
    --arg deployment_network_name "$DEPLOYMENT_NETWORK_NAME" \
    --arg deployment_vcenter_network "$DEPLOYMENT_VCENTER_NETWORK" \
    --arg deployment_network_cidr "$DEPLOYMENT_NW_CIDR" \
    --arg deployment_reserved_ip_ranges "$DEPLOYMENT_EXCLUDED_RANGE" \
    --arg deployment_dns "$DEPLOYMENT_NW_DNS" \
    --arg deployment_gateway "$DEPLOYMENT_NW_GATEWAY" \
    --arg deployment_availability_zones "$DEPLOYMENT_NW_AZS" \
    --arg services_network_name "$SERVICES_NETWORK_NAME" \
    --arg services_vcenter_network "$SERVICES_VCENTER_NETWORK" \
    --arg services_network_cidr "$SERVICES_NW_CIDR" \
    --arg services_reserved_ip_ranges "$SERVICES_EXCLUDED_RANGE" \
    --arg services_dns "$SERVICES_NW_DNS" \
    --arg services_gateway "$SERVICES_NW_GATEWAY" \
    --arg services_availability_zones "$SERVICES_NW_AZS" \
    --arg dynamic_services_network_name "$DYNAMIC_SERVICES_NETWORK_NAME" \
    --arg dynamic_services_vcenter_network "$DYNAMIC_SERVICES_VCENTER_NETWORK" \
    --arg dynamic_services_network_cidr "$DYNAMIC_SERVICES_NW_CIDR" \
    --arg dynamic_services_reserved_ip_ranges "$DYNAMIC_SERVICES_EXCLUDED_RANGE" \
    --arg dynamic_services_dns "$DYNAMIC_SERVICES_NW_DNS" \
    --arg dynamic_services_gateway "$DYNAMIC_SERVICES_NW_GATEWAY" \
    --arg dynamic_services_availability_zones "$DYNAMIC_SERVICES_NW_AZS" \
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
          "name": $deployment_network_name,
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $deployment_vcenter_network,
              "cidr": $deployment_network_cidr,
              "reserved_ip_ranges": $deployment_reserved_ip_ranges,
              "dns": $deployment_dns,
              "gateway": $deployment_gateway,
              "availability_zone_names": ($deployment_availability_zones | split(","))
            }
          ]
        },
        {
          "name": $services_network_name,
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $services_vcenter_network,
              "cidr": $services_network_cidr,
              "reserved_ip_ranges": $services_reserved_ip_ranges,
              "dns": $services_dns,
              "gateway": $services_gateway,
              "availability_zone_names": ($services_availability_zones | split(","))
            }
          ]
        },
        {
          "name": $dynamic_services_network_name,
          "service_network": true,
          "subnets": [
            {
              "iaas_identifier": $dynamic_services_vcenter_network,
              "cidr": $dynamic_services_network_cidr,
              "reserved_ip_ranges": $dynamic_services_reserved_ip_ranges,
              "dns": $dynamic_services_dns,
              "gateway": $dynamic_services_gateway,
              "availability_zone_names": ($dynamic_services_availability_zones | split(","))
            }
          ]
        }
      ]
    }'
)


director_config=$(
  jq -n \
    --arg ntp_servers_string "$NTP_SERVERS" \
    --arg resurrector_enabled "$ENABLE_VM_RESURRECTOR" \
    --arg post_deploy_enabled "true" \
    --arg max_threads "$MAX_THREADS" \
    --arg database_type "internal" \,
    --arg blobstore_type "$BLOBSTORE_TYPE" \
    --arg director_hostname "$OPS_DIR_HOSTNAME" \
    --arg s3_blobstore_endpoint "$S3_BLOBSTORE_ENDPOINT" \
    --arg s3_blobstore_bucket "$S3_BLOBSTORE_BUCKET" \
    --arg s3_blobstore_sig_version "$S3_BLOBSTORE_SIG_VERSION" \
    --arg s3_blobstore_region "$S3_BLOBSTORE_REGION" \
    '
    {
      "ntp_servers_string": $ntp_servers_string,
      "resurrector_enabled": $resurrector_enabled,
      "post_deploy_enabled": $post_deploy_enabled,
      "max_threads": $max_threads,
      "database_type": $database_type,
      "blobstore_type": $blobstore_type,
      "director_hostname": $director_hostname
    }
    +
    if blobstore_type == "s3" then
      {
        "s3_blobstore_options":
          {
            "endpoint": $s3_blobstore_endpoint,
            "bucket_name":"pcf6-bosh",
            "signature_version":"2",
            "region":null
          }
      }
    else
      .
    end
    '
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
echo $director_config

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
