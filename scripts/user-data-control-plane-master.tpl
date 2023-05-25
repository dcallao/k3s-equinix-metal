#!/usr/bin/env bash
set -euo pipefail
apt update && apt install curl -y

curl -sfL https://get.k3s.io | \
  K3S_TOKEN="${k3s_token}" \
  INSTALL_K3S_EXEC="server --cluster-init --write-kubeconfig-mode=644 --tls-san=${API_IP} --tls-san=${API_IP}.sslip.io --disable=servicelb" \
  sh -
systemctl enable --now k3s

# Create a configure_bird.sh script that will do the heavy work
# As the metadata doesn't include the bgp information at boot (it needs to be explicitely done)
# it will wait indefitenly until it does.
# It will be called with a systemd script to avoid startup issues and timeouts
cat << 'EOS' > /usr/local/bin/configure_bird.sh
#!/bin/bash
set -euo pipefail

# Install bird
apt update && apt install bird jq -y

INTERNAL_IP="null"
while [ $${INTERNAL_IP} == "null" ]; do
	METADATA=$(curl -s https://metadata.platformequinix.com/metadata)
	INTERNAL_IP=$(echo $${METADATA} | jq -r '.bgp_neighbors[0].customer_ip')
  echo "BGP data still not available..."
	sleep 5
done
PEER_IP_1=$(echo $${METADATA} | jq -r '.bgp_neighbors[0].peer_ips[0]')
PEER_IP_2=$(echo $${METADATA} | jq -r '.bgp_neighbors[0].peer_ips[1]')
ASN=$(echo $${METADATA} | jq -r '.bgp_neighbors[0].customer_as')
ASN_AS=$(echo $${METADATA} | jq -r '.bgp_neighbors[0].peer_as')
MULTIHOP=$(echo $${METADATA} | jq -r '.bgp_neighbors[0].multihop')
GATEWAY=$(echo $${METADATA} | jq -r '.network.addresses[] | select(.public == true and .address_family == 4) | .gateway')

# Generate the bird configuration
cat <<EOF >/etc/bird/bird.conf
router id $${INTERNAL_IP};

protocol direct {
  interface "lo";
}

protocol kernel {
  persist;
  scan time 60;
  import all;
  export all;
}

protocol device {
  scan time 60;
}

protocol static {
  route $${PEER_IP_1}/32 via $${GATEWAY};
  route $${PEER_IP_2}/32 via $${GATEWAY};
}

filter metal_bgp {
  accept;
}

protocol bgp neighbor_v4_1 {
  export filter metal_bgp;
  local as $${ASN};
  multihop;
  neighbor $${PEER_IP_1} as $${ASN_AS};
}

protocol bgp neighbor_v4_2 {
  export filter metal_bgp;
  local as $${ASN};
  multihop;
  neighbor $${PEER_IP_2} as $${ASN_AS};
}
EOF

# Wait for the node to be available, meaning the K8s API is available
while ! kubectl wait --for condition=ready node $(cat /etc/hostname | tr '[:upper:]' '[:lower:]') --timeout=60s; do sleep 2 ; done

# Configure the interfaces
if ! grep -q 'lo:0' /etc/network/interfaces; then
  cat <<-EOF >>/etc/network/interfaces
	auto lo:0
	iface lo:0 inet static
		address ${API_IP}
		netmask 255.255.255.255
	EOF
  ifup lo:0
fi

# Enable IP forward for bird
echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-ip-forward.conf
sysctl --load /etc/sysctl.d/99-ip-forward.conf

# Debian usually starts the service after being installed, but just in case
systemctl is-enabled bird || systemctl enable bird
systemctl is-active bird || systemctl restart bird
EOS

chmod a+x /usr/local/bin/configure_bird.sh

# Create a systemd unit to configure bird once
# Using "User=root" is required for some environment variables to be present
cat <<- EOF > /etc/systemd/system/configure_bird.service
[Unit]
Description=Configure Bird on Equinix Metal after Metadata is up
Wants=network-online.target
After=network.target network-online.target
ConditionPathExists=/usr/local/bin/configure_bird.sh

[Service]
User=root
Type=forking
TimeoutStartSec=infinity
ExecStart=/usr/local/bin/configure_bird.sh
RemainAfterExit=yes
KillMode=process
# Disable & delete everything
ExecStartPost=rm -f /usr/local/bin/configure_bird.sh
ExecStartPost=/bin/sh -c "systemctl disable configure_bird.service"
ExecStartPost=rm -f /etc/systemd/system/configure_bird.service

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now configure_bird.service
