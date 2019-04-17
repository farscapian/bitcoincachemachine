#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

source ./env

if ! bcm stack list | grep -q lnd; then
    # first, let's make sure we deploy our direct dependencies.
    bcm stack deploy lnd
fi

# env.sh has some of our naming conventions for DOCKERVOL and HOSTNAMEs and such.
source "$BCM_GIT_DIR/project/shared/env.sh"

# prepare the image.
"$BCM_GIT_DIR/project/shared/docker_image_ops.sh" \
--build-context="$(pwd)/build" \
--container-name="$LXC_HOSTNAME" \
--image-name="$IMAGE_NAME" \
--image-tag="$IMAGE_TAG"

# push the stack and build files
lxc file push -p -r "$(pwd)/stack/" "$BCM_GATEWAY_HOST_NAME/root/stacks/$TIER_NAME/$STACK_NAME"

RTL_PASSWORD="TODO"

lxc exec "$BCM_GATEWAY_HOST_NAME" -- env IMAGE_NAME="$BCM_PRIVATE_REGISTRY/$IMAGE_NAME:$IMAGE_TAG" \
BCM_ACTIVE_CHAIN="$BCM_ACTIVE_CHAIN" \
LXC_HOSTNAME="$LXC_HOSTNAME" \
SERVICE_PORT="$SERVICE_PORT" \
RTL_PASSWORD="$RTL_PASSWORD" \
MACAROON_PATH="/root/.lnd/data/chain/bitcoin/$BCM_ACTIVE_CHAIN" \
docker stack deploy -c "/root/stacks/$TIER_NAME/$STACK_NAME/stack/$STACK_FILE" "$STACK_NAME-$BCM_ACTIVE_CHAIN"

ENDPOINT=$(bcm get-ip)
wait-for-it -t 0 "$ENDPOINT:$SERVICE_PORT"

# let's the the pariing URL from the container output
PAIRING_OUTPUT_URL=$(lxc exec "$BCM_GATEWAY_HOST_NAME" --  docker service logs "$STACK_NAME-$BCM_ACTIVE_CHAIN""_$SERVICE_NAME" | grep 'Pairing URL: ' | awk '{print $5}')
RTL_URL=${PAIRING_OUTPUT_URL/0.0.0.0/$ENDPOINT}

xdg-open "$RTL_URL" &
