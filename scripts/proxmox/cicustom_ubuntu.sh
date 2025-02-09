cat << EOF | sudo tee /var/lib/vz/snippets/ubuntu.yaml
cloud-config
runcmd:
    - apt update
    - apt install -y qemu-guest-agent
    - reboot
EOF