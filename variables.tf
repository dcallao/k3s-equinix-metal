# https://deploy.equinix.com/developers/capacity-dashboard/
variable "plan_control_plane" {
  type        = string
  description = "K3s control plane type/size"
  default     = "c3.small.x86"
}

variable "plan_node" {
  type        = string
  description = "K3s node type/size"
  default     = "c3.small.x86"
}

variable "node_count" {
  type        = number
  default     = "0"
  description = "Number of K3s nodes"
}

variable "k3s_ha" {
  type        = bool
  default     = true
  description = "K3s HA (aka 3 control plane nodes)"
}

variable "metro" {
  type        = string
  description = "Equinix metro code"
  default     = "FR"
}

variable "os" {
  type        = string
  description = "Operating system"
  default     = "debian_11"
}

variable "metal_auth_token" {
  type        = string
  sensitive   = true
  description = "Your Equinix Metal API key"
}

variable "metal_project_id" {
  type        = string
  description = "Your Equinix Metal Project ID"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Your SSH private key path (used locally only)"
}

variable "control_plane_hostnames" {
  type        = string
  description = "Control plane hostnames (i.e.- cp will generate cp01, cp02,...)"
  default     = "control-plane"
}

variable "node_hostnames" {
  type        = string
  description = "Node hostnames (i.e.- no will generate no01, no02,...)"
  default     = "node"
}

variable "custom_k3s_token" {
  type        = string
  description = "K3s token used for nodes to join the cluster"
  default     = null
}