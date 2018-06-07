#!/bin/bash
set -eu


# Delete Active OpsMan
# resource_pool_path=$(govc find . -name ${GOVC_RESOURCE_POOL} | grep -i resource )
possible_opsmans=$(govc find "$GOVC_RESOURCE_POOL" -type m -guest.ipAddress ${OPSMAN_IP} -runtime.powerState poweredOn)

for opsman in ${possible_opsmans}; do
  network="$(govc vm.info -r=true -json ${opsman} | jq -r '.VirtualMachines[0].Guest.Net[0].Network')"
  currname=$(govc vm.info -vm.ipath=${opsman} --json | jq -r '.VirtualMachines[0].Name')
  datever=$(date +"%y%m%d%H%M%S")
  newname=$currname-backup-$datever
  if [[ ${network} == ${GOVC_NETWORK} || ${network} == "" ]]; then
    echo "Powering off and renaming ${opsman}..."
    set +e
    govc vm.power -vm.ipath=${opsman} -off
    set -e
    # govc vm.destroy -vm.ipath=${opsman}
    govc vm.change -vm.ipath=${opsman} -name=${newname}
  fi
done
