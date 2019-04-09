#!/bin/bash

set -Eeuo pipefail

# if the lxd groups doesn't exist, create it.
if ! grep -q lxd /etc/group; then
    sudo addgroup --system lxd
fi

if ! groups "$USER" | grep -q lxd; then
    sudo adduser "${USER}" lxd
    sudo gpasswd -a "${USER}" lxd
fi

if [ ! -x "$(command -v lxd)" ]; then
    sudo snap install lxd --channel=candidate
fi
