sudo docker run -it --rm \
-v ./data:/data \
-e SYNAPSE_SERVER_NAME=synapse.internal.earles.io \
-e SYNAPSE_REPORT_STATS=no \
matrixdotorg/synapse:latest generate
...
sudo chown aearles:aearles ./*

<!-- nano ./homeserver.yml
Comment sqlite3 3 lines and paste the following in it's place:

```
 name: psycopg2
 args:
   user: synapse_user
   password: <pass>
   database: synapse
   host: synapse-db
   cp_min: 5
   cp_max: 10
   ```

Save changes. -->

synapse  | Starting synapse with args -m synapse.app.homeserver --config-path /data/homeserver.yaml
synapse  | This server is configured to use 'matrix.org' as its trusted key server via the
synapse  | 'trusted_key_servers' config option. 'matrix.org' is a good choice for a key
synapse  | server since it is long-lived, stable and trusted. However, some admins may
synapse  | wish to use another server for this purpose.
synapse  |
synapse  | To suppress this warning and continue using 'matrix.org', admins should set
synapse  | 'suppress_key_server_warning' to 'true' in homeserver.yaml.