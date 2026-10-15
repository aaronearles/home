# Grok Bot web UI: the official app.asar under stock Electron, its renderer served to browsers by a relay
# (relay/). Self-contained: does not need the Xpra POC image or a local installer.
ARG DEBIAN_RELEASE=trixie
FROM debian:${DEBIAN_RELEASE}-slim

ARG APP_UID=1000
ARG APP_GID=1000
# Official Grok Bot package. Only its resources/ (app.asar) and icons are used, so it is unpacked
# with dpkg-deb -x and its maintainer scripts (apt source, setuid chrome-sandbox) never run.
# Updating: new URL + SHA-256, and check ELECTRON_VERSION still matches the app's Electron.
ARG GROKBOT_VERSION=0.70.2
ARG GROKBOT_DEB_URL=https://downloads.cursor.com/grokbot/stable/52da656f56d317510ca65ad6af3d69a2cde461e0/linux/x64/grok-bot_0.70.2_amd64.deb
ARG GROKBOT_DEB_SHA256=ff70fc2173f9827be1648cbeaf39c7c1212a3fd9b2326c5028be8a2fdbef0900
# Same Electron version the app ships with, so its native modules load; checksum from SHASUMS256.txt
ARG ELECTRON_VERSION=42.1.0
ARG ELECTRON_SHA256=882047343a9e203c6cfc5d39b166ea9e025dd256943e0d3711f86725ad0e3bd9

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=America/Denver

# Electron runtime libraries (the .deb's Depends), a virtual display, session bus and keyring
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl python3 \
      xvfb dbus-daemon gnome-keyring \
      libgtk-3-0t64 libnotify4 libnss3 libxss1 libxtst6 xdg-utils libatspi2.0-0t64 libuuid1 \
      libsecret-1-0 libasound2t64 libgbm1 libxkbcommon0 libdrm2 \
 && rm -rf /var/lib/apt/lists/* \
 && install -d -m 1777 /tmp/.X11-unix

RUN curl -fsSL -o /tmp/grok-bot.deb "${GROKBOT_DEB_URL}" \
 && echo "${GROKBOT_DEB_SHA256}  /tmp/grok-bot.deb" | sha256sum -c - \
 && dpkg-deb -x /tmp/grok-bot.deb /tmp/grok-bot \
 && install -d "/opt/Grok Bot" \
 && mv "/tmp/grok-bot/opt/Grok Bot/resources" "/opt/Grok Bot/resources" \
 && cp -r /tmp/grok-bot/usr/share/icons /usr/share/ \
 && rm -rf /tmp/grok-bot /tmp/grok-bot.deb \
 && curl -fsSL -o /tmp/electron.zip \
      "https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-x64.zip" \
 && echo "${ELECTRON_SHA256}  /tmp/electron.zip" | sha256sum -c - \
 && python3 -I -c 'import os,sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); [(lambda p, m: m and os.chmod(p, m & 0o755))(z.extract(i, sys.argv[2]), i.external_attr >> 16) for i in z.infolist()]' /tmp/electron.zip /opt/electron \
 && rm /tmp/electron.zip

# Unprivileged session user
RUN groupadd -g ${APP_GID} grokbot \
 && useradd -m -u ${APP_UID} -g ${APP_GID} -s /bin/bash grokbot \
 && install -d -o grokbot -g grokbot -m 0700 /run/user/${APP_UID}

COPY relay/ /opt/grokbot-relay/
COPY grokbot-web-entrypoint /usr/local/bin/grokbot-web-entrypoint

USER grokbot
WORKDIR /home/grokbot
ENV HOME=/home/grokbot \
    XDG_RUNTIME_DIR=/run/user/${APP_UID}

EXPOSE 14600
ENTRYPOINT ["/usr/local/bin/grokbot-web-entrypoint"]
