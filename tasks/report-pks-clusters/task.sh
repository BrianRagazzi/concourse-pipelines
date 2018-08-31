#!/bin/bash -eu

set -e


#return pks version
SKIPSSLPARAM=skip-ssl-validation
PKSVER=$(pks --version | cut -d ":" -f 2 | cut -d "." -f 1,2 | tr -d '[:space:]')
if $PKSVER="1.0"
  SKIPSSLPARAM=skip-ssl-verification
fi

echo "Login to PKS API [$UAA_URL]"
#pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-verification # TBD --ca-cert CERT-PATH
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --$SKIPSSLPARAM # TBD --ca-cert CERT-PATH

NUM=$(pks clusters --json | jq '. | length')
echo "$NUM PKS clusters Exist and will be deleted"

ALL_CLUSTERS=$(pks clusters --json | jq -r '.[] | .name')

for name in $ALL_CLUSTERS
do
  # echo "$name"
  #NATIP=$(pks cluster ${name} --json | jq -r '.kubernetes_master_ips[0]')
  CLUSTERINFO=$(pks cluster ${name} --json)
  UUID=$(echo $CLUSTERINFO | jq -r '.uuid')
  NATIP=$(echo $CLUSTERINFO | jq -r '.parameters.kubernetes_master_host')
  CLUSTERSTATE=$(echo $CLUSTERINFO | jq -r '.parameters.kubernetes_master_host')

  echo "Name: ${name} state: $CLUSTERSTATE"
done
