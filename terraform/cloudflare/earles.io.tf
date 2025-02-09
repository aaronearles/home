resource "cloudflare_record" "terraform_managed_resource_983597cbb894f749892aa5163152b03c" {
  content = "65.130.222.208"
  name    = "vpn"
  proxied = false
  ttl     = 1
  type    = "A"
  # value   = "65.130.222.208"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_71dc219883d11c9b0e3f7ac98bc82b62" {
  content = "173.255.253.233"
  name    = "watchman"
  proxied = false
  ttl     = 1
  type    = "A"
  # value   = "173.255.253.233"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_710b080a2b7ffa4b5eeb5d54d35eb6bd" {
  comment = "Redirect to Cloudflare Access App Portal."
  content = "aearles.cloudflareaccess.com"
  name    = "earles.io"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  # value   = "aearles.cloudflareaccess.com"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_5a9360ea46006215f284c28fd964e8cf" {
  content = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  name    = "proxmox"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  # value   = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_2316e5d0ed4dc9ba8b1eac33aa4818b0" {
  comment = "Cloudflare Access App for browser SSH to 'pve' host."
  content = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  name    = "ssh"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  # value   = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_5527122430ddf75cafbb6efd2f92475d" {
  content = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  name    = "synology"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  # value   = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_cb70a05025535107390701586aa78298" {
  content = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  name    = "unifi"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  # value   = "ed8c2fae-9ffd-4f47-bf67-709333e00bb4.cfargotunnel.com"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_47a3287c761e171d99f4a059e9c7527c" {
  content = "aearles.cloudflareaccess.com"
  name    = "www"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  # value   = "aearles.cloudflareaccess.com"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_e4376d8d33cb7efd110fa64a75e954f8" {
  content  = "route3.mx.cloudflare.net"
  name     = "earles.io"
  priority = 21
  proxied  = false
  ttl      = 1
  type     = "MX"
  # value    = "route3.mx.cloudflare.net"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_7d4d5d036d9d72ae80f10aa3f2e6b7cc" {
  content  = "route2.mx.cloudflare.net"
  name     = "earles.io"
  priority = 61
  proxied  = false
  ttl      = 1
  type     = "MX"
  # value    = "route2.mx.cloudflare.net"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_e2d5e14ed666742bcb937dfed012d9cd" {
  content  = "route1.mx.cloudflare.net"
  name     = "earles.io"
  priority = 40
  proxied  = false
  ttl      = 1
  type     = "MX"
  # value    = "route1.mx.cloudflare.net"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

resource "cloudflare_record" "terraform_managed_resource_2c1588d1d7b022259879dd4f3373d683" {
  content = "v=spf1 ip4:65.130.222.208 include:earles.io include:_spf.mx.cloudflare.net ~all"
  name    = "earles.io"
  proxied = false
  ttl     = 1
  type    = "TXT"
  # value   = "v=spf1 ip4:65.130.222.208 include:earles.io include:_spf.mx.cloudflare.net ~all"
  zone_id = "3df85645994c6bd1399d9a2221ef6213"
}

