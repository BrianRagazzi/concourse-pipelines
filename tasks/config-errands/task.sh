#!/bin/bash

set -eu

enabled_errands=$(
  om-linux \
    --target "https://${OPS_MGR_HOST}" \
    --skip-ssl-validation \
    --username $OPS_MGR_USR \
    --password $OPS_MGR_PWD \
    errands \
    --product-name "$PRODUCT_NAME" |
  tail -n+4 | head -n-1 | grep -v false | cut -d'|' -f2 | tr -d ' '
)

all_errands=$(
  om-linux \
    --target "https://${OPS_MGR_HOST}" \
    --skip-ssl-validation \
    --username $OPS_MGR_USR \
    --password $OPS_MGR_PWD \
    errands \
    --product-name "$PRODUCT_NAME" |
  tail -n+4 | head -n-1 | cut -d'|' -f2 | tr -d ' '
)

if [[ "$ERRANDS_TO_RUN_ON_CHANGE" == "all" ]]; then
  errands_to_run_on_change="${all_errands[@]}"
else
  errands_to_run_on_change=$(echo "$ERRANDS_TO_RUN_ON_CHANGE" | tr ',' '\n')
fi

if [[ "$ERRANDS_TO_DISABLE" == "all" ]]; then
  errands_to_disable="${all_errands[@]}"
else
  errands_to_disable=$(echo "$ERRANDS_TO_DISABLE" | tr ',' '\n')
fi

will_run_on_change=$(
  echo $all_errands |
  jq \
    --arg run_on_change "${errands_to_run_on_change[@]}" \
    --raw-input \
    --raw-output \
    'split(" ")
    | reduce .[] as $errand ([];
       if $run_on_change | contains($errand) then
         . + [$errand]
       else
         .
       end)
    | join("\n")'
)

will_disable=$(
  echo $all_errands |
  jq \
    --arg disable "${errands_to_disable[@]}" \
    --raw-input \
    --raw-output \
    'split(" ")
    | reduce .[] as $errand ([];
       if $disable | contains($errand) then
         . + [$errand]
       else
         .
       end)
    | join("\n")'
)

if [ -z "$will_run_on_change" ]; then
  echo Nothing to set to run on change.
else
  while read errand; do
    echo -n Set $errand to run on change...
    om-linux \
      --target "https://${OPS_MGR_HOST}" \
      --skip-ssl-validation \
      --username "$OPS_MGR_USR" \
      --password "$OPS_MGR_PWD" \
      set-errand-state \
      --product-name "$PRODUCT_NAME" \
      --errand-name $errand \
      --post-deploy-state "when-changed"
    echo done
  done < <(echo "$will_run_on_change")
fi

if [ -z "$will_disable" ]; then
  echo Nothing to set to disable.
else
  while read errand; do
    echo -n Set $errand to disable...
    om-linux \
      --target "https://${OPS_MGR_HOST}" \
      --skip-ssl-validation \
      --username "$OPS_MGR_USR" \
      --password "$OPS_MGR_PWD" \
      set-errand-state \
      --product-name "$PRODUCT_NAME" \
      --errand-name $errand \
      --post-deploy-state "disabled"
    echo done
  done < <(echo "$will_disable")
fi
