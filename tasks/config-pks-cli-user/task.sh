#!/bin/bash
set -eu

echo "Note - pre-requisite for this task to work:"
echo "- Your PKS API endpoint [$UAA_URL] should be routable and accessible from the Concourse worker(s) network."
echo "- See PKS tile documentation for configuration details for vSphere [https://docs.pivotal.io/runtimes/pks/1-0/installing-pks-vsphere.html#loadbalancer-pks-api]"

echo "Retrieving PKS tile properties from Ops Manager [https://$OPS_MGR_HOST]..."
# get PKS UAA admin credentails from OpsMgr
PRODUCTS=$(om-linux \
  --target "https://$OPS_MGR_HOST" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation curl -p /api/v0/staged/products
  )
PKS_GUID=$(echo "$PRODUCTS" | jq -r '.[] | .guid' | grep pivotal-container-service)
UAA_ADMIN_SECRET=$(om-linux \
  --target "https://$OPS_MGR_HOST" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation curl -p /api/v0/deployed/products/$PKS_GUID/credentials/.properties.pks_uaa_management_admin_client | jq -rc '.credential.value.secret'
  )

if [ -n "$UAA_ADMIN_SECRET" ]; then
  echo "Successfully retrieved admin secret from Ops Manager"
fi

echo "Connecting to PKS UAA server [$UAA_URL]..."
# login to PKS UAA\
uaac target https://$UAA_URL:8443 --skip-ssl-validation
uaac token client get admin --secret $UAA_ADMIN_SECRET

# uaac contexts > contexts.out
set +eu
CHK=$(uaac users | grep $PKS_CLI_USERNAME)
if [ -z "$CHK" ]; then
  echo "Creating new PKS CLI administrator user per PK tile documentation https://docs.pivotal.io/runtimes/pks/1-0/manage-users.html#uaa-scopes"
  uaac user add "$PKS_CLI_USERNAME" --emails "$PKS_CLI_USEREMAIL" -p "$PKS_CLI_PASSWORD"
  echo "PKS CLI administrator user [$PKS_CLI_USERNAME] successfully created."
else
  echo "user [$PKS_CLI_USERNAME] already exists"
fi

uaac member add pks.clusters.admin $PKS_CLI_USERNAME
uaac member add pks.clusters.admin admin
uaac member add uaa.admin $PKS_CLI_USERNAME
set -eu

echo "Next, download the PKS CLI from Pivotal Network and login to the PKS API to create a new K8s cluster [https://docs.pivotal.io/runtimes/pks/1-0/create-cluster.html]"
echo "Example: "
echo "   pks login -a $UAA_URL -u $PKS_CLI_USERNAME -p <pks-cli-password-provided>"
