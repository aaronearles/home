# Grok Bot web UI spike: the official app.asar under stock Electron, its renderer served to browsers
# by a relay (relay/). Reuses the Xpra POC image for the installed app, keyring and Xvfb.
FROM grokbot-xpra:local

USER root
ARG ELECTRON_VERSION=42.1.0
ARG ELECTRON_SHA256=882047343a9e203c6cfc5d39b166ea9e025dd256943e0d3711f86725ad0e3bd9
# Same Electron version the app ships with, so its native modules load; checksum from SHASUMS256.txt
RUN curl -fsSL -o /tmp/electron.zip \
      "https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-x64.zip" \
 && echo "${ELECTRON_SHA256}  /tmp/electron.zip" | sha256sum -c - \
 && python3 -I -c 'import os,sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); [(lambda p, m: m and os.chmod(p, m & 0o755))(z.extract(i, sys.argv[2]), i.external_attr >> 16) for i in z.infolist()]' /tmp/electron.zip /opt/electron \
 && rm /tmp/electron.zip

COPY relay/ /opt/grokbot-relay/
COPY grokbot-web-entrypoint /usr/local/bin/grokbot-web-entrypoint

USER grokbot
EXPOSE 14600
ENTRYPOINT ["/usr/local/bin/grokbot-web-entrypoint"]
