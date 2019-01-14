#!/bin/bash
set -eu

echo "Login to PKS API [$UAA_URL]"
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-validation # TBD --ca-cert CERT-PATH


pks cluster ${k8s_clustername}
pks get-credentials ${k8s_clustername}
kubectl config use-context ${k8s_clustername}
kubectl get nodes -o wide

set +eu
appns=$(kubectl get namespace | grep ${k8s_namespace})
set -eu

if [ -z $appns ]; then
  echo "Creating ${k8s_namespace} namespace"
  kubectl create namespace ${k8s_namespace}
else
  echo "${k8s_namespace} namespace already exists"
fi

wget "${APP_YAML_URL}" -O app.yml
#YELBYML=`cat yelb-lb-harbor-original.yml`
# echo ${YELBYML//"$VALUE_TO_REPLACE"/"$REPLACEMENT_VALUE"} > yelb-lb-harbor.yml
sed -i -e "s/$VALUE_TO_REPLACE/$REPLACEMENT_VALUE/g" app.yml
kubectl apply -f app.yml
kubectl get pods --namespace ${k8s_namespace}
kubectl get services --namespace ${k8s_namespace} -o json
# EXT_IP=$(kubectl get services --namespace yelb -o json | jq -r '.items[] | select(.spec.selector.app=="yelb-ui") | .status.loadBalancer.ingress[0].ip')
# echo "Connect a browser to http://${EXT_IP} to load yelb"
