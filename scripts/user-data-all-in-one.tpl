#!/usr/bin/env bash
set -euo pipefail
apt update && apt install curl -y

K3S_TOKEN="${k3s_token}"

# Single node
export INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644"

curl -sfL https://get.k3s.io | sh -
systemctl enable --now k3s
