output "ipv4" {
  description = "Public IPv4 address of the server"
  value       = hcloud_server.nixos.ipv4_address
}

output "ipv6" {
  description = "Public IPv6 address of the server"
  value       = hcloud_server.nixos.ipv6_address
}

output "name" {
  description = "Server name"
  value       = hcloud_server.nixos.name
}

output "status" {
  description = "Server status"
  value       = hcloud_server.nixos.status
}

output "ssh_command" {
  description = "SSH command to connect (update key path as needed)"
  value       = "ssh -i ~/.ssh/openclaw_hetzner root@${hcloud_server.nixos.ipv4_address}"
}
