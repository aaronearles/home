#!/bin/sh
Xvfb :98 -screen 0 1280x860x24 -nolisten tcp >/dev/null 2>&1 &
sleep 1
DISPLAY=:98 exec /opt/electron/electron /test/notify-test.cjs --no-sandbox --disable-gpu 2>&1 | grep -vE 'bus\.cc|object_proxy|system_bus_socket|dbus'
