#!/bin/bash -eu

# echo "Get NSX-CLI script"
# wget https://storage.googleapis.com/pks-releases/nsx-helper-pkg.tar.gz --no-check-certificate
# tar -xvzf nsx-helper-pkg.tar.gz

#return pks version
#SKIPSSLPARAM=skip-ssl-validation
#return pks version
#PKSVER=$(pks --version)
#PKSVER=${PKSVER:18:3}
# if [ "$PKSVER" == "1.0" ] ; then
#   echo "PKS v1.0 detected, using old syntax"
#   SKIPSSLPARAM=skip-ssl-verification
# fi

echo "Login to PKS API [$UAA_URL]"
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-validation

#PKS_NAT_IP=$(./nsx-cli.sh ipam allocate | cut -d ' ' -f 3)
NUM=0
NUM=$(pks clusters --json | jq '. | length')
echo "$NUM PKS Clusters already Exist"
NUM=$((NUM + 1))

PKS_CLUSTER_NAME=cl$NUM
EXT_HOSTNAME=$(echo $UAA_URL | sed -E 's/api|uaa/'$PKS_CLUSTER_NAME'/g')

#echo "Creating PKS cluster [$PKS_CLUSTER_NAME], master node NAT IP [$PKS_NAT_IP], plan [$PKS_SERVICE_PLAN_NAME], number of workers [$PKS_CLUSTER_NUMBER_OF_WORKERS]"
echo "Creating PKS cluster [$PKS_CLUSTER_NAME], ext name: [$EXT_HOSTNAME], plan [$PKS_SERVICE_PLAN_NAME], number of workers [$PKS_CLUSTER_NUMBER_OF_WORKERS]"
#pks create-cluster "$PKS_CLUSTER_NAME" --external-hostname "$PKS_NAT_IP" --plan "$PKS_SERVICE_PLAN_NAME" --num-nodes "$PKS_CLUSTER_NUMBER_OF_WORKERS" --non-interactive
pks create-cluster "$PKS_CLUSTER_NAME" --external-hostname "$EXT_HOSTNAME" --plan "$PKS_SERVICE_PLAN_NAME" --num-nodes "$PKS_CLUSTER_NUMBER_OF_WORKERS" --non-interactive

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
  # echo "Configuring NAT on NSX-T - [$PKS_NAT_IP] to [$MASTER_IP]"
  # ./nsx-cli.sh nat create-rule "$CLUSTER_UUID" "$MASTER_IP" "$PKS_NAT_IP"
  # echo "Next step: make sure that the external hostname configured for the cluster [$PKS_NAT_IP] is accessible from a DNS/network standpoint, so it can be managed with 'kubectl'"
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
    #echo "cleaning up NSX-T"
    #./nsx-cli.sh cleanup "$CLUSTER_UUID" false
    #./nsx-cli.sh ipam release "$PKS_NAT_IP"
    exit 1
  fi
fi
