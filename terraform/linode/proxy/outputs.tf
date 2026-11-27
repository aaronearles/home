output "ip_address" {
  value = one(linode_instance.proxy.ipv4)
}

output "ssh_tunnel_command" {
  description = "Run this, then point clients at http://localhost:3128"
  value       = "ssh -N -L 3128:127.0.0.1:3128 -p ${var.ssh_port} ${var.ssh_user}@${one(linode_instance.proxy.ipv4)}"
}
