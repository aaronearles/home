# UniFi Network Controller API Project

## Project Overview

This project provides tools and documentation for interacting with the UniFi Network Controller API. The UniFi controller manages network infrastructure including access points, switches, and other UniFi devices.

## API Access Configuration

The UniFi Network Controller is accessible at `https://unifi.earles.internal` with API endpoints under `/proxy/network/api/`.

**Authentication**: Uses X-API-KEY header authentication
```bash
curl -k -s -H "X-API-KEY: YOUR_API_KEY" https://unifi.earles.internal/proxy/network/api/ENDPOINT
```

## Available API Endpoints

### Device Information
- **Endpoint**: `/proxy/network/api/s/default/stat/device`
- **Method**: GET
- **Description**: Returns comprehensive device information including access points, switches, and network equipment

### User Self Information  
- **Endpoint**: `/proxy/network/api/self`
- **Method**: GET
- **Description**: Returns current user information, permissions, and UI preferences

### Network Configuration
- **Endpoint**: `/proxy/network/api/s/default/rest/networkconf`
- **Method**: GET
- **Description**: Returns all configured networks/VLANs including WAN, corporate, guest, and VPN networks

### WiFi Configuration
- **Endpoint**: `/proxy/network/api/s/default/rest/wlanconf`
- **Method**: GET/POST
- **Description**: Manage WiFi SSID configurations. GET returns all SSIDs, POST creates new SSID

### AP Groups
- **Endpoint**: `/proxy/network/api/s/default/rest/wlangroup`
- **Method**: GET
- **Description**: Returns access point group configurations

## API Response Structure

### Device Stats Response
The device API returns detailed information for all network devices:

**Key Device Properties:**
- `_id`: Device unique identifier
- `name`: Device display name  
- `model`: Hardware model (e.g., "U7PRO")
- `version`: Firmware version
- `ip`: Device IP address
- `mac`: Device MAC address
- `state`: Connection state (1 = connected)
- `uptime`: Device uptime in seconds
- `last_seen`: Last contact timestamp

**Radio Information** (`radio_table`):
- Multiple radio configurations (2.4GHz, 5GHz, 6E)
- Channel assignments, power levels, capabilities
- WiFi standards supported (11ac, 11ax, 11be)

**VAP (Virtual Access Point) Table** (`vap_table`):
- Per-SSID statistics and configuration
- Client counts, data throughput, signal strength
- Channel utilization and performance metrics

**Network Statistics**:
- Uplink information and connection details
- Throughput statistics (tx_bytes, rx_bytes)
- System performance metrics (CPU, memory, load average)

### User Self Response
Contains user account information and UI preferences:
- Admin permissions and site access
- UI settings and preferences  
- Table column configurations
- Dashboard layout preferences

## Common Use Cases

**Monitor Network Health**:
```bash
curl -k -s -H "X-API-KEY: YOUR_KEY" https://unifi.earles.internal/proxy/network/api/s/default/stat/device | jq '.data[] | {name, model, state, uptime, satisfaction}'
```

**Check WiFi Performance**:
```bash
curl -k -s -H "X-API-KEY: YOUR_KEY" https://unifi.earles.internal/proxy/network/api/s/default/stat/device | jq '.data[].vap_table[] | {essid, num_sta, satisfaction, channel}'
```

**Device Status Summary**:
```bash
curl -k -s -H "X-API-KEY: YOUR_KEY" https://unifi.earles.internal/proxy/network/api/s/default/stat/device | jq '.data[] | {name, ip, version, last_seen}'
```

**List All Networks/VLANs**:
```bash
curl -k -s -H "X-API-KEY: YOUR_KEY" https://unifi.earles.internal/proxy/network/api/s/default/rest/networkconf | jq '.data[] | {name, purpose, vlan, ip_subnet}'
```

**List All WiFi SSIDs**:
```bash
curl -k -s -H "X-API-KEY: YOUR_KEY" https://unifi.earles.internal/proxy/network/api/s/default/rest/wlanconf | jq '.data[] | {name, enabled, is_guest, security}'
```

## WiFi SSID Management

### Creating a New WiFi Network

To create a new WiFi SSID, you need the network ID of the target network (from networkconf) and the AP group ID (from wlangroup).

**Required Parameters for New SSID:**
- `name`: SSID name
- `x_passphrase`: WiFi password
- `usergroup_id`: Network ID from networkconf (for guest networks use Guest network ID)
- `networkconf_id`: Same as usergroup_id
- `security`: "wpapsk" for WPA-PSK
- `wpa_mode`: "wpa2" 
- `wpa_enc`: "ccmp"
- `enabled`: true/false
- `is_guest`: true for guest networks
- `ap_group_ids`: Array with AP group ID (usually ["658e451259e64d0d340146f0"])
- `ap_group_mode`: "all"
- `wlan_bands`: ["2g", "5g"] for both bands

**Example - Create Guest WiFi Network:**
```bash
curl -k -s -X POST -H "X-API-KEY: YOUR_KEY" -H "Content-Type: application/json" \
  -d '{
    "name": "testtest",
    "x_passphrase": "111222333",
    "usergroup_id": "65c403bbd62b19314831ad56",
    "networkconf_id": "65c403bbd62b19314831ad56", 
    "security": "wpapsk",
    "wpa_mode": "wpa2",
    "wpa_enc": "ccmp",
    "enabled": true,
    "is_guest": true,
    "hide_ssid": false,
    "ap_group_mode": "all",
    "ap_group_ids": ["658e451259e64d0d340146f0"],
    "wlan_band": "both",
    "wlan_bands": ["2g", "5g"],
    "l2_isolation": false,
    "proxy_arp": false,
    "uapsd_enabled": false,
    "fast_roaming_enabled": false,
    "bss_transition": true,
    "mac_filter_enabled": false,
    "mac_filter_policy": "allow",
    "mac_filter_list": [],
    "radius_mac_auth_enabled": false,
    "mcastenhance_enabled": false,
    "no2ghz_oui": true,
    "minrate_ng_enabled": true,
    "minrate_ng_data_rate_kbps": 1000,
    "minrate_na_enabled": false,
    "minrate_na_data_rate_kbps": 6000,
    "dtim_mode": "default",
    "dtim_ng": 1,
    "dtim_na": 3,
    "group_rekey": 0
  }' \
  https://unifi.earles.internal/proxy/network/api/s/default/rest/wlanconf
```

### Network Configuration Reference

**Current Environment Networks:**
- **Guest Network**: ID `65c403bbd62b19314831ad56` (VLAN 30, 172.20.30.1/24)
- **Default AP Group**: ID `658e451259e64d0d340146f0`

**Network Purposes:**
- `wan`: WAN connections
- `corporate`: Internal networks  
- `guest`: Guest networks
- `remote-user-vpn`: VPN networks

### Deleting a WiFi Network

To delete an existing WiFi SSID, use the DELETE method with the SSID's unique ID.

**Delete WiFi SSID:**
```bash
curl -k -s -X DELETE -H "X-API-KEY: YOUR_KEY" \
  https://unifi.earles.internal/proxy/network/api/s/default/rest/wlanconf/SSID_ID
```

**Example - Delete SSID by ID:**
```bash
curl -k -s -X DELETE -H "X-API-KEY: YOUR_KEY" \
  https://unifi.earles.internal/proxy/network/api/s/default/rest/wlanconf/687732cd2369e15ea0e50e54
```

**Verify Deletion:**
```bash
curl -k -s -H "X-API-KEY: YOUR_KEY" \
  https://unifi.earles.internal/proxy/network/api/s/default/rest/wlanconf | \
  jq '.data[] | select(.name == "SSID_NAME")'
```

The SSID will be immediately removed from all access points and stop broadcasting.

## Project Structure

This directory contains tools and scripts for working with the UniFi Network Controller API, providing network monitoring and management capabilities.