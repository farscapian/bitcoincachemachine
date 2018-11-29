#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

#MASTER_NODE=$(lxc info | grep server_name | xargs | awk 'NF>1{print $NF}')
for endpoint in $(bcm cluster list --endpoints --cluster-name="$BCM_CLUSTER_NAME"); do
    #echo $endpoint
    HOST_ENDING=$(echo "$endpoint" | tail -c 2)
    GATEWAY_HOST="bcm-gateway-$(printf %02d "$HOST_ENDING")"

    bash -c "$BCM_LXD_OPS/delete_lxc_container.sh --container-name=$GATEWAY_HOST"

    bash -c "$BCM_LXD_OPS/delete_cluster_dockerdisk.sh --container-name=$GATEWAY_HOST --endpoint=$endpoint"
done

bash -c "$BCM_LXD_OPS/delete_lxc_network.sh --network-name=bcmbrGWNat"

bash -c "$BCM_LXD_OPS/delete_lxc_network.sh --network-name=bcmNet"

bash -c "$BCM_LXD_OPS/delete_lxc_image.sh --image-name=bcm-gateway-template"

bash -c "$BCM_LXD_OPS/delete_lxc_profile.sh --profile-name=bcm_gateway_profile"