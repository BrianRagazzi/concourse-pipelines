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

CF_GUID=$(
  om-linux \
    --target https://$OPS_MGR_HOST \
    --username "$OPS_MGR_USR" \
    --password "$OPS_MGR_PWD" \
    --skip-ssl-validation \
    curl --silent --path "/api/v0/deployed/products" | \
    jq -r '.[] | .installation_name' | grep cf- | tail -1
)
export CF_GUID=$CF_GUID

SYS_DOMAIN=$(
  om-linux \
  --target https://$OPS_MGR_HOST \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
    --skip-ssl-validation \
    curl --silent --path "/api/v0/staged/products/${CF_GUID}/properties" | \
    jq --raw-output '.[] | .[".cloud_controller.system_domain"].value'
)
echo api.$SYS_DOMAIN

cf login -a https://api.$SYS_DOMAIN -u $BM_UAA_USERNAME -p $BM_UAA_PASSWORD --skip-ssl-validation -o system -s system

BM_TRAFFIC_CONTROLLER_URL=$(cf curl /v2/info | jq .doppler_logging_endpoint)

BM_UAA_URL=$(cf curl /v2/info | jq .token_endpoint)

properties_config=$($JQ_CMD -n \
  --arg bm_subscription_id ${BM_SUBSCRIPTION_ID:-"bluemedora-nozzle"} \
  --arg bm_insecure_ssl_skip_verify ${BM_INSECURE_SSL_SKIP_VERIFY:-"true"} \
  --arg bm_idle_timeout_seconds ${BM_IDLE_TIMEOUT_SECONDS:-"60"} \
  --arg bm_metric_cache_duration_seconds ${BM_METRIC_CACHE_DURATION_SECONDS:-"300"}
  --arg bm_uaa_url ${BM_UAA_URL} \
  --arg bm_uaa_username ${BM_UAA_USERNAME} \
  --arg bm_uaa_password ${BM_UAA_PASSWORD} \
'{
  ".properties.bm_idle_timeout_seconds": {
    "value": $bm_idle_timeout_seconds
  },
  ".properties.bm_insecure_ssl_skip_verify": {
    "value": $bm_insecure_ssl_skip_verify
  },
  ".properties.bm_metric_cache_duration_seconds": {
    "value": $bm_metric_cache_duration_seconds
  },
  ".properties.bm_subscription_id": {
    "value": $bm_subscription_id
  },
  ".properties.bm_traffic_controller_url": {
    "value": $bm_traffic_controller_url
  },
  ".properties.bm_uaa_password": {
    "value": $bm_uaa_password
  },
  ".properties.bm_uaa_url": {
    "value": $bm_uaa_url
  }
  ".properties.bm_uaa_username": {
    "value": $bm_uaa_username
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
  --product-name blue-medora-firehose-nozzle \
  --product-properties "$properties_config" \
