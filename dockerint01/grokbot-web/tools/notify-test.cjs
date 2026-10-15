// End-to-end check of relayed notifications (needs RELAY_DEBUG=1): a recording Notification stub in the
// page, a test notification from the relay, then a simulated click that must reach the relay
const { app, BrowserWindow } = require('electron');
const path = require('node:path');
app.whenReady().then(async () => {
  const w = new BrowserWindow({ show: true, width: 1280, height: 860,
    webPreferences: { partition: 'notify-test', contextIsolation: false, preload: path.join(__dirname, 'notify-stub.cjs') } });
  await w.loadURL(process.env.TEST_URL);
  await new Promise((r) => setTimeout(r, 15000));
  const before = await w.webContents.executeJavaScript('document.body.innerText.includes("Enable notifications")');
  await w.webContents.executeJavaScript('fetch("./__relay/debug/notify", { method: "POST" }).then((r) => r.text())');
  await new Promise((r) => setTimeout(r, 3000));
  const seen = await w.webContents.executeJavaScript('JSON.stringify(window.__shown.map(({ title, options }) => ({ title, tag: options.tag, icon: options.icon.replace(/^.*\\//, "") })))');
  await w.webContents.executeJavaScript('window.__shown.at(-1)?.onclick?.()');
  await new Promise((r) => setTimeout(r, 2000));
  const closed = await w.webContents.executeJavaScript('window.__shown.at(-1)?.closed === true');
  console.log('[notify-test]', JSON.stringify({ bannerWhileGranted: before, seen: JSON.parse(seen), closedAfterClick: closed }));
  app.quit();
});
