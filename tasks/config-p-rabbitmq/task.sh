#!/bin/bash

set -eu

export ROOT_DIR=`pwd`
source $ROOT_DIR/pipelines-repo/functions/copy_binaries.sh
source $ROOT_DIR/pipelines-repo/functions/check_versions.sh

check_bosh_version
check_available_product_version "p-rabbitmq"

om \
    -t $OPS_MGR_HOST \
    -u $OPS_MGR_USR \
    -p $OPS_MGR_PWD  \
    -k stage-product \
    -p $PRODUCT_NAME \
    -v $PRODUCT_VERSION

check_staged_product_guid "p-rabbitmq"

prod_network=$(
  jq -n \
    --arg network_name "$NETWORK_NAME" \
    --arg service_network_name "$SERVICE_NETWORK_NAME" \
    --arg other_azs "$OTHER_AZS" \
    --arg singleton_az "$SINGLETON_JOBS_AZ" \
    '
    {
      "service_network": {
        "name": $service_network_name
      },
      "network": {
        "name": $network_name
      },
      "other_availability_zones": ($other_azs | split(",") | map({name: .})),
      "singleton_availability_zone": {
        "name": $singleton_az
      }
    }
    '
)


has_odb_plan_vm_type=$(echo $STAGED_PRODUCT_PROPERTIES | jq . | grep ".properties.on_demand_broker_plan.*rabbitmq_vm_type" | wc -l || true)
has_odb_plan_disk_type=$(echo $STAGED_PRODUCT_PROPERTIES | jq . |grep ".properties.on_demand_broker_plan.*rabbitmq_persistent_disk_type" | wc -l || true)

prod_properties=$(
  jq -n \
    --arg tile_rabbit_admin_user "$TILE_RABBIT_ADMIN_USER" \
    --arg tile_rabbit_admin_passwd "$TILE_RABBIT_ADMIN_PASSWD" \
    --arg tile_rabbit_on_demand_plan_1_instance_quota "$TILE_RABBIT_ON_DEMAND_PLAN_1_INSTANCE_QUOTA" \
    --arg singleton_az "$SINGLETON_JOBS_AZ" \
    --arg syslog_selector "$SYSLOG_SELECTOR" \
    --arg syslog_protocol "$SYSLOG_PROTOCOL" \
    --arg syslog_host "$SYSLOG_HOST" \
    --arg syslog_port "$SYSLOG_PORT" \
    '
    {
      ".rabbitmq-server.server_admin_credentials": {
        "value": {
          "identity": $tile_rabbit_admin_user,
          "password": $tile_rabbit_admin_passwd
        }
      },
      ".properties.on_demand_broker_plan_1_cf_service_access": {
        "value": "enable"
      },
      ".properties.on_demand_broker_plan_1_instance_quota": {
        "value": $tile_rabbit_on_demand_plan_1_instance_quota
      },
      ".properties.on_demand_broker_plan_1_rabbitmq_az_placement": {
        "value": [$singleton_az]
      },
      ".properties.on_demand_broker_plan_1_disk_limit_acknowledgement": {
        "value": ["acknowledge"]
      },
      ".properties.disk_alarm_threshold": {
        "value": "mem_relative_1_0"
      }
    }
    +
    if $syslog_selector=="true" then
    {
      ".properties.syslog_selector": {
        "value": "enabled"
      },
      ".properties.syslog_selector.enabled.syslog_transport": {
        "value": "$SYSLOG_PROTOCOL"
      },
      ".properties.syslog_selector.enabled.address": {
        "value": "$SYSLOG_HOST"
      },
      ".properties.syslog_selector.enabled.port": {
        "value": $SYSLOG_PORT
      }
    }
    else
    {
      ".properties.syslog_selector": {
        "value": "No"
      }
    }
    '
)



prod_resources=$(cat <<-EOF
{
  "rabbitmq-haproxy": {
    "instances" : $TILE_RABBIT_PROXY_INSTANCES
  },
  "rabbitmq-server": {
    "instances" : $TILE_RABBIT_SERVER_INSTANCES
  }
}
EOF
)

om-linux -t https://$OPS_MGR_HOST \
  -u $OPS_MGR_USR \
  -p $OPS_MGR_PWD \
  -k configure-product \
  -n $PRODUCT_NAME \
  -pn "$prod_network" \
  -pr "$prod_resources"


om-linux -t https://$OPS_MGR_HOST \
  -u $OPS_MGR_USR \
  -p $OPS_MGR_PWD \
  -k configure-product \
  -n $PRODUCT_NAME \
  -p "$prod_properties" \
