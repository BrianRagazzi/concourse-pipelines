#!/bin/bash
if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

echo "Login to PKS API [$UAA_URL]"
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-validation # TBD --ca-cert CERT-PATH

#081718-BPR - Addes sort-by because the results are not always in a logical order.
#clustername=$(pks clusters --json |   jq -r -c 'sort_by(.name)[-1] | select(.name | contains("cl")) | .name')


pks cluster $PKS_CLUSTER_NAME
pks get-credentials $PKS_CLUSTER_NAME
kubectl config use-context $PKS_CLUSTER_NAME
kubectl get nodes -o wide

set +eu
ns=$(kubectl get namespace | grep $NAMESPACE)
set -eu

if [ -z $ns ]; then
  echo "Creating $NAMESPACE Namepace"
  kubectl create namespace $NAMESPACE
else
  echo "$NAMESPACE namespace already exists"
fi

# set +eu
# # turn off errors because it will throw one if the deployment does not exist
# testdeploy=$(kubectl get deploy --namespace $NAMESPACE | grep yelb-ui)
# # echo $yelbdeploy
# set -eu
#
# if [ -z $yelbdeploy ]; then
wget "${YAML_SOURCE}" -O app.yml
#YELBYML=`cat yelb-lb-harbor-original.yml`
# echo ${YELBYML//"$VALUE_TO_REPLACE"/"$REPLACEMENT_VALUE"} > yelb-lb-harbor.yml
#sed -i -e "s/$VALUE_TO_REPLACE/$REPLACEMENT_VALUE/g" app.yml
#echo "attempting to apply yml"
kubectl delete -f app.yml -n $NAMESPACE
echo "waiting 10s for services to stop and pods to terminate"
sleep 10s # wait a sec for the loadbalancer to finisb
kubectl get pods --namespace $NAMESPACE
kubectl get services --namespace $NAMESPACE
# EXT_IP=$(kubectl get services --namespace $NAMESPACE -o json | jq -r '.items[] | select(.spec.selector.app=="yelb-ui") | .status.loadBalancer.ingress[0].ip')
#EXT_IP=$(kubectl get services --namespace $NAMESPACE -o json | jq -r $EXT_IP_SELECTOR)
#echo "Connect a browser to http://${EXT_IP}"
# else
#   echo "yelb deployment already exists in $PKS_CLUSTER_NAME"
# fi
