terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      # version = "3.0.2"
    }
    nginxproxymanager = {
      source = "sander0542/nginxproxymanager"
    }
  }
}

provider "docker" {
  host = "tcp://docker.earles.internal:2375" #Needs to be enabled, see notes.txt
  # host = "unix:///var/run/docker.sock" #If running terraform locally.
  # host     = "ssh://aearles@docker.earles.internal" #SSH doesn't seem to be supported in Windows.
  # ssh_opts = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]
}

provider "nginxproxymanager" {
  #   host     = "http://npm.internal:81" #Pass NGINX_PROXY_MANAGER_HOST instead
  #   username = "terraform@example.com" #Pass NGINX_PROXY_MANAGER_USERNAME instead
  #   password = "" #Pass NGINX_PROXY_MANAGER_PASSWORD instead
  host     = "http://docker.earles.internal:4081" #Pass NGINX_PROXY_MANAGER_HOST instead
  username = "admin@example.com"                  #Pass NGINX_PROXY_MANAGER_USERNAME instead
  password = "newpassword"                           #Pass NGINX_PROXY_MANAGER_PASSWORD instead
}

module "docker" {
  source = "./docker"
}

module "npm" {
  source     = "./npm"
  depends_on = [module.docker]
}