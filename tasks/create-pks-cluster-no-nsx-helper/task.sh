#!/bin/bash -eu


#return pks version
SKIPSSLPARAM=skip-ssl-validation

echo "Login to PKS API [$UAA_URL]"
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --$SKIPSSLPARAM # TBD --ca-cert CERT-PATH

NUM=0
NUM=$(pks clusters --json | jq '. | length')
echo "$NUM PKS Clusters already Exist"
NUM=$((NUM + 1))

PKS_CLUSTER_NAME=testcluster$NUM

echo "Creating PKS cluster [$PKS_CLUSTER_NAME], master node NAT IP [$PKS_NAT_IP], plan [$PKS_SERVICE_PLAN_NAME], number of workers [$PKS_CLUSTER_NUMBER_OF_WORKERS]"
pks create-cluster "$PKS_CLUSTER_NAME" --external-hostname "$PKS_CLUSTER_EXT_HOSTNAME" --plan "$PKS_SERVICE_PLAN_NAME" --num-nodes "$PKS_CLUSTER_NUMBER_OF_WORKERS" --non-interactive

echo "Monitoring the creation status for PKS cluster [$PKS_CLUSTER_NAME]:"
in_progress_state="in progress"
succeeded_state="succeeded"
cluster_state="$in_progress_state"


TIMER=0
while [[ "$cluster_state" == "$in_progress_state" ]]; do
  cluster_state=$(pks cluster "$PKS_CLUSTER_NAME" --json | jq -rc '.last_action_state')
  echo "${cluster_state}...waited $(date -d@$TIMER -u +%H:%M:%S) total"
  sleep 30
  let TIMER=$TIMER+30
done

last_action_description=$(pks cluster "$PKS_CLUSTER_NAME" --json | jq -rc '.last_action_description')
CLUSTER_UUID=$(pks cluster "$PKS_CLUSTER_NAME" --json | jq -rc '.uuid')

if [[ "$cluster_state" == "$succeeded_state" ]]; then
  echo "Successfully created cluster [$PKS_CLUSTER_NAME], last_action_state=[$cluster_state], last_action_description=[$last_action_description]"
  pks cluster "$PKS_CLUSTER_NAME"
  MASTER_IP=$(pks cluster "$PKS_CLUSTER_NAME" --json | jq -rc '.kubernetes_master_ips[0]')
  echo "Next step: make sure that the external hostname configured for the cluster [$PKS_CLUSTER_EXT_HOSTNAME] resolves to [$MASTER_IP]"
else
  echo "Error creating cluster [$PKS_CLUSTER_NAME], last_action_state=[$cluster_state], last_action_description=[$last_action_description]"
  if [[ "$PKS_KEEP_FAILED_CLUSTER_ALIVE" == "true" ]]; then
    echo "Leaving cluster intact for debugging"
    # wget https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-3.0.1-linux-amd64
    # ln -s bosh-cli-3.0.1-linux-amd64 bosh
    # chmod +x bosh
    exit 1
  else
    echo "Tearing down failed cluster"
    pks delete-cluster "$PKS_CLUSTER_NAME" --non-interactive
    cluster_state="$in_progress_state"
    while [[ "$cluster_state" == "$in_progress_state" ]]; do
      cluster_state=$(pks cluster "$PKS_CLUSTER_NAME" --json | jq -rc '.last_action_state')
      echo "${cluster_state}...waiting"
      sleep 30
    done
    exit 1
  fi
fi