locals {
  k3s_token = coalesce(var.custom_k3s_token, random_string.random_k3s_token.result)
}

resource "random_string" "random_k3s_token" {
  length  = 16
  special = false
}

resource "equinix_metal_device" "all_in_one" {
  hostname         = "${var.control_plane_hostnames}-aio"
  plan             = var.plan_control_plane
  metro            = var.metro
  operating_system = var.os
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
  count            = var.k3s_ha ? 0 : 1
  user_data        = templatefile("scripts/user-data-all-in-one.tpl", { k3s_token = local.k3s_token })
}

resource "equinix_metal_device" "control_plane_master" {
  hostname         = "${var.control_plane_hostnames}-0"
  plan             = var.plan_control_plane
  metro            = var.metro
  operating_system = var.os
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
  count            = var.k3s_ha ? 1 : 0
  user_data        = templatefile("scripts/user-data-control-plane-master.tpl", { k3s_token = local.k3s_token, API_IP = equinix_metal_reserved_ip_block.api_vip_addr[0].network })
}

resource "equinix_metal_reserved_ip_block" "api_vip_addr" {
  count      = var.k3s_ha ? 1 : 0
  project_id = var.metal_project_id
  metro      = var.metro
  type       = "public_ipv4"
  quantity   = 1
}

resource "equinix_metal_device" "control_plane_others" {
  hostname         = format("%s-%d", var.control_plane_hostnames, count.index + 1)
  plan             = var.plan_control_plane
  metro            = var.metro
  operating_system = var.os
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
  count            = var.k3s_ha ? 2 : 0
  depends_on       = [equinix_metal_device.control_plane_master]
  user_data        = templatefile("scripts/user-data-control-plane.tpl", { k3s_token = local.k3s_token, API_IP = equinix_metal_reserved_ip_block.api_vip_addr[0].network })
}

resource "equinix_metal_bgp_session" "control_plane_master" {
  device_id      = equinix_metal_device.control_plane_master[0].id
  address_family = "ipv4"
  count          = var.k3s_ha ? 1 : 0
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
  user_data        = templatefile("scripts/user-data-nodes.tpl", { k3s_token = local.k3s_token, API_IP = equinix_metal_reserved_ip_block.api_vip_addr[0].network })
}