#!/bin/bash
set -eu

echo "Login to PKS API [$UAA_URL]"
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-validation # TBD --ca-cert CERT-PATH


pks cluster ${K8S_CLUSTERNAME}
pks get-credentials ${K8S_CLUSTERNAME}
kubectl config use-context ${K8S_CLUSTERNAME}
kubectl get nodes -o wide

set +eu
appns=$(kubectl get namespace | grep ${K8S_NAMESPACE})
set -eu

if [ -z $appns ]; then
  echo "Creating ${K8S_NAMESPACE} namespace"
  kubectl create namespace ${K8S_NAMESPACE}
else
  echo "${K8S_NAMESPACE} namespace already exists"
fi

wget "${APP_YAML_URL}" -O app.yml
#YELBYML=`cat yelb-lb-harbor-original.yml`
# echo ${YELBYML//"$VALUE_TO_REPLACE"/"$REPLACEMENT_VALUE"} > yelb-lb-harbor.yml
sed -i -e "s/$VALUE_TO_REPLACE/$REPLACEMENT_VALUE/g" app.yml
kubectl apply -f app.yml
kubectl get pods --namespace ${K8S_NAMESPACE}
kubectl get services --namespace ${K8S_NAMESPACE} -o json
# EXT_IP=$(kubectl get services --namespace yelb -o json | jq -r '.items[] | select(.spec.selector.app=="yelb-ui") | .status.loadBalancer.ingress[0].ip')
# echo "Connect a browser to http://${EXT_IP} to load yelb"
