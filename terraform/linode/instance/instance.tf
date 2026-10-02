# Generate a random password
resource "random_password" "root_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Fetch public SSH keys from GitHub (skipped if github_user is blank)
data "http" "github_keys" {
  count = trimspace(var.github_user) != "" ? 1 : 0
  url   = "https://github.com/${var.github_user}.keys"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to fetch SSH keys for GitHub user ${var.github_user}."
    }
  }
}

locals {
  github_keys     = flatten([for r in data.http.github_keys : split("\n", r.response_body)])
  authorized_keys = distinct(compact([for k in concat(var.authorized_keys, local.github_keys) : trimspace(k)]))
}

# Create a Linode
resource "linode_instance" "instance01" {
  label           = var.instance_label
  image           = var.image
  stackscript_id  = var.stackscript_id != "" ? var.stackscript_id : null
  region          = "us-west"
  type            = "g6-nanode-1"
  authorized_keys = local.authorized_keys
  root_pass       = random_password.root_pass.result

  tags      = var.tags
  swap_size = 256
  # private_ip = true

  lifecycle {
    # Keys only apply at creation; changing them would force replacement
    ignore_changes = [authorized_keys]

    precondition {
      condition     = length(local.authorized_keys) > 0
      error_message = "No SSH keys found. Set authorized_keys and/or github_user (with keys at https://github.com/<user>.keys)."
    }
  }
}