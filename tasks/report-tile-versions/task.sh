#!/bin/bash

set -eu

om-linux \
  --target "https://$OPS_MGR_HOST" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation curl --silent --path "/api/v0/deployed/products" > ./proddata.out


PRODUCTS=$(cat ./proddata.out | jq -r '.[]|.type')

for prod in $PRODUCTS
do
  # echo $prod
  installedver=$(cat ./proddata.out | jq -r --arg prod_id "$prod" '.[] | select(.type == $prod_id ) | .product_version')
  latest=$(pivnet-cli --format=json rs --product-slug $prod | jq -r '.[0]|.version')
  echo "$prod - $installedver vs $latest " >> out/report
done

echo "Tile Version report for $OPS_MGR_HOST" >> out/subject
