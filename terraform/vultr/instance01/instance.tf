resource "vultr_instance" "instance01" {
  plan                = var.plan
  region              = var.region
  os_id               = var.os_id
  label               = var.label
  tags                = var.tags
  hostname            = var.hostname
  enable_ipv6         = false
  disable_public_ipv4 = false
  backups             = "disabled"
  # backups_schedule {
  #         type = "daily"
  # }
  ddos_protection  = var.ddos_protection
  activation_email = var.activation_email

  ssh_key_ids = var.ssh_key_ids
}