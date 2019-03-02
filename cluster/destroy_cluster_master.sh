#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1091
source ./env

BCM_CLUSTER_NAME=
BCM_SSH_USERNAME=
BCM_SSH_HOSTNAME=

for i in "$@"; do
    case $i in
        --cluster-name=*)
            BCM_CLUSTER_NAME="${i#*=}"
            shift # past argument=value
        ;;
        --ssh-username=*)
            BCM_SSH_USERNAME="${i#*=}"
            shift # past argument=value
        ;;
        --ssh-hostname=*)
            BCM_SSH_HOSTNAME="${i#*=}"
            shift # past argument=value
        ;;
        *)
            # unknown option
        ;;
    esac
done

if [[ -z "$BCM_SSH_USERNAME" ]]; then
    echo "ERROR: BCM_SSH_USERNAME not specified. Use --ssh-username="
fi

if [[ -z "$BCM_SSH_HOSTNAME" ]]; then
    echo "ERROR: BCM_SSH_HOSTNAME not specified. Use --ssh-hostname="
fi

# if it's the cluster master add the LXC remote so we can manage it.
if lxc remote list --format csv | grep -q "bcm-$BCM_CLUSTER_NAME"; then
    echo "Switching lxd remote to local."
    lxc remote switch local
    
    echo "Removing lxd remote for cluster '$BCM_CLUSTER_NAME' at '$BCM_SSH_HOSTNAME:8443'."
    lxc remote remove "bcm-$BCM_CLUSTER_NAME"
fi

# remove the entry for the host in your ~/.ssh/known_hosts
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$BCM_SSH_HOSTNAME"

if [[ -d "$BCM_TEMP_DIR/$BCM_CLUSTER_NAME" ]]; then
    rm -rf "${BCM_TEMP_DIR:?}/$BCM_CLUSTER_NAME"
fi