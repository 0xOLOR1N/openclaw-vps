variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "name" {
  description = "Server name"
  type        = string
  default     = "openclaw"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg, Germany
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx22" # 2 vCPU, 4GB RAM (AMD, shared)
}

variable "image" {
  description = "Base image (will be replaced by NixOS via nixos-infect)"
  type        = string
  default     = "ubuntu-22.04"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for initial access"
  type        = string
  default     = "../secrets/ssh-key.pub"
}

variable "host_public_key_path" {
  description = "Path to SSH host public key (persistent across rebuilds)"
  type        = string
  default     = "../secrets/host-key.pub"
}
