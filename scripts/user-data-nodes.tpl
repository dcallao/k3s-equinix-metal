#!/usr/bin/env bash
set -euo pipefail
apt update && apt install curl -y

EXTERNAL_IP=${api_ip}
K3S_TOKEN="${k3s_token}"

# To add nodes
export INSTALL_CLUSTER_EXEC="agent --server https://${EXTERNAL_IP}:6443"

curl -sfL https://get.k3s.io | sh -
systemctl enable --now k3s
