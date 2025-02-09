terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      # version = "3.0.2"
    }
  }
}

# Pulls the image
resource "docker_image" "npm-image-latest" {
  name = "jc21/nginx-proxy-manager:latest"
}

# Create a container
resource "docker_container" "npm-container-test" {
  image   = docker_image.npm-image-latest.image_id
  name    = "npm-test"
  restart = "unless-stopped"

  ports {
    internal = "80"
    external = "4080"
  }
  ports {
    internal = "81"
    external = "4081"
  }
  ports {
    internal = "443"
    external = "4443"
  }

  volumes {
    host_path      = "/home/aearles/home/docker/tf_npm-test/data"
    container_path = "/data"
    read_only      = false
  }
  volumes {
    host_path      = "/home/aearles/home/docker/tf_npm-test/letsencrypt"
    container_path = "/etc/letsencrypt"
    read_only      = false
  }

  provisioner "local-exec" {
    command = "powershell ${path.module}/change_password.ps1"
  }

}