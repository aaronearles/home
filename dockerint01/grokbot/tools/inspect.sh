#!/bin/bash
# Phase 1 inspection of the official Grok Bot installer. Read-only: never executes the app.
# Runs in a throwaway container so nothing from the package touches the host:
#
#   docker run --rm --network none \
#     -v "$PWD/installer:/in:ro" -v "$PWD/tools:/tools:ro" -v "$PWD/scratch:/out" \
#     grokbot-inspect bash /tools/inspect.sh "/in/<installer file>"
#
# grokbot-inspect is built from tools/Dockerfile.inspect (see README.md)
# Report: scratch/REPORT.md; unpacked package: scratch/pkg; extracted app.asar: scratch/asar
set -uo pipefail

pkg="$1"
out=/out
rm -rf "$out/pkg" "$out/asar"
mkdir -p "$out/pkg" "$out/asar"
exec > >(tee "$out/REPORT.md") 2>&1

h() { printf '\n## %s\n\n' "$*"; }
code() { printf '```\n'; cat; printf '```\n'; }

echo "# Grok Bot installer inspection"
echo
echo "- File: \`$(basename "$pkg")\`"
echo "- SHA-256: \`$(sha256sum "$pkg" | cut -d' ' -f1)\`"
echo "- Type: $(file -b "$pkg")"

h "Package metadata and dependencies"
case "$pkg" in
  *.deb)
    dpkg-deb -f "$pkg" Package Version Architecture Depends Recommends | code
    dpkg-deb -x "$pkg" "$out/pkg"
    mkdir -p "$out/pkg/DEBIAN" && dpkg-deb -e "$pkg" "$out/pkg/DEBIAN"
    for s in postinst prerm postrm; do
      [ -f "$out/pkg/DEBIAN/$s" ] && { echo "maintainer script \`$s\`:"; code < "$out/pkg/DEBIAN/$s"; }
    done
    ;;
  *.rpm)
    rpm -qip --requires "$pkg" 2>/dev/null | code
    (cd "$out/pkg" && rpm2cpio "$pkg" | cpio -idm --quiet)
    rpm -qp --scripts "$pkg" 2>/dev/null | code
    ;;
  *.AppImage|*.appimage)
    offset="$(python3 -I -c 'import struct,sys
d=open(sys.argv[1],"rb").read(64)
shoff,=struct.unpack_from("<Q",d,0x28); shentsize,shnum=struct.unpack_from("<HH",d,0x3A)
print(shoff+shentsize*shnum)' "$pkg")"
    unsquashfs -q -f -o "$offset" -d "$out/pkg" "$pkg"
    echo "AppImage: no declared dependencies (bundled); squashfs offset $offset"
    ;;
esac

asar="$(find "$out/pkg" -path '*/resources/app.asar' | head -1)"
resdir="$(dirname "$asar")"
appdir="$(dirname "$resdir")"
bin="$(find "$appdir" -maxdepth 1 -type f -perm -u+x -size +50M | head -1)"

h "Electron / Chromium version"
strings -n 8 "$bin" | grep -m1 -oE 'Chrome/[0-9.]+ Electron/[0-9.]+' | code
echo "Main binary: \`${bin#$out/pkg}\`"

h "Desktop entry (URL schemes)"
find "$out/pkg" -name '*.desktop' -exec grep -HE '^(Name|Exec|MimeType)=' {} \; | sed "s|$out/pkg||" | code

h "Updater feed"
for f in "$resdir"/app-update.yml "$resdir"/*update*; do [ -f "$f" ] && { echo "\`${f#$out/pkg}\`:"; code < "$f"; }; done
ls "$resdir" | code

h "app.asar"
asar extract "$asar" "$out/asar"
node -e 'const p=require(process.argv[1]);console.log(JSON.stringify({name:p.name,productName:p.productName,version:p.version,main:p.main,dependencies:p.dependencies},null,2))' "$out/asar/package.json" | code

h "Native .node modules"
find "$out/asar" "$resdir/app.asar.unpacked" -name '*.node' 2>/dev/null | while read -r n; do
  printf '%s\n  NEEDED: %s\n' "${n#$out/}" "$(readelf -d "$n" 2>/dev/null | sed -nE 's/.*Shared library: \[(.*)\]/\1/p' | xargs)"
done | code

# Search the bundled JS (minified bundles: print a short window around each hit)
js() { grep -rhoE ".{0,90}($1).{0,90}" --include='*.js' --include='*.cjs' --include='*.mjs' --exclude-dir=node_modules "$out/asar" | sort -u | head -${2:-15} | code; }

h "Main window: loadURL / loadFile"
js 'loadURL\(|loadFile\(' 20
echo "Remote origins referenced:"
grep -rhoE 'https://[a-zA-Z0-9.-]+\.[a-z]{2,}' --include='*.js' --exclude-dir=node_modules "$out/asar" | sed -E 's|(https://[^/]+).*|\1|' | sort | uniq -c | sort -rn | head -20 | code

h "Sign-in return path"
echo "Custom URL scheme:"; js 'setAsDefaultProtocolClient|open-url|second-instance'
echo "Localhost callback:"; js 'createServer\(|\.listen\(|127\.0\.0\.1|localhost:[0-9]'
echo "Device code:"; js 'device_code|verification_uri|user_code|device/code'
echo "External browser:"; js 'shell\.openExternal' 10

h "Keyring, GPU, D-Bus"
echo "Secret storage:"; js 'safeStorage|keytar|libsecret|setPassword|getPassword' 10
echo "GPU:"; js 'disableHardwareAcceleration|appendSwitch\(|commandLine\.append' 15
echo "D-Bus / desktop integration:"; js 'dbus|globalShortcut|powerSaveBlocker|new Notification|Tray\(' 10
echo "Auto-update:"; js 'autoUpdater|electron-updater|checkForUpdates|update-electron-app' 15

h "IPC surface (for Phase 4)"
echo "ipcMain handlers: $(grep -rhoE 'ipcMain\.(handle|on|once)\(["'"'"'][^"'"'"']+' --include='*.js' "$out/asar" | sort -u | wc -l)"
echo "contextBridge exposures:"; js 'contextBridge\.exposeInMainWorld' 10
echo "Main-process modules used by renderer-facing code:"; js 'webContents\.(executeJavaScript|debugger)|BrowserView|WebContentsView|session\.(fromPartition|defaultSession)' 15
