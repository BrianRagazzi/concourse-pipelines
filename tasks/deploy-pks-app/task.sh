#!/bin/bash
set -eu

echo "Login to PKS API [$UAA_URL]"
pks login -a "$UAA_URL" -u "$PKS_CLI_USERNAME" -p "$PKS_CLI_PASSWORD" --skip-ssl-validation # TBD --ca-cert CERT-PATH

#081718-BPR - Addes sort-by because the results are not always in a logical order.
clustername=$(pks clusters --json |   jq -r -c 'sort_by(.name)[-1] | select(.name | contains("cl")) | .name')


pks cluster ${clustername}
pks get-credentials ${clustername}
kubectl config use-context ${clustername}
kubectl get nodes -o wide

set +eu
yelbns=$(kubectl get namespace | grep yelb)
set -eu

if [ -z $yelbns ]; then
  echo "Creating yelb Namepace"
  kubectl create namespace yelb
else
  echo "yelb namespace already exists"
fi

set +eu
# turn off errors because it will throw one if the deployment does not exist
yelbdeploy=$(kubectl get deploy --namespace yelb | grep yelb-ui)
# echo $yelbdeploy
set -eu

if [ -z $yelbdeploy ]; then
  wget "${YAML_SOURCE}" -O yelb-lb-harbor.yml
  #YELBYML=`cat yelb-lb-harbor-original.yml`
  # echo ${YELBYML//"$VALUE_TO_REPLACE"/"$REPLACEMENT_VALUE"} > yelb-lb-harbor.yml
  sed -i -e "s/$VALUE_TO_REPLACE/$REPLACEMENT_VALUE/g" yelb-lb-harbor.yml
  kubectl apply -f yelb-lb-harbor.yml
  kubectl get pods --namespace yelb
  kubectl get services --namespace yelb
  EXT_IP=$(kubectl get services --namespace yelb -o json | jq -r '.items[] | select(.spec.selector.app=="yelb-ui") | .status.loadBalancer.ingress[0].ip')
  echo "Connect a browser to http://${EXT_IP} to load yelb"
else
  echo "yelb deployment already exists in ${clustername}"
fi
