#!/usr/bin/env bash
set -euo pipefail
apt update && apt install curl -y

# Create an install_k3s.sh script that will do the heavy work
# As the K3s first server may not be up at boot (it needs to be) it will wait indefitenly until it does.
# It will be called with a systemd script to avoid startup issues and timeouts
cat << 'EOS' > /usr/local/bin/install_k3s.sh
#!/bin/bash
set -euo pipefail
apt update && apt install curl -y

# Wait for the first control plane node to be up
while ! curl -m 10 -s -k -o /dev/null https://${API_IP}:6443 ; do echo "API still not reachable"; sleep 2 ; done

curl -sfL https://get.k3s.io | \
  K3S_TOKEN="${k3s_token}" \
  INSTALL_K3S_EXEC="agent --server https://${API_IP}:6443" \
  sh -
systemctl enable --now k3s
EOS

chmod a+x /usr/local/bin/install_k3s.sh

# Create a systemd unit to install k3s once
# Using "User=root" is required for some environment variables to be present
cat <<- EOF > /etc/systemd/system/install_k3s.service
[Unit]
Description=Install K3s once first control plane is up
Wants=network-online.target
After=network.target network-online.target
ConditionPathExists=/usr/local/bin/install_k3s.sh
ConditionPathExists=!/usr/local/bin/k3s

[Service]
User=root
Type=forking
TimeoutStartSec=infinity
ExecStart=/usr/local/bin/install_k3s.sh
RemainAfterExit=yes
KillMode=process
# Disable & delete everything
ExecStartPost=rm -f /usr/local/bin/install_k3s.sh
ExecStartPost=/bin/sh -c "systemctl disable install_k3s.service"
ExecStartPost=rm -f /etc/systemd/system/install_k3s.service

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now install_k3s.service