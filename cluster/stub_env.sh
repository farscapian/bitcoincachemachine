#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

IS_MASTER=0
BCM_SSH_USERNAME=
BCM_SSH_HOSTNAME=
BCM_SSH_KEY_PATH=

for i in "$@"; do
    case $i in
        --master)
            IS_MASTER=1
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
        --ssh-key-path=*)
            BCM_SSH_KEY_PATH="${i#*=}"
            shift # past argument=value
        ;;
        *)
            # unknown option
        ;;
    esac
done

if [[ -z "$BCM_SSH_USERNAME" ]]; then
    echo "ERROR: BCM_SSH_USERNAME not passed correctly."
    exit
fi

if [[ -z "$BCM_SSH_HOSTNAME" ]]; then
    echo "ERROR: BCM_SSH_HOSTNAME not passed correctly."
    exit
fi

ENDPOINT_DIR="$TEMP_DIR/$BCM_ENDPOINT_NAME"
mkdir -p "$ENDPOINT_DIR"
touch "$ENV_FILE"

# generate an LXD secret for the new VM lxd endpoint.
export BCM_ENDPOINT_NAME="$BCM_ENDPOINT_NAME"

# if the user override the keypath, we will use that instead.
if [[ ! -f $BCM_SSH_KEY_PATH ]]; then
    BCM_SSH_KEY_PATH="$ENDPOINT_DIR/id_rsa"
    # this key is for temporary use and used only during initial provisioning.
    ssh-keygen -t rsa -b 4096 -C "$BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME" -f "$BCM_SSH_KEY_PATH" -N ""
    chmod 400 "$BCM_SSH_KEY_PATH.pub"
fi

if [[ $BCM_SSH_HOSTNAME == *.onion ]]; then
    torify ssh-copy-id -i "$BCM_SSH_KEY_PATH" "$BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME"
else
    # not let's do an ssh-keyscan so we can get the remote identity added to our ~/.ssh/known_hosts file
    wait-for-it -t 10 "$BCM_SSH_HOSTNAME:22"
    ssh-keyscan -H "$BCM_SSH_HOSTNAME" >> "$HOME/.ssh/known_hosts"
    ssh-copy-id -i "$BCM_SSH_KEY_PATH" "$BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME"
fi

BCM_LXD_SECRET="$(apg -n 1 -m 30 -M CN)"
export BCM_LXD_SECRET="$BCM_LXD_SECRET"
export BCM_SSH_USERNAME="$BCM_SSH_USERNAME"
export BCM_SSH_HOSTNAME="$BCM_SSH_HOSTNAME"

if [ $IS_MASTER -eq 1 ]; then
    envsubst <./envtemplates/master_defaults.env >"$ENV_FILE"
    elif [ $IS_MASTER -ne 1 ]; then
    envsubst <./envtemplates/member_defaults.env >"$ENV_FILE"
else
    echo "Incorrect usage. Please specify whether $BCM_ENDPOINT_NAME is an LXD cluster master or member."
fi

if [ $IS_MASTER -eq 1 ]; then
    envsubst <./lxd_preseed/lxd_master_preseed.yml >"$TEMP_DIR/$BCM_ENDPOINT_NAME/lxd_preseed.yml"
    #bcm pass insert --name="$BCM_CLUSTER_NAME/$BCM_ENDPOINT_NAME/lxd_preseed.yml"
    elif [ $IS_MASTER -ne 1 ]; then
    envsubst <./lxd_preseed/lxd_member_preseed.yml >"$TEMP_DIR/$BCM_ENDPOINT_NAME/lxd_preseed.yml"
else
    echo "Incorrect usage. Please specify whether $BCM_ENDPOINT_NAME is an LXD cluster master or member."
fi
