#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

BCM_CLI_VERB=${2:-}
if [ -z "${BCM_CLI_VERB}" ]; then
    cat ./help.txt
    exit
fi

if [[ "$BCM_CLI_VERB" == "clear" ]]; then
    bash -c "$BCM_COMMAND_DIR/tier/entrypoint.sh destroy bitcoin-$BCM_ACTIVE_CHAIN"
    bash -c "$BCM_COMMAND_DIR/tier/entrypoint.sh destroy underlay"
    bash -c "$BCM_COMMAND_DIR/tier/entrypoint.sh destroy kafka"
    bash -c "$BCM_COMMAND_DIR/tier/entrypoint.sh destroy manager"
    bash -c "$BCM_PROJECT_DIR/destroy.sh"
    
    exit
fi

TIER_NAME=${3:-}

# if [[ $BCM_CLI_VERB == "create" ]]; then
#     if  [[ $TIER_NAME == "bitcoin" ]]; then
#         bash -c "$BCM_GIT_DIR/project/tiers/bitcoin/up.sh"
#         elif  [[ $TIER_NAME == "underlay" ]]; then
#         # bash -c "$BCM_GIT_DIR/project/tiers/underlay/up.sh"
#         elif [[ $TIER_NAME == "kafka" ]]; then
#         # bash -c "$BCM_GIT_DIR/project/tiers/kafka/up.sh"
#         elif  [[ $TIER_NAME == "manager" ]]; then
#         # let's make sure we have the LXD project set up correctly.
#         # bash -c "$BCM_GIT_DIR/project/tiers/manager/up.sh"
#     fi
# fi

if [[ $BCM_CLI_VERB == "destroy" ]]; then
    # we deal with bitcoin tiers a bit differently since they are scoped by ACTIVE_CHAIN
    if  [[ $TIER_NAME == bitcoin* ]]; then
        bash -c "$BCM_GIT_DIR/project/tiers/remove_tier.sh --tier-name=$TIER_NAME"
    else
        # if not Bitcoin, we call their specific destroy scripts.
        bash -c "$BCM_GIT_DIR/project/tiers/$TIER_NAME/destroy.sh"
    fi
fi

if [[ $BCM_CLI_VERB != "list" && $BCM_CLI_VERB != "destroy" && $BCM_CLI_VERB != "create" ]]; then
    echo "Error: next command should be 'create', 'remove', or 'list'."
    cat ./help.txt
fi
