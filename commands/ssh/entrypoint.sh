#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

VALUE=${2:-}
if [ -n "${VALUE}" ]; then
    BCM_CLI_VERB="$2"
else
    echo "Please provide a ssh command."
    cat ./help.txt
    exit
fi

SSH_KEY_PATH=
ONION_ADDRESS=
AUTH_TOKEN=
TITLE=
BCM_COMMAND=
BCM_EXECUTE_FLAG=0

for i in "$@"; do
    case $i in
        --ssh-key-path=*)
            SSH_KEY_PATH="${i#*=}"
            shift
        ;;
        --command=*)
            BCM_COMMAND="${i#*=}"
            shift
        ;;
        --onion=*)
            ONION_ADDRESS="${i#*=}"
            shift
        ;;
        --token=*)
            AUTH_TOKEN="${i#*=}"
            shift
        ;;
        --title=*)
            TITLE="${i#*=}"
            shift
        ;;
        --execute)
            BCM_EXECUTE_FLAG=1
            shift
        ;;
        *)
            # unknown option
        ;;
    esac
done

if [[ ! -f "$BCM_KNOWN_HOSTS_FILE" ]]; then
    touch "$BCM_KNOWN_HOSTS_FILE"
fi

if [[ $BCM_HELP_FLAG == 1 ]]; then
    cat ./help.txt
    exit
fi

KEY_NAME="bcm_trezor_$BCM_SSH_HOSTNAME"".pub"
TREZOR_PUB_KEY_PATH="$SSHHOME/$KEY_NAME"
if [[ $BCM_CLI_VERB == "newkey" ]]; then
    # shellcheck disable=SC1090
    source "$BCM_GIT_DIR/controller/export_usb_path.sh"
    if [[ -z "$BCM_TREZOR_USB_PATH" ]]; then
        echo "Could not determine Trezor USB PATH."
        exit
    fi
    
    if [[ $BCM_HELP_FLAG == 1 ]]; then
        cat ./newkey/help.txt
        exit
    fi
    
    docker run -t --rm \
    -v "$BCM_TREZOR_USB_PATH":"$BCM_TREZOR_USB_PATH" \
    -v "$SSHHOME":/home/user/.ssh \
    -e BCM_SSH_USERNAME="$BCM_SSH_USERNAME" \
    -e BCM_SSH_HOSTNAME="$BCM_SSH_HOSTNAME" \
    -e KEY_NAME="$KEY_NAME" \
    --device="$BCM_TREZOR_USB_PATH" \
    "bcm-trezor:$BCM_VERSION" bash -c "trezor-agent $BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME > /home/user/.ssh/$KEY_NAME"
    
    if [[ ! -f "$TREZOR_PUB_KEY_PATH" ]]; then
        echo "Error: SSH Key did not generate successfully!"
        exit
    fi
    
    chmod 0400 "$TREZOR_PUB_KEY_PATH"
    
    echo "INFO! Your new Trezor-backed SSH public key for host '$BCM_SSH_HOSTNAME' can be found at '$TREZOR_PUB_KEY_PATH'"
fi

# shellcheck disable=SC1090
source "$BCM_GIT_DIR/controller/export_usb_path.sh"
if [[ -z "$BCM_TREZOR_USB_PATH" ]]; then
    echo "Could not determine Trezor USB PATH."
    exit
fi
IP_ADDRESS=$(dig +short "$BCM_SSH_HOSTNAME" | head -n 1)

# this command pushes a Trezor public SSH key to an existing SSH host which is AUTHENTICATED using an external SSH keypair.
# the existing keypair will be removed from the remote node such that ONLY trezor can authenticate you to the endpoint.
if [[ $BCM_CLI_VERB == "provision" ]]; then
    
    # let's add the remote hosts fingerprint to known hosts so we don't get interactive input.
    ssh-keyscan -H "$BCM_SSH_HOSTNAME" >> "$BCM_KNOWN_HOSTS_FILE"
    if [[ ! -f $TREZOR_PUB_KEY_PATH ]]; then
        # generate a new SSH key for the remote hostname.
        bash -c "$BCM_COMMAND_DIR/ssh newkey --hostname=$BCM_SSH_HOSTNAME --username=$BCM_SSH_USERNAME
        < $TREZOR_PUB_KEY_PATH ssh -i $SSH_KEY_PATH $BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME cat > /home/\$(whoami)/.ssh/authorized_keys"
    fi
    
    # place the public SSH key on the remote SSH endpoint.
    echo "WARNING: You can ONLY use your Trezor now to log into the host '$SSH_HOSTNAME'."
    ssh-keyscan -H "$SSH_HOSTNAME" >> "$BCM_KNOWN_HOSTS_FILE"
    
    # shellcheck disable=SC2016
    docker run -it \
    --add-host="$SSH_HOSTNAME:$IP_ADDRESS" \
    -v "$BCM_TREZOR_USB_PATH":"$BCM_TREZOR_USB_PATH" \
    -v "$SSHHOME":/home/user/.ssh \
    --device="$BCM_TREZOR_USB_PATH" \
    -e BCM_SSH_USERNAME="$BCM_SSH_USERNAME" \
    -e BCM_SSH_HOSTNAME="$SSH_HOSTNAME" \
    "bcm-trezor:$BCM_VERSION" trezor-agent -c "$BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME" -- 'set -ex && export BCM_GIT_DIR="$HOME/bcm" BCM_GITHUB_REPO_URL="https://github.com/BitcoinCacheMachine/BitcoinCacheMachine" && set -e && echo "BCM_GIT_DIR:  $BCM_GIT_DIR" && echo "BCM_GITHUB_REPO_URL: $BCM_GITHUB_REPO_URL" && echo "deb https://deb.torproject.org/torproject.org bionic main" | sudo tee -a /etc/apt/sources.list && echo "deb-src https://deb.torproject.org/torproject.org bionic main" | sudo tee -a /etc/apt/sources.list && curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | sudo gpg --import && gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | sudo apt-key add - && sudo apt-get update && sudo apt-get install -y tor curl wait-for-it git deb.torproject.org-keyring && wait-for-it -t 30 127.0.0.1:9050 && git config --global "http.$BCM_GITHUB_REPO_URL.proxy" socks5://127.0.0.1:9050 && mkdir -p "$BCM_GIT_DIR" && if [[ ! -d "$BCM_GIT_DIR/.git" ]]; then git clone --quiet --single-branch --branch dev "$BCM_GITHUB_REPO_URL" "$BCM_GIT_DIR"; fi && cd "$BCM_GIT_DIR" && git fetch && git checkout dev && git pull && bash -c "./commands/install/endpoint_provision.sh" && exit'
fi

if [[ $BCM_CLI_VERB == "connect" ]]; then
    docker system prune -f
    docker run -it --add-host="$BCM_SSH_HOSTNAME:$IP_ADDRESS" \
    -v "$BCM_TREZOR_USB_PATH":"$BCM_TREZOR_USB_PATH" \
    -v "$SSHHOME":/home/user/.ssh \
    --device="$BCM_TREZOR_USB_PATH" \
    "bcm-trezor:$BCM_VERSION" trezor-agent --connect "$BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME"
fi

if [[ $BCM_EXECUTE_FLAG == 1 ]]; then
    docker system prune -f
    docker run -it --add-host="$BCM_SSH_HOSTNAME:$IP_ADDRESS" \
    -v "$BCM_TREZOR_USB_PATH":"$BCM_TREZOR_USB_PATH" \
    -v "$SSHHOME":/home/user/.ssh \
    -e BCM_COMMAND="$BCM_COMMAND" \
    --device="$BCM_TREZOR_USB_PATH" \
    "bcm-trezor:$BCM_VERSION" trezor-agent --connect "$BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME" -- bcm "$@"
fi


if [[ $BCM_CLI_VERB == "add-onion" ]]; then
    if [[ $BCM_HELP_FLAG == 1 ]]; then
        cat ./addonion/help.txt
        exit
    fi
    
    if [[ -z $ONION_ADDRESS ]]; then
        echo "Error: ONION_ADDRESS is not defined. Use --onion=<ONION_ADDRESS>"
        exit
    fi
    
    if [[ -z $TITLE ]]; then
        echo "Error: TITLE is not defined. Use --title=<TITLE>"
        exit
    fi
    
    # construct the tor string.
    TOR_STRING="HidServAuth $ONION_ADDRESS $AUTH_TOKEN #BCM_SSH: $TITLE"
    TORRC=/etc/tor/torrc
    if grep -Fxq "$TOR_STRING" "$TORRC"; then
        echo "This SSH endpoint '$TITLE' is already defined in '$TORRC'. You can use 'bcm ssh remove-onion' to remove it.'"
    else
        # let's further check to ensure you're not inserting an existing onion address else the tor service
        # won't start due to duplicates.
        if ! grep -Fxq "$ONION_ADDRESS" "$TORRC"; then
            echo "$TOR_STRING" | sudo tee -a "$TORRC" >>/dev/null
            sudo systemctl reload tor
            wait-for-it -t 15 127.0.0.1:9050
            
            echo "$TITLE has been added to $TORRC and your local tor client has been reloaded."
        else
            echo "WARNING: you already have an onion endpoint with the same onion address! No changes were made."
        fi
    fi
    
    exit
fi

if [[ $BCM_CLI_VERB == "remove-onion" ]]; then
    if [[ $BCM_HELP_FLAG == 1 ]]; then
        cat ./removeonion-help.txt
        exit
    fi
    
    if [[ -z $TITLE ]]; then
        echo "Error: TITLE is not defined. Use --title=<TITLE>"
        exit
    fi
    
    # construct the tor string.
    TORRC=/etc/tor/torrc
    if grep -q "#BCM_SSH: $TITLE" "$TORRC"; then
        sudo sed -i '/'"#BCM_SSH: $TITLE"'/d' "$TORRC"
        
        # restart tor daemon
        # TODO only restart if the line was in there in the first place
        sudo systemctl reload tor >>/dev/null
        wait-for-it -t 15 --quiet 127.0.0.1:9050>>/dev/null
        
        echo "'$TITLE' has been removed from '$TORRC' and your local tor daemon has been reloaded."
    else
        echo "'$TITLE' was not found in $TORRC"
    fi
    
    exit
fi

if [[ $BCM_CLI_VERB == "list-onion" ]]; then
    echo "TITLE,ONION_ADDRESS"
    while read -r LINE; do
        if [[ "$LINE" =~ "#BCM_SSH:" ]]; then
            TITLE=$(echo "$LINE" | awk '{print $5;}')
            ONION=$(echo "$LINE"| awk '{print $2;}')
            echo "$TITLE,$ONION"
        fi
    done </etc/tor/torrc
fi



# this script grabs the onion site and adds it to your local /etc/tor/torrc

# # now we wait for the service to start, then we grab the new onion site and token
# # then we add it to our config using bcm ssh add-onion
# DOCKER_CONTAINER_ID=$(lxc exec "$BCM_UNDERLAY_HOST_NAME" -- docker ps | grep toronion | awk '{print $1}')
# if [[ -n $DOCKER_CONTAINER_ID ]]; then
#     ONION_CREDENTIALS="$(lxc exec "$BCM_UNDERLAY_HOST_NAME" -- docker exec -t "$DOCKER_CONTAINER_ID" cat /var/lib/tor/bcmonion/hostname)"

#     if [[ -n $ONION_CREDENTIALS ]]; then
#         ONION_URL="$(echo "$ONION_CREDENTIALS" | awk '{print $1;}')"
#         ONION_TOKEN="$(echo "$ONION_CREDENTIALS" | awk '{print $2;}')"
#         bcm ssh add-onion --onion="$ONION_URL" --token="$ONION_TOKEN" --title="$(lxc remote get-default)"
#     fi
# else
#     echo "WARNING: Docker container not found for 'toronion'. You may need to run 'bcm stack start toronion'."
# fi
