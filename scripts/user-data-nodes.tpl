#!/usr/bin/env bash
set -euo pipefail
apt update && apt install curl -y

K3S_TOKEN="${k3s_token}"

# To add nodes
export INSTALL_CLUSTER_EXEC="agent --server https://${API_IP}:6443"

curl -sfL https://get.k3s.io | sh -
systemctl enable --now k3s
