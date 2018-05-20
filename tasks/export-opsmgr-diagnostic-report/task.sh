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

function main() {

  local cwd
  cwd="${1}"

   om-linux --target "https://${OPS_MGR_HOST}" \
     --skip-ssl-validation \
     --username "${OPS_MGR_USR}" \
     --password "${OPS_MGR_PWD}" \
     curl --path /api/v0/diagnostic_report \
     > "${cwd}/diagnostic-report/exported-diagnostic-report.json"
}

main "${PWD}"
