# blog

WordPress (Earles Gone Wild) and MySQL, at https://blog.internal.earles.io through Traefik.

The running deployment is `/home/aearles/blog` on dockerint01: it holds `.env`, `mysql-init.sql`
and the database (`data/mysql`), none of which are in git. Starting the stack from a checkout of this
folder instead would create an empty site and clash with the running containers' names.

## Changing the domain

WordPress stores absolute URLs in posts, settings and plugin tables. To move every stored link from
one host to another (this was done once, from `whitegirlroadtrip.com`):

```bash
./change-domain.sh <old host> <new base URL> --dry-run   # counts only
./change-domain.sh <old host> <new base URL>             # backs up the database, then replaces
```

Run it on dockerint01 with the stack up, from a folder holding the deployment's `.env` (or a link to
it). It dumps the database to `./backups` first, covers http/https, `www.` and Jetpack's
`i0/i1/i2.wp.com` image CDN copies, and leaves GUIDs alone: Disqus and feed readers key on them.
To change the site address itself, pass the current host as `<old host>`; that updates the `home`
and `siteurl` settings along with everything else.
