FROM node:22-alpine

# Bitwarden CLI provides `bw serve`, a local REST API that handles Bitwarden's
# client-side encryption. Pinned: new CLI releases occasionally need a newer
# Vaultwarden. Bump together and check the sync logs after.
ARG BW_CLI_VERSION=2026.9.1
RUN npm install -g --omit=dev @bitwarden/cli@${BW_CLI_VERSION} \
 && npm cache clean --force

WORKDIR /app
COPY sync.mjs .

# bw keeps its (encrypted) local vault cache in the home dir. It's rebuilt on
# every start, so no volume is needed.
USER node
ENV BITWARDENCLI_APPDATA_DIR=/home/node/.config/bw \
    NODE_ENV=production

# Healthy = a sync cycle succeeded in the last 30 minutes.
HEALTHCHECK --interval=60s --timeout=5s --start-period=120s \
  CMD node -e "const t=+require('fs').readFileSync('/tmp/last-success','utf8');process.exit(Date.now()-t<1800000?0:1)"

CMD ["node", "sync.mjs"]
