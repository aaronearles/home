#!/usr/bin/env bash
# Point every stored link at a new domain: posts, pages, comments, settings, plugin tables.
# Backs up the database first, then runs WP-CLI search-replace (safe for serialized settings),
# for http:// and https://, with and without www, and Jetpack's image CDN copies of the old site
# (i0/i1/i2.wp.com/<old host>/..., which stop working once the old host is gone). GUIDs are left
# alone, as WordPress requires. Email addresses at the old domain (e.g. in contact forms) are not
# URLs and are not changed.
#
#   ./change-domain.sh <old host> <new base URL> [--dry-run]
#   ./change-domain.sh whitegirlroadtrip.com https://blog.internal.earles.io --dry-run
#
# Run on the Docker host from the deploy folder (the one with .env), with the stack running.
# BACKUP_DIR (default ./backups) is where the gzipped dump goes.
set -euo pipefail
cd "$(dirname "$0")"

old=${1:?usage: $0 <old host> <new base URL> [--dry-run]}
new=${2:?usage: $0 <old host> <new base URL> [--dry-run]}
dry=${3:-}
[[ $old != *://* && $old != */* ]] || { echo "old host is a bare hostname, e.g. whitegirlroadtrip.com" >&2; exit 1; }
[[ $new =~ ^https?://[^/]+$ ]] || { echo "new base URL is scheme + host with no trailing slash, e.g. https://blog.example.com" >&2; exit 1; }
[[ -z $dry || $dry == --dry-run ]] || { echo "third argument can only be --dry-run" >&2; exit 1; }
[ -f .env ] || { echo "no .env here: run this from the deploy folder" >&2; exit 1; }

# The running stack's WordPress files and database network
html=$(docker inspect blog-wordpress -f '{{range .Mounts}}{{if eq .Destination "/var/www/html"}}{{.Source}}{{end}}{{end}}')
net=$(docker inspect blog-db -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' | awk '{print $1}')
if [ -z "$html" ] || [ -z "$net" ]; then echo "blog-wordpress and blog-db must be running" >&2; exit 1; fi

wp() {
  docker run --rm -i --network "$net" --env-file .env -v "$html:/var/www/html:ro" --user 33:33 \
    wordpress:cli wp --skip-plugins --skip-themes "$@"
}

if [ -z "$dry" ]; then
  backup_dir=${BACKUP_DIR:-backups}
  mkdir -p "$backup_dir"
  dump="$backup_dir/db-before-$(printf %s "$old" | tr -c 'a-zA-Z0-9.-' _)-$(date +%Y%m%d-%H%M%S).sql.gz"
  # MySQL's own mysqldump, inside blog-db (WP-CLI's MariaDB client rejects MySQL's self-signed TLS cert)
  docker exec blog-db sh -c 'exec mysqldump --no-tablespaces --single-transaction --add-drop-table \
    -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" 2>/dev/null' | gzip > "$dump"
  [ "$(gzip -dc "$dump" | tail -c 200 | grep -c 'Dump completed')" = 1 ] || { echo "backup $dump looks incomplete; stopping" >&2; exit 1; }
  echo "backup: $dump ($(du -h "$dump" | cut -f1))"
fi

total=0
for from in "http://$old" "https://$old" "http://www.$old" "https://www.$old" \
    "https://i0.wp.com/$old" "https://i1.wp.com/$old" "https://i2.wp.com/$old" \
    "http://i0.wp.com/$old" "http://i1.wp.com/$old" "http://i2.wp.com/$old"; do
  n=$(wp search-replace "$from" "$new" --skip-columns=guid --all-tables-with-prefix --format=count ${dry:+--dry-run})
  printf '%-45s %s\n' "$from" "$n"
  total=$((total + n))
done
if [ -n "$dry" ]; then echo "would replace $total in total (dry run: nothing changed)"; else echo "replaced $total in total"; fi

if [ -z "$dry" ]; then
  wp cache flush >/dev/null
  echo "cache flushed. Check: $new"
fi
