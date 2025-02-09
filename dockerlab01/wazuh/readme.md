## Installation Notes
### https://documentation.wazuh.com/current/deployment-options/docker/docker-installation.html

Wazuh indexer creates many memory-mapped areas. So you need to set the kernel to give a process at least 262,144 memory-mapped areas.

- Increase max_map_count on your Docker host:
`sysctl -w vm.max_map_count=262144`
- Update the `vm.max_map_count` setting in `/etc/sysctl.conf` to set this value permanently. To verify after rebooting, run `sysctl vm.max_map_count`.

##
Difficulty mapping ports in Traefik, ended up just publishing them as-is for testing. Agent installation fails in LXC. Docker ulimits fail in LXC.
Created LAB --> DOCKERINT firewall rule for port group Wazuh (1514-agent, 1515-enroll, 514-syslog, 50000-api)