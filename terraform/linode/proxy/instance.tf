# Generate a random password (root login is disabled by the stackscript; only for Lish/recovery)
resource "random_password" "root_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Provisioning script: admin user, SSH hardening, loopback-only squid
resource "linode_stackscript" "proxy" {
  label       = "proxy-squid"
  description = "SSH-only squid proxy (managed by OpenTofu)"
  script      = file("${path.module}/stackscript.sh")
  images      = [var.image]
  rev_note    = "managed by tofu"
}

# Create a Linode
resource "linode_instance" "proxy" {
  label          = "proxy"
  image          = var.image
  stackscript_id = linode_stackscript.proxy.id
  stackscript_data = {
    SSH_USER = var.ssh_user
    SSH_PORT = tostring(var.ssh_port)
    FQDN     = var.fqdn
    TIMEZONE = var.timezone
  }
  region          = var.region
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = random_password.root_pass.result

  tags      = var.tags
  swap_size = 256
  # private_ip = true
}

# Only SSH is reachable from the internet
resource "linode_firewall" "proxy" {
  label           = "proxy"
  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  inbound {
    label    = "ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = tostring(var.ssh_port)
    ipv4     = var.ssh_allowed_ipv4
    ipv6     = ["::/0"]
  }

  linodes = [linode_instance.proxy.id]
}
