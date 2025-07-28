# VyOS Configuration Examples

This document contains practical configuration examples extracted from the 0lzi blog series and adapted for the Ansible framework.

## Blog Post Summary

The configuration examples are based on the five-part blog series:

1. **Part 1**: Initial VyOS setup in Proxmox with VXLAN networking
2. **Part 2**: Basic interface, routing, and service configuration
3. **Part 3**: Ansible automation with Jinja2 templating
4. **Part 4**: Advanced network configuration with YAML data structures
5. **Part 5**: Firewall rules and security policies

## Manual Configuration Examples

### Basic Interface Setup (from Part 2)

```bash
# Configure outside interface (WAN)
set interfaces ethernet eth1 address 192.168.1.251/24
set interfaces ethernet eth1 description OUTSIDE

# Configure inside interface (LAN) 
set interfaces ethernet eth0 address 10.0.10.254/24
set interfaces ethernet eth0 description INSIDE

# Default route
set protocols static route 0.0.0.0/0 next-hop 192.168.1.254

# DNS servers  
set system name-server 192.168.1.114
set system name-server 192.168.1.115
```

### DHCP Server Configuration

```bash
# DHCP server for lab network
set service dhcp-server shared-network-name LAB authoritative
set service dhcp-server shared-network-name LAB subnet 10.0.10.0/24 range 0 start 10.0.10.1
set service dhcp-server shared-network-name LAB subnet 10.0.10.0/24 range 0 stop 10.0.10.100
set service dhcp-server shared-network-name LAB subnet 10.0.10.0/24 default-router 10.0.10.254
set service dhcp-server shared-network-name LAB subnet 10.0.10.0/24 name-server 192.168.1.114
```

### NAT Configuration

```bash
# Source NAT for internal network
set nat source rule 1 outbound-interface name eth1
set nat source rule 1 source address 10.0.10.0/24
set nat source rule 1 translation address masquerade
```

### Firewall Rules

```bash
# Global firewall options
set firewall global-options state-policy established action 'accept'
set firewall global-options state-policy invalid action 'drop'
set firewall global-options state-policy related action 'accept'

# Network groups
set firewall group network-group NET-INSIDE network 10.0.10.0/24
set firewall group network-group NET-OUTSIDE network 192.168.1.0/24

# Input filter default policy
set firewall ipv4 input filter default-action drop
set firewall ipv4 forward filter default-action drop

# Allow established connections
set firewall ipv4 input filter rule 10 action accept
set firewall ipv4 input filter rule 10 state established
set firewall ipv4 input filter rule 10 state related

# Allow SSH from internal network
set firewall ipv4 input filter rule 20 action accept
set firewall ipv4 input filter rule 20 protocol tcp
set firewall ipv4 input filter rule 20 destination port 22
set firewall ipv4 input filter rule 20 source group network-group NET-INSIDE
```

## Ansible Variable Examples

### Network Definition Structure (from Part 4)

```yaml
# Host-specific network configuration
networks:
  0:  # WAN Interface
    address: 192.168.1.252/24
    cidr: 192.168.1.0/24
    description: home
    gateway: 192.168.1.254/24
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

### Port Groups Configuration (from Part 5)

```yaml
port_groups:
  tcp_ports:
    - 22    # SSH
    - 80    # HTTP  
    - 443   # HTTPS
    - 647   # DHCP Failover
    - 8000  # Alternative HTTP
  udp_ports:
    - 67    # DHCP Server
    - 68    # DHCP Client
    - 123   # NTP
    - 53    # DNS
  mixed_ports:
    - 53    # DNS (TCP/UDP)
    - 123   # NTP
  special_ports:
    - 51820 # WireGuard
    - 500   # IPsec IKE
    - 4500  # IPsec NAT-T
```

### Firewall Network Groups

```yaml
firewall_groups:
  network_groups:
    NET-INSIDE:
      - 10.0.10.0/24
      - 10.0.20.0/24
    NET-OUTSIDE:
      - 192.168.1.0/24
    NET-DMZ:
      - 10.0.100.0/24
```

## Advanced Configuration Examples

### Multi-Network Router

```yaml
# Advanced multi-network configuration
networks:
  0:  # WAN
    address: 192.168.1.252/24  
    cidr: 192.168.1.0/24
    description: home
    gateway: 192.168.1.254
    interface: eth1
    wan: true
  1:  # LAN
    address: 10.0.10.254/24
    cidr: 10.0.10.0/24  
    description: lab
    interface: eth0
    wan: false
    dhcp:
      enabled: true
      range_start: 10.0.10.1
      range_stop: 10.0.10.100
  2:  # DMZ
    address: 10.0.100.254/24
    cidr: 10.0.100.0/24
    description: dmz  
    interface: eth2
    wan: false
    dhcp:
      enabled: true
      range_start: 10.0.100.50
      range_stop: 10.0.100.200
```

### User Configuration with Multiple SSH Keys

```yaml
vyos_users:
  - name: admin
    full_name: "Primary Administrator"
    level: admin
    ssh_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey1 admin@workstation"
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... admin@laptop"
  - name: operator  
    full_name: "Network Operator"
    level: operator
    ssh_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey2 operator@homelab"
```

## Jinja2 Template Examples

### Dynamic Interface Configuration

```jinja2
{# From vyos_network role templates #}
{% for network_id, network in networks.items() %}
set interfaces ethernet {{ network.interface }} address {{ network.address }}
set interfaces ethernet {{ network.interface }} description {{ network.description | upper }}
{% if network.wan is defined and network.wan %}
set protocols static route 0.0.0.0/0 next-hop {{ network.gateway | regex_replace('/.*', '') }}
{% endif %}
{% endfor %}
```

### Dynamic DHCP Configuration  

```jinja2
{# DHCP server template #}
{% for network_id, network in networks.items() %}
{% if network.dhcp is defined and network.dhcp.enabled %}
set service dhcp-server shared-network-name {{ network.description | upper }} authoritative
set service dhcp-server shared-network-name {{ network.description | upper }} subnet {{ network.cidr }} range 0 start {{ network.dhcp.range_start }}
set service dhcp-server shared-network-name {{ network.description | upper }} subnet {{ network.cidr }} range 0 stop {{ network.dhcp.range_stop }}
set service dhcp-server shared-network-name {{ network.description | upper }} subnet {{ network.cidr }} default-router {{ network.address | regex_replace('/.*', '') }}
{% endif %}
{% endfor %}
```

### Dynamic Firewall Rules

```jinja2  
{# Firewall network groups #}
{% for group_name, networks in firewall_groups.network_groups.items() %}
{% for network in networks %}
set firewall group network-group {{ group_name }} network {{ network }}
{% endfor %}
{% endfor %}

{# Port groups #}
{% for port in port_groups.tcp_ports %}
set firewall group port-group TCP-PORTS port {{ port }}
{% endfor %}
```

## Testing Commands

### Verify Configuration

```bash
# Show interfaces
show interfaces

# Show routing table  
show ip route

# Show DHCP leases
show dhcp server leases

# Show NAT rules
show nat source rules

# Show firewall rules
show firewall ipv4 input filter  
show firewall ipv4 forward filter

# Show firewall groups
show firewall group
```

### Network Connectivity Tests

```bash
# Test DNS resolution
nslookup google.com

# Test internet connectivity
ping 8.8.8.8

# Test internal network
ping 10.0.10.1

# Show DHCP statistics  
show dhcp server statistics
```

## Integration with Proxmox

### VXLAN Network Setup (from Part 1)

1. **Create VXLAN zone** in Proxmox SDN
2. **Configure VNET** with VXLAN ID
3. **Attach VyOS VM** to both home network and VXLAN
4. **Configure interfaces** in VyOS to match Proxmox setup

### VM Requirements

- **Minimum specs**: 2 cores, 2GB RAM
- **Network interfaces**: 2 (home network + VXLAN)  
- **Boot order**: VyOS ISO, then install to disk
- **Initial credentials**: vyos/vyos (change immediately)

This framework automates the manual configuration process described in the blog posts, providing a repeatable and maintainable approach to VyOS router management.