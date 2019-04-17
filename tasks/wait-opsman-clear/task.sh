#!/bin/bash

set -eu

# Copyright 2017-Present Pivotal Software, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#This script polls ops mgr waiting for pending changes and running installs to be empty before beginning
#POLL_INTERVAL controls how quickly the script will poll ops mgr for changes to pending changes/running installs

POLL_INTERVAL=30
function main() {

  local cwd
  cwd="${1}"

  set +e
  while :
  do

      om-linux --target "https://${OPS_MGR_HOST}" \
           --skip-ssl-validation \
           --username "${OPS_MGR_USR}" \
           --password "${OPS_MGR_PWD}" \
            curl -path /api/v0/staged/pending_changes > changes-status.txt

      if [[ $? -ne 0 ]]; then
        echo "Could not login to ops man"
        cat changes-status.txt
        exit 1
      fi

      om-linux --target "https://${OPS_MGR_HOST}" \
           --skip-ssl-validation \
           --username "${OPS_MGR_USR}" \
           --password "${OPS_MGR_PWD}" \
           curl -path /api/v0/installations > running-status.txt

      if [[ $? -ne 0 ]]; then
        echo "Could not login to ops man"
        cat running-status.txt
        exit 1
      fi

      #grep "action" changes-status.txt
      PENDING_CHANGES=$(cat changes-status.txt | jq -r '.product_changes[] | select(.action!="unchanged")')


      if [[ -z $PENDING_CHANGES ]]; then
        echo "No pending changes"
        RUNNING_STATUS=$(cat running-status.txt | jq -e -r '.installations[0] | select(.status=="running")')
        if [ -z ${RUNNING_STATUS} ]; then
            echo "No running installs detected. Proceeding"
            exit 0
        fi
        echo "Pending changes or running installs detected. Waiting"
        sleep $POLL_INTERVAL
      else
        echo "There are pending changes, aborting"
        exit 1
      fi


  done
  set -e
}

main "${PWD}"
