# Generate a random password
resource "random_password" "root_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create a Linode
resource "linode_instance" "instance01" {
  label           = var.instance_label
  image           = var.image
  stackscript_id  = var.stackscript_id != "" ? var.stackscript_id : null
  region          = "us-west"
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = random_password.root_pass.result

  tags      = var.tags
  swap_size = 256
  # private_ip = true
}