resource "equinix_metal_device" "control_plane_master" {
  hostname         = "${var.control_plane_hostnames}-00"
  plan             = var.plan_control_plane
  metro            = var.metro
  operating_system = var.os
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
}

resource "equinix_metal_reserved_ip_block" "api_vip_addr" {
  count      = var.k3s_ha ? 1 : 0
  project_id = var.metal_project_id
  metro      = var.metro
  type       = "public_ipv4"
  quantity   = 1
}

resource "equinix_metal_reserved_ip_block" "ingress_vip_addr" {
  count      = var.k3s_ha ? 1 : 0
  project_id = var.metal_project_id
  metro      = var.metro
  type       = "public_ipv4"
  quantity   = 1
}

resource "equinix_metal_device" "control_plane_others" {
  hostname         = "${var.control_plane_hostnames}-${count.index}"
  plan             = var.plan_control_plane
  metro            = var.metro
  operating_system = var.os
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
  count            = var.k3s_ha ? 2 : 0
  depends_on       = [equinix_metal_device.control_plane_master]
}

resource "equinix_metal_bgp_session" "control_plane_second" {
  device_id      = equinix_metal_device.control_plane_others[0].id
  address_family = "ipv4"
  count          = var.k3s_ha ? 1 : 0
}

resource "equinix_metal_bgp_session" "control_plane_third" {
  device_id      = equinix_metal_device.control_plane_others[1].id
  address_family = "ipv4"
  count          = var.k3s_ha ? 1 : 0
}

resource "equinix_metal_device" "nodes" {
  hostname         = "${var.node_hostnames}-${count.index}"
  plan             = var.plan_node
  metro            = var.metro
  operating_system = var.os
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
  count            = var.node_count
  depends_on       = [equinix_metal_device.control_plane_master]
}

locals {
  k3s_token = coalesce(var.custom_k3s_token, random_string.random_k3s_token.result)
}

resource "random_string" "random_k3s_token" {
  length = 16
}