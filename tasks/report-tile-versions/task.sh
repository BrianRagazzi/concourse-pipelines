#!/bin/bash

set -eu

om-linux \
  --target "https://$OPS_MGR_HOST" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation curl --silent --path "/api/v0/deployed/products" > ./proddata.out

pivnet-cli login --api-token="$PIVNET_API_TOKEN"
PRODUCTS=$(cat ./proddata.out | jq -r '.[]|.type')
echo "<!DOCTYPE html>" > out/report
echo "<html><head><meta charset="""utf-8"""/></head><body><table><tr><th>Prod</th><th>installed version</th><th>latest version</th></tr>" >> out/report

for prod in $PRODUCTS
do
  # echo $prod
  installedver=$(cat ./proddata.out | jq -r --arg prod_id "$prod" '.[] | select(.type == $prod_id ) | .product_version')
  latest=$(pivnet-cli --format=json rs --product-slug $prod | jq -r '.[0]|.version')
  #echo "$prod - $installedver vs $latest " >> out/report
  echo "<tr><td>$prod</td><td>$installedver</td><td>$latest</td></tr>" >> out/report
done

echo "</table></body></html>" >> out/report
echo "Tile Version report for $OPS_MGR_HOST" >> out/subject

cat > out/headers <<'EOF'
MIME-version: 1.0
Content-Type: text/html; charset="UTF-8
EOF
