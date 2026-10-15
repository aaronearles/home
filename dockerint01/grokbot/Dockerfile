# Grok Bot (official Linux build) streamed to the browser with Xpra HTML5
# The vendor package in ./installer/ is installed as shipped; nothing in it is modified.
ARG DEBIAN_RELEASE=trixie
FROM debian:${DEBIAN_RELEASE}-slim

ARG DEBIAN_RELEASE
ARG INSTALLER
ARG APP_UID=1000
ARG APP_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=America/Denver

# Xpra (server + HTML5 client + audio) from the official xpra.org repository
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -fsSL https://xpra.org/xpra.asc -o /usr/share/keyrings/xpra.asc \
 && curl -fsSL https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/${DEBIAN_RELEASE}/xpra.sources \
      -o /etc/apt/sources.list.d/xpra.sources \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      xpra-server xpra-x11 xpra-codecs xpra-audio xpra-html5 \
      xvfb dbus dbus-x11 pulseaudio \
      gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
      gnome-keyring libsecret-tools \
      firefox-esr xdg-utils desktop-file-utils shared-mime-info \
      fonts-noto-core fonts-noto-color-emoji \
      libgtk-3-0t64 libnss3 libasound2t64 libgbm1 libsecret-1-0 libnotify4 \
      libxss1 libxtst6 libatspi2.0-0t64 libdrm2 libuuid1 \
      python3 squashfs-tools file \
 && rm -rf /var/lib/apt/lists/*

# Official installer: .deb is installed with apt, AppImage is unpacked (no FUSE in containers)
COPY installer/ /tmp/installer/
COPY rootfs/usr/local/bin/install-app /usr/local/bin/install-app
RUN test -n "${INSTALLER}" || { echo "Set GROKBOT_INSTALLER in .env" >&2; exit 1; } \
 && bash /usr/local/bin/install-app "/tmp/installer/${INSTALLER}" \
 # postinst makes chrome-sandbox setuid root when the build has no user namespaces. APP_ARGS runs
 # --no-sandbox, and the SUID fallback cannot exec from a path with a space ("/opt/Grok Bot"), so drop it
 && find /opt -name chrome-sandbox -type f -exec chmod 0755 {} + \
 && rm -rf /tmp/installer /var/lib/apt/lists/*

# Unprivileged session user; no sudo/pkexec, so in-app updaters cannot install anything
RUN groupadd -g ${APP_GID} grokbot \
 && useradd -m -u ${APP_UID} -g ${APP_GID} -s /bin/bash grokbot \
 && install -d -o grokbot -g grokbot -m 0700 /run/user/${APP_UID} \
 && install -d -o grokbot -g grokbot -m 0775 /run/xpra

COPY rootfs/ /
RUN chmod 0755 /usr/local/bin/grokbot-entrypoint /usr/local/bin/grokbot-session

USER grokbot
WORKDIR /home/grokbot
ENV HOME=/home/grokbot \
    XDG_RUNTIME_DIR=/run/user/${APP_UID}

EXPOSE 14500
ENTRYPOINT ["/usr/local/bin/grokbot-entrypoint"]
