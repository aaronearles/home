terraform {
  required_providers {
    nginxproxymanager = {
      source = "sander0542/nginxproxymanager"
    }
  }
}

provider "nginxproxymanager" {
  #   host     = "http://npm.internal:81" #Pass NGINX_PROXY_MANAGER_HOST instead
  #   username = "terraform@example.com" #Pass NGINX_PROXY_MANAGER_USERNAME instead
  #   password = "" #Pass NGINX_PROXY_MANAGER_PASSWORD instead
  host     = "http://docker.earles.internal:4081" #Pass NGINX_PROXY_MANAGER_HOST instead
  username = "admin@example.com"                  #Pass NGINX_PROXY_MANAGER_USERNAME instead
  password = "newpassword"                           #Pass NGINX_PROXY_MANAGER_PASSWORD instead
}


# Fetch all proxy hosts
data "nginxproxymanager_proxy_hosts" "all" {}

# output "nginxproxymanager_proxy_hosts_id" {
#   value = data.nginxproxymanager_proxy_hosts.all
# }


# Manage a proxy host
resource "nginxproxymanager_proxy_host" "example" {
  domain_names = ["example.com"]

  forward_scheme = "https"
  forward_host   = "example2.com"
  forward_port   = 443

  caching_enabled         = true
  allow_websocket_upgrade = true
  block_exploits          = true

  access_list_id = 0 # Publicly Accessible

  location {
    path           = "/admin"
    forward_scheme = "https"
    forward_host   = "example3.com"
    forward_port   = 443

    advanced_config = ""
  }

  location {
    path           = "/contact"
    forward_scheme = "http"
    forward_host   = "example4.com"
    forward_port   = 80

    advanced_config = ""
  }

  certificate_id  = 0 # No Certificate
  ssl_forced      = false
  hsts_enabled    = false
  hsts_subdomains = false
  http2_support   = false

  advanced_config = ""
}