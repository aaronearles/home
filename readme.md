## HOME 2.0
This repository is an attempt to rewrite all currently running infrastructure as code and use Git as the source of truth.

All code should support using variables to determine deployed environment (lab vs prod) and be generic enough that it can be shared for public use.

This repository is intended to remain Public to encourage good security practices and secret management.

Use this opportunity to redesign domain naming convention and use variables in traefik labels if possible (with preference for simplicity over ansible/jinja2 templates etc.)