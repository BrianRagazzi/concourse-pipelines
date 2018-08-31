#!/bin/bash -eu

set -e

OUTFILE=out/report

echo "<!DOCTYPE html>" > OUTFILE
echo "<html><head><meta charset="""utf-8"""/></head><body>" >> $OUTFILE

echo "<b>Report for PKS on $UAA_URL</b><br>" >> OUTFILE
SKIPSSLPARAM=skip-ssl-validation
#return pks version
PKSVER=$(pks --version)
PKSVER=${PKSVER:18:3}
if [ "$PKSVER" == "1.0" ] ; then
  echo "PKS v1.0 detected, using old syntax"
  SKIPSSLPARAM=skip-ssl-verification
fi

echo "Login to PKS API [$UAA_URL]"
#pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-verification # TBD --ca-cert CERT-PATH
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --$SKIPSSLPARAM # TBD --ca-cert CERT-PATH

NUM=$(pks clusters --json | jq '. | length')
echo "$NUM PKS clusters Exist"

ALL_CLUSTERS=$(pks clusters --json | jq -r '.[] | .name')

for name in $ALL_CLUSTERS
do
  # echo "$name"
  #NATIP=$(pks cluster ${name} --json | jq -r '.kubernetes_master_ips[0]')
  CLUSTERINFO=$(pks cluster ${name} --json)
  UUID=$(echo $CLUSTERINFO | jq -r '.uuid')
  NATIP=$(echo $CLUSTERINFO | jq -r '.parameters.kubernetes_master_host')
  CLUSTERSTATE=$(echo $CLUSTERINFO | jq -r '.last_action_state')

  echo "<br><table><tr><th>Cluster Name</th><th>UUID</th><th>NAT IP</th><th>State</th></tr>"  >> $OUTFILE
  echo "<tr><td>${name}</td><td>$UUID</td><td>$NATIP</td><td>$CLUSTERSTATE</td></tr>" >> $OUTFILE
  echo "<tr><td colspan=4 align=center><b>Services</b></td><tr>" >> $OUTFILE
  echo "<tr><td colspan=4>" >> $OUTFILE
  echo "<table width=100%><tr align=left><th>Namespace</th><th>Name</th><th>Type</th><th>Cluster IP</th><th>External IP</th><th>First Port</th></tr>" >> $OUTFILE
  #echo "Name: ${name} state: $CLUSTERSTATE"
  #<table><tr><th>Product</th><th>Installed Version</th><th>Latest Version</th></tr>
  pks get-credentials ${name}
  kubectl config use-context ${name}
  # kubectl get services --all-namespaces > ${name}-services.txt
  # kubectl get services --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace)\t\(.metadata.name)\t\(.spec.type)\t\(.spec.clusterIP)\t\(.status.loadBalancer.ingress[0].ip)\t\(.spec.ports[0].port)\/\(.spec.ports[0].protocol)"'
  kubectl get services --all-namespaces -o json | jq -r '.items[] | "<tr><td>\(.metadata.namespace)<\/td><td>\(.metadata.name)<\/td><td>\(.spec.type)<\/td><td>\(.spec.clusterIP)<\/td><td>\(.status.loadBalancer.ingress[0].ip)<\/td><td>\(.spec.ports[0].port)\/\(.spec.ports[0].protocol)<\/td><\/tr>"' >> $OUTFILE

  echo "</table></td></tr><br><br>" >> $OUTFILE
done
echo "</body></html>" >> $OUTFILE

echo "K8s clusters and Services - $UAA_URL" >> out/subject

cat > out/headers <<'EOF'
MIME-version: 1.0
Content-Type: text/html; charset="UTF-8"
EOF
