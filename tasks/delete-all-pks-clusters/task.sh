#!/bin/bash -eu

set -e

# echo "Get NSX-CLI script"
# wget https://storage.googleapis.com/pks-releases/nsx-helper-pkg.tar.gz --no-check-certificate
# tar -xvzf nsx-helper-pkg.tar.gz

pks --version

echo "Login to PKS API [$UAA_URL]"
#pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-verification # TBD --ca-cert CERT-PATH
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-validation # TBD --ca-cert CERT-PATH
NUM=$(pks clusters --json | jq '. | length')
echo "$NUM PKS clusters Exist and will be deleted"

ALL_CLUSTERS=$(pks clusters --json | jq -r '.[] | .name')

for name in $ALL_CLUSTERS
do
  # echo "$name"
  UUID=$(pks cluster ${name} --json | jq -r '.uuid')
  echo "Cluster UUID: $UUID"
  #NATIP=$(pks cluster ${name} --json | jq -r '.kubernetes_master_ips[0]')
  # NATIP=$(pks cluster ${name} --json | jq -r '.parameters.kubernetes_master_host')


  echo "Deleting PKS cluster [$name]..."
  pks delete-cluster "$name" --non-interactive  #non-interactive parame req'd for PKS CLI 1.1+

  echo "Monitoring the deletion status for PKS cluster [$name]"
  in_progress_state="in progress"
  cluster_state="$in_progress_state"

  TIMER=0
  while [[ "$cluster_state" == "$in_progress_state" ]]; do
    cluster_state=$(pks cluster "$name" --json | jq -rc '.last_action_state')
    echo "${cluster_state}...waited ${TIMER} seconds total"
    sleep 30
    let TIMER=$TIMER+30
  done
  # echo $UUID

  cluster_exists=$(pks clusters --json | jq -rc '.[].name')

  if [[ "$cluster_exists" == "" ]]; then
    echo "Successfully deleted cluster [$name]"
    echo "Current list of PKS clusters:"
    pks clusters --json
  else
    last_action_description=$(pks cluster "$name" --json | jq -rc '.last_action_description')
    echo "Error deleting cluster [$name], last_action_state=[$cluster_state], last_action_description=[$last_action_description]"
  fi

  # echo "cleaning up NSX-T"
  # set +e
  # ./nsx-cli.sh cleanup "$UUID" false
  # sleep 10
  # ./nsx-cli.sh cleanup "$UUID" false
  # sleep 5
  # ./nsx-cli.sh ipam release "$NATIP"
  # set -e
done
