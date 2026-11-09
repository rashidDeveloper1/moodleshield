output "primary_public_ip" {
  description = "Floating IP assigned to the primary server"
  value       = hcloud_floating_ip.primary.ip_address
}

output "primary_private_ip" {
  description = "Private overlay IP of the primary server"
  value       = hcloud_server_network.primary.ip
}

output "replica_public_ip" {
  description = "Public IP of the DR replica"
  value       = hcloud_server.replica.ipv4_address
}

output "replica_private_ip" {
  description = "Private overlay IP of the DR replica"
  value       = hcloud_server_network.replica.ip
}
