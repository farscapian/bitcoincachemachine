#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

LXC_HOST=
STACK_NAME=
VOLUME_NAME=

for i in "$@"; do
    case $i in
        --lxc-hostname=*)
            LXC_HOST="${i#*=}"
            shift
        ;;
        --stack-name=*)
            STACK_NAME="${i#*=}"
            shift
        ;;
        --volume-name=*)
            VOLUME_NAME="${i#*=}"
            shift
        ;;
        *)
            # unknown option
        ;;
    esac
done


if [[ $TIER_NAME == bitcoin ]]; then
    LXC_HOST="$BCM_BITCOIN_HOST_NAME"
    elif [[ $TIER_NAME == underlay ]]; then
    LXC_HOST="$BCM_UNDERLAY_HOST_NAME"
    elif [[ $TIER_NAME == manager ]]; then
    LXC_HOST="$BCM_MANAGER_HOST_NAME"
    elif [[ $TIER_NAME == kafka ]]; then
    LXC_HOST="$BCM_KAFKA_HOST_NAME"
fi

# push the stack and build files
lxc exec "$LXC_HOST" -- docker volume rm -f "$STACK_NAME-$BCM_ACTIVE_CHAIN""""_""$VOLUME_NAME"