output "public_ip" {
  description = "Public IPv4 address of the instance"
  value       = one([for ip in linode_instance.instance01.ipv4 : ip if !startswith(ip, "192.168.")])
}
