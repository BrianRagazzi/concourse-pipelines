#!/bin/bash

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

# chmod +x om-cli/om-linux
OM_CMD=om-linux
#chmod +x ./jq/jq-linux64
JQ_CMD=jq

BOSH_TASKCHECK_USER=login
BOSH_TASKCHECK_PASS=$(
  om-linux \
  --target https://$OPS_MGR_HOST \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
    --skip-ssl-validation \
    curl --silent --path "/api/v0/deployed/director/credentials/uaa_login_client_credentials" | \
    jq -r '.[] | .value.password'
)


properties_config=$($JQ_CMD -n \
  --arg healthwatch_forwarder_boshhealth_instance_count ${HEALTHWATCH_FORWARDER_BOSHHEALTH_INSTANCE_COUNT:-1} \
  --arg healthwatch_forwarder_boshtasks_instance_count ${HEALTHWATCH_FORWARDER_BOSHTASKS_INSTANCE_COUNT:-2} \
  --arg healthwatch_forwarder_canary_instance_count ${HEALTHWATCH_FORWARDER_CANARY_INSTANCE_COUNT:-2} \
  --arg healthwatch_forwarder_cli_instance_count ${HEALTHWATCH_FORWARDER_CLI_INSTANCE_COUNT:-2} \
  --arg healthwatch_forwarder_foundation_name ${HEALTHWATCH_FORWARDER_FOUNDATION_NAME:-null} \
  --arg healthwatch_forwarder_health_check_az ${HEALTHWATCH_FORWARDER_HEALTH_CHECK_AZ:-null} \
  --arg healthwatch_forwarder_health_check_vm_type ${HEALTHWATCH_FORWARDER_HEALTH_CHECK_VM_TYPE:-null} \
  --arg healthwatch_forwarder_ingestor_instance_count ${HEALTHWATCH_FORWARDER_INGESTOR_INSTANCE_COUNT:-4} \
  --arg healthwatch_forwarder_opsman_instance_count ${HEALTHWATCH_FORWARDER_OPSMAN_INSTANCE_COUNT:-2} \
  --arg healthwatch_mysql_skip_name_resolve ${HEALTHWATCH_MYSQL_SKIP_NAME_RESOLVE:-true} \
  --arg healthwatch_opsman ${HEALTHWATCH_OPSMAN:-"enable"} \
  --arg healthwatch_opsman_enable_url ${HEALTHWATCH_OPSMAN_ENABLE_URL:-null} \
  --arg healthwatch_bosh_taskcheck_username ${BOSH_TASKCHECK_USER} \
  --arg healthwatch_bosh_taskcheck_password ${BOSH_TASKCHECK_PASS} \
  --arg healthwatch_syslog_selector "${HEALTHWATCH_SYSLOG_SELECTOR}" \
  --arg syslog_port ${SYSLOG_PORT} \
  --arg syslog_address ${SYSLOG_ADDRESS} \
  --arg syslog_transport_protocol ${SYSLOG_TRANSPORT_PROTOCOL} \
'{
  ".properties.opsman": {
    "value": $healthwatch_opsman
  },
  ".properties.boshtasks.enable.bosh_taskcheck_username": {
    "value": $healthwatch_bosh_taskcheck_username
  },
  ".properties.boshtasks.enable.bosh_taskcheck_password": {
    "value": {
      "secret": $healthwatch_bosh_taskcheck_password
    }
  }
}
+
if $healthwatch_opsman == "enable" then
{
  ".properties.opsman.enable.url": {
    "value": $healthwatch_opsman_enable_url
  }
}
else .
end
+
{
  ".mysql.skip_name_resolve": {
    "value": $healthwatch_mysql_skip_name_resolve
  },
  ".healthwatch-forwarder.foundation_name": {
    "value": $healthwatch_forwarder_foundation_name
  },
  ".healthwatch-forwarder.ingestor_instance_count": {
    "value": $healthwatch_forwarder_ingestor_instance_count
  },
  ".healthwatch-forwarder.canary_instance_count": {
    "value": $healthwatch_forwarder_canary_instance_count
  },
  ".healthwatch-forwarder.boshhealth_instance_count": {
    "value": $healthwatch_forwarder_boshhealth_instance_count
  },
  ".healthwatch-forwarder.boshtasks_instance_count": {
    "value": $healthwatch_forwarder_boshtasks_instance_count
  },
  ".healthwatch-forwarder.cli_instance_count": {
    "value": $healthwatch_forwarder_cli_instance_count
  },
  ".healthwatch-forwarder.opsman_instance_count": {
    "value": $healthwatch_forwarder_opsman_instance_count
  },
  ".healthwatch-forwarder.health_check_az": {
    "value": $healthwatch_forwarder_health_check_az
  },
  ".healthwatch-forwarder.health_check_vm_type": {
    "value": $healthwatch_forwarder_health_check_vm_type
  },
  ".properties.syslog_selector": {
    "value": $healthwatch_syslog_selector
  },
  ".properties.syslog_selector.active.syslog_address": {
    "value": $syslog_address
  },
  ".properties.syslog_selector.active.syslog_port": {
    "value": $syslog_port
  },
  ".properties.syslog_selector.active.syslog_transport": {
    "value": $syslog_transport_protocol
  }
}'
)

resources_config="{
  \"mysql\": {\"instances\": ${HEALTHWATCH_MYSQL_INSTANCES:-1}, \"instance_type\": { \"id\": \"${HEALTHWATCH_MYSQL_INSTANCE_TYPE:-2xlarge}\"}, \"persistent_disk\": { \"size_mb\": \"${HEALTHWATCH_MYSQL_PERSISTENT_DISK_MB:-102400}\"}},
  \"redis\": {\"instances\": ${HEALTHWATCH_REDIS_INSTANCES:-1}, \"instance_type\": { \"id\": \"${HEALTHWATCH_REDIS_INSTANCE_TYPE:-medium.disk}\"}},
  \"healthwatch-forwarder\": {\"instances\": ${HEALTHWATCH_FORWARDER_INSTANCES:-1}, \"instance_type\": { \"id\": \"${HEALTHWATCH_FORWARDER_INSTANCE_TYPE:-xlarge}\"}, \"persistent_disk\": { \"size_mb\": \"${HEALTHWATCH_FORWARDER_PERSISTENT_DISK_MB:-102400}\"}}
}"

network_config=$($JQ_CMD -n \
  --arg network_name "$NETWORK_NAME" \
  --arg other_azs "$OTHER_AZS" \
  --arg singleton_az "$SINGLETON_JOBS_AZ" \
  --arg service_network_name "$SERVICE_NETWORK_NAME" \
  '
  {
    "network": {
      "name": $network_name
    },
    "other_availability_zones": ($other_azs | split(",") | map({name: .})),
    "singleton_availability_zone": {
      "name": $singleton_az
    },
    "service_network": {
      "name": $service_network_name
    }
  }
  '
)

$OM_CMD \
  --target https://$OPS_MGR_HOST \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-healthwatch \
  --product-network "$network_config"

$OM_CMD \
  --target https://$OPS_MGR_HOST \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-healthwatch \
  --product-resources "$resources_config" \
  --product-properties "$properties_config" \
