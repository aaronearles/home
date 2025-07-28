# VyOS Ansible Framework

A comprehensive Ansible framework for managing VyOS routers in Proxmox environments, based on the blog series "Proxmox Network Inside Network with VyOS" by 0lzi.

## Overview

This framework provides automated configuration management for VyOS routers with the following capabilities:
- **Base System Configuration**: Hostname, DNS, NTP, SSH, and login banners
- **User Management**: User accounts with SSH key authentication
- **Network Configuration**: Interface setup, routing, DHCP, and NAT
- **Firewall Management**: Rule-based security with network and port groups

## Architecture

```
vyos/ansible/
├── ansible.cfg                 # Ansible configuration
├── inventories/
│   └── hosts.yml              # Router inventory and network definitions
├── group_vars/
│   └── vyos_routers.yml       # Global variables for all routers
├── roles/
│   ├── vyos_base/             # Base system configuration
│   ├── vyos_users/            # User account management
│   ├── vyos_network/          # Network and routing configuration
│   ├── vyos_firewall/         # Firewall rules and policies
│   ├── vyos_vpn/              # WireGuard VPN server configuration
│   ├── vyos_qos/              # Quality of Service traffic shaping
│   └── vyos_monitoring/       # Monitoring, logging, and SNMP
└── playbooks/
    ├── vyos_full_deploy.yml      # Complete router deployment
    ├── vyos_initial_setup.yml    # First-time setup with default credentials
    ├── vyos_network_only.yml     # Network configuration only
    └── vyos_optional_features.yml # Advanced features (VPN, QoS, monitoring)
```

## Quick Start

### Prerequisites

1. Install required Ansible collections:
```bash
ansible-galaxy collection install vyos.vyos
```

2. Configure your router inventory in `inventories/hosts.yml`
3. Update network configurations in the inventory file
4. Modify global variables in `group_vars/vyos_routers.yml`

### Initial Setup (Default Credentials)

For new VyOS installations with default vyos/vyos credentials:

```bash
ansible-playbook -i inventories/hosts.yml playbooks/vyos_initial_setup.yml \
  -e'ansible_user=vyos ansible_password=vyos' --diff
```

### Full Deployment

After initial setup with SSH keys configured:

```bash
ansible-playbook -i inventories/hosts.yml playbooks/vyos_full_deploy.yml --diff
```

### Network Configuration Only

To update only network settings:

```bash
ansible-playbook -i inventories/hosts.yml playbooks/vyos_network_only.yml \
  --tags network --diff
```

### Optional Features Deployment

To deploy advanced features (VPN, QoS, monitoring):

```bash
# Deploy all enabled optional features
ansible-playbook -i inventories/hosts.yml playbooks/vyos_optional_features.yml --diff

# Deploy only VPN features
ansible-playbook -i inventories/hosts.yml playbooks/vyos_optional_features.yml \
  --tags vpn --diff

# Deploy only monitoring features  
ansible-playbook -i inventories/hosts.yml playbooks/vyos_optional_features.yml \
  --tags monitoring --diff
```

## Configuration Examples

### Network Definition (from blog posts)

Based on the 0lzi blog series, here's an example network configuration:

```yaml
# In inventories/hosts.yml
vyos-lab-01:
  ansible_host: 10.0.10.254
  networks:
    0:  # WAN Interface
      address: 192.168.1.251/24
      cidr: 192.168.1.0/24
      description: home
      gateway: 192.168.1.254
      interface: eth1
      wan: true
    1:  # LAN Interface
      address: 10.0.10.254/24
      cidr: 10.0.10.0/24
      description: lab
      interface: eth0
      wan: false
      dhcp:
        enabled: true
        range_start: 10.0.10.1
        range_stop: 10.0.10.100
```

### Firewall Configuration

The framework automatically configures:
- **Global state policies** (established, related, invalid)
- **Network groups** for inside/outside networks
- **Port groups** for common services
- **Input/Forward filtering** with default deny policies

### User Management

Configure users with SSH key authentication:

```yaml
# In group_vars/vyos_routers.yml
vyos_users:
  - name: admin
    full_name: "VyOS Administrator"
    level: admin
    ssh_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample admin@homelab"
```

### Optional Features Configuration

#### WireGuard VPN Server

Enable and configure VPN access:

```yaml
# In group_vars/vyos_routers.yml or host_vars/
vyos_wireguard_enabled: true
vyos_wireguard_network: 10.100.0.0/24
vyos_wireguard_port: 51820

vyos_wireguard_clients:
  - name: laptop
    public_key: "client_public_key_here"
    allowed_ips: "10.100.0.10/32"
    description: "User Laptop"
  - name: phone  
    public_key: "client_public_key_here"
    allowed_ips: "10.100.0.11/32"
    description: "User Phone"
```

#### Quality of Service (QoS)

Configure traffic shaping and bandwidth management:

```yaml
# In group_vars/vyos_routers.yml or host_vars/
vyos_qos_enabled: true

vyos_qos_interface_assignments:
  - interface: "eth1" 
    direction: "out"
    policy: "wan-upload"
```

#### Monitoring and Logging

Enable SNMP monitoring and centralized logging:

```yaml
# In group_vars/vyos_routers.yml or host_vars/
vyos_monitoring_enabled: true
vyos_snmp_enabled: true
vyos_snmp_community: "homelab_ro"

vyos_syslog_remote_servers:
  - host: "192.168.1.100"
    port: 514
    protocol: "udp" 
    facility: "all"
    level: "info"
```

## Proxmox Integration

This framework is designed to work seamlessly with Proxmox's Software Defined Networking (SDN) using VXLAN technology.

### Proxmox SDN Setup

#### 1. Create VXLAN Zone
```bash
# In Proxmox web interface or via CLI
pvesh create /cluster/sdn/zones --zone lab-vxlan --type vxlan --peers 192.168.1.100
```

#### 2. Create Virtual Network (VNET)
```bash
# Create VNET for lab network
pvesh create /cluster/sdn/vnets --vnet lab-net --zone lab-vxlan --tag 100
```

#### 3. Create Subnet
```bash
# Define subnet for the lab network
pvesh create /cluster/sdn/vnets/lab-net/subnets --subnet 10.0.10.0/24 --type subnet --gateway 10.0.10.254
```

#### 4. Apply SDN Configuration
```bash
# Apply the SDN configuration
pvesh set /cluster/sdn
```

### VyOS VM Configuration in Proxmox

#### VM Requirements
- **CPU**: 2 cores minimum (4 recommended)
- **RAM**: 2GB minimum (4GB recommended for advanced features)
- **Storage**: 8GB minimum for VyOS installation
- **Network Interfaces**: 2 required
  - **net0**: Bridged to home network (vmbr0)
  - **net1**: Connected to VXLAN VNET (lab-net)

#### VM Creation Example
```bash
# Create VyOS VM via Proxmox CLI
qm create 200 \
  --name vyos-lab-router \
  --cores 2 \
  --memory 2048 \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr0,tag=100 \
  --ide2 local:iso/vyos-1.4-rolling.iso,media=cdrom \
  --bootdisk scsi0 \
  --scsi0 local-lvm:8 \
  --ostype l26 \
  --boot order=ide2
```

### Network Mapping

| Proxmox Interface | VyOS Interface | Purpose | Network |
|-------------------|----------------|---------|---------|
| net0 (vmbr0) | eth1 | WAN/Home | 192.168.1.0/24 |
| net1 (VXLAN) | eth0 | LAN/Lab | 10.0.10.0/24 |

### Post-Installation Steps

1. **Boot VyOS VM** and perform initial installation
2. **Install to disk**: `install image`
3. **Configure initial network access** for Ansible connectivity
4. **Run initial setup playbook** with default credentials
5. **Execute full deployment** with SSH key authentication

### Troubleshooting Proxmox Integration

#### Common Issues
- **VXLAN not working**: Verify firewall allows UDP port 4789
- **Network isolation**: Ensure VNET configuration is applied
- **VM network**: Check interface assignments match configuration
- **SDN changes**: Reload network configuration after SDN updates

#### Verification Commands
```bash
# Check VXLAN tunnel
ip -d link show

# Verify bridge configuration  
brctl show

# Test network connectivity
ping -I eth0 10.0.10.1
```

## Key Features from Blog Posts

### Network Inside Network Architecture
- **Proxmox SDN with VXLAN** for network isolation
- **Dual-interface setup** (WAN: home network, LAN: lab network)
- **DHCP server** for internal networks
- **NAT/Masquerading** for internet access

### Automated Configuration
- **Jinja2 templating** for dynamic configurations
- **Modular roles** for different configuration aspects
- **Idempotent operations** ensuring consistent state
- **Infrastructure as Code** approach

### Security Features
- **Firewall rules** with network and port groups
- **SSH key-only authentication** (password auth disabled)
- **Network segmentation** between WAN and LAN
- **Stateful connection tracking**

## Playbook Tags

Use tags for selective execution:

```bash
# Configure only users
ansible-playbook playbooks/vyos_full_deploy.yml --tags users

# Configure network and firewall
ansible-playbook playbooks/vyos_full_deploy.yml --tags network,firewall

# Skip firewall configuration
ansible-playbook playbooks/vyos_full_deploy.yml --skip-tags firewall

# Deploy only optional features
ansible-playbook playbooks/vyos_full_deploy.yml --tags optional

# Deploy specific optional features
ansible-playbook playbooks/vyos_full_deploy.yml --tags vpn
ansible-playbook playbooks/vyos_full_deploy.yml --tags qos
ansible-playbook playbooks/vyos_full_deploy.yml --tags monitoring
```

## Common Commands

### Connectivity Testing
```bash
# Test connectivity to all routers
ansible vyos_routers -m vyos.vyos.vyos_command -a "commands='show version'"

# Check interface status
ansible vyos_routers -m vyos.vyos.vyos_command -a "commands='show interfaces'"
```

### Configuration Verification
```bash
# Show current configuration
ansible vyos_routers -m vyos.vyos.vyos_command -a "commands='show configuration'"

# Show routing table
ansible vyos_routers -m vyos.vyos.vyos_command -a "commands='show ip route'"

# Show firewall status
ansible vyos_routers -m vyos.vyos.vyos_command -a "commands='show firewall'"
```

### Backup and Restore
```bash
# Backup configuration
ansible vyos_routers -m vyos.vyos.vyos_command -a "commands='show configuration'" > vyos_backup.txt

# Save configuration
ansible vyos_routers -m vyos.vyos.vyos_config -a "save: true"
```

## Troubleshooting

### Common Issues

1. **Connection refused**: Ensure SSH is enabled and accessible
2. **Authentication failed**: Verify SSH keys or use password authentication for initial setup
3. **Network unreachable**: Check network connectivity and firewall rules
4. **Configuration not saved**: Ensure save handlers are executed

### Debug Mode

Run playbooks with increased verbosity:
```bash
ansible-playbook playbooks/vyos_full_deploy.yml -vvv
```

## Contributing

This framework follows the Ansible standards defined in `../../standards/ansible.md`:
- 2-space YAML indentation
- Descriptive task names
- Proper error handling
- Comprehensive documentation
- Idempotent operations

## References

- [0lzi Blog Series: Proxmox Network Inside Network with VyOS](https://blog.0lzi.com/proxmox-network-inside-network-with-vyos-1)
- [VyOS Documentation](https://docs.vyos.io/)
- [Ansible VyOS Collection](https://docs.ansible.com/ansible/latest/collections/vyos/vyos/)
- [Proxmox SDN Documentation](https://pve.proxmox.com/wiki/Software_Defined_Network)