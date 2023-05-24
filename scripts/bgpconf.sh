#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"

die(){
	echo ${1}
	exit ${2}
}

apt update && apt install curl bird jq -y

METADATA=$(curl https://metadata.platformequinix.com/metadata)
INTERNAL_IP=$(echo ${METADATA} | jq -r '.bgp_neighbors[0].customer_ip')
PEER_IP_1=$(echo ${METADATA} | jq -r '.bgp_neighbors[0].peer_ips[0]')
PEER_IP_2=$(echo ${METADATA} | jq -r '.bgp_neighbors[0].peer_ips[1]')
ASN=$(echo ${METADATA} | jq -r '.bgp_neighbors[0].customer_as')
ASN_AS=$(echo ${METADATA} | jq -r '.bgp_neighbors[0].peer_as')
MULTIHOP=$(echo ${METADATA} | jq -r '.bgp_neighbors[0].multihop')
GATEWAY=$(echo ${METADATA} | jq -r '.network.addresses[] | select(.public == true and .address_family == 4) | .gateway')

EXTERNAL_IP=${1}

cat <<EOF >/etc/bird/bird.conf
router id ${INTERNAL_IP};

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
  route ${PEER_IP_1}/32 via ${GATEWAY};
  route ${PEER_IP_2}/32 via ${GATEWAY};
}

filter metal_bgp {
  accept;
}

protocol bgp neighbor_v4_1 {
  export filter metal_bgp;
  local as ${ASN};
  multihop;
  neighbor ${PEER_IP_1} as ${ASN_AS};
}

protocol bgp neighbor_v4_2 {
  export filter metal_bgp;
  local as ${ASN};
  multihop;
  neighbor ${PEER_IP_2} as ${ASN_AS};
}
EOF

if ! grep -q 'lo:0' /etc/network/interfaces; then
  cat <<-EOF >>/etc/network/interfaces
	auto lo:0
	iface lo:0 inet static
		address ${EXTERNAL_IP}
		netmask 255.255.255.255
	EOF
  ifup lo:0
fi

echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-ip-forward.conf
sysctl --load /etc/sysctl.d/99-ip-forward.conf
systemctl enable --now bird