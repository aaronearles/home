## Status
 - [X] Default/Internal Cert -- *.earles.internal Working.
    - [ ] Review cert filenames for consistency.
    - [ ] Test alternate/specific certs.
 - [X] Let's Encrypt w/ cloudflare DNS Challenge -- Working
 - [X] HTTP Redirect -- Global redirect (in traefik.yaml) Working
 - [...] WAF -- In-progress, need to review config and ruleset
 - [X] BasicAuth -- Working!
 - [...] Authentik/SSO -- In-Progress. Container is UP and accessible but no further config.
 - [ ] Rename traefik.yaml, etc. to config-static.yaml and config-dynamic.yaml, file provider path, etc. to align w/ Traefik docs.
 - [ ] Move API Dashboard to HTTPS. What port? Or disable altogether?


## Config Documentation
https://traefik.io/blog/traefik-2-0-docker-101-fc2893944b9d/

https://doc.traefik.io/traefik/routing/routers/

## WAF
https://traefik.io/blog/traefik-3-deep-dive-into-wasm-support-with-coraza-waf-plugin/
https://plugins.traefik.io/plugins/65f2aea146079255c9ffd1ec/coraza-waf

Need to review:
- https://coraza.io/docs/tutorials/coreruleset/
- https://github.com/coreruleset/coreruleset
- https://plugins.traefik.io/plugins/628c9ebcffc0cd18356a979f/fail2-ban

## Authentik / SSO

## To-do before exposing to internet
 - WAF
 - SSO
 - DMZ Firewall Rules