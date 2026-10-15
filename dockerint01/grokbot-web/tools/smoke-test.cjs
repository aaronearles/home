// Headless browser check for the Grok Bot web relay: load the page, log console + failures, screenshot
const { app, BrowserWindow } = require('electron');
const fs = require('node:fs');
const URL_ = process.env.TEST_URL;
const WAIT = Number(process.env.TEST_WAIT_MS || 20000);
app.whenReady().then(async () => {
  // TEST_SHOW=1: a visible, focused window, so the page reports itself as present (focused tab)
  const w = new BrowserWindow({ show: process.env.TEST_SHOW === '1', width: 1280, height: 860, webPreferences: { partition: 'test' } });
  if (process.env.TEST_SHOW === '1') w.focus();
  const wc = w.webContents;
  wc.on('console-message', (e) => {
    const msg = e.message; const lvl = e.level;
    if (!/Download the React DevTools/.test(msg)) console.log(`[console:${lvl}]`, String(msg).slice(0, 400));
  });
  wc.on('did-fail-load', (_e, code, desc, url) => console.log('[fail-load]', code, desc, url));
  wc.session.webRequest.onCompleted((d) => { if (d.statusCode >= 400) console.log('[http]', d.statusCode, d.url.slice(0, 160)); });
  wc.session.webRequest.onErrorOccurred((d) => { if (!/ERR_ABORTED/.test(d.error)) console.log('[net-error]', d.error, d.url.slice(0, 160)); });
  wc.setWindowOpenHandler(({ url }) => { console.log('[window.open]', url.replace(/(challenge|uuid)=[^&]+/g, '$1=…')); return { action: 'deny' }; });
  try { await wc.loadURL(URL_); } catch (err) { console.log('[load-error]', err.message); }
  await new Promise((r) => setTimeout(r, WAIT));
  if (process.env.TEST_CLICK) {
    const clicked = await wc.executeJavaScript(`(() => { const b = [...document.querySelectorAll('button,a')].find(e => e.innerText.trim().startsWith(${JSON.stringify(process.env.TEST_CLICK)})); if (!b) return false; b.click(); return true; })()`);
    console.log('[click]', process.env.TEST_CLICK, clicked);
    await new Promise((r) => setTimeout(r, 6000));
  }
  if (process.env.TEST_SAFE !== '1') fs.writeFileSync('/out/shot.png', (await wc.capturePage()).toPNG());
  const text = await wc.executeJavaScript('document.body ? document.body.innerText.slice(0, 1500) : "(no body)"').catch((e) => 'ERR ' + e.message);
  const globals = await wc.executeJavaScript('JSON.stringify({desktop: typeof window.desktop, coordinatorPort: typeof window.coordinatorPort, root: (document.getElementById("root")||{}).childElementCount})').catch((e) => e.message);
  console.log('[globals]', globals);
  if (process.env.TEST_SAFE === '1') {
    // Privacy-safe probe for a signed-in session: structure only, no page text
    const probe = await wc.executeJavaScript(`JSON.stringify({
      composer: !!document.querySelector('[contenteditable="true"], textarea'),
      sidebarItems: document.querySelectorAll('nav a, nav button, [role="listitem"], [role="option"]').length,
      textChars: (document.body.innerText || '').length,
      signInScreen: /Sign in/.test(document.body.innerText || '') && !document.querySelector('[contenteditable="true"]'),
      couldntRefresh: ((document.body.innerText || '').match(/Couldn.t refresh/g) || []).length,
    })`).catch((e) => e.message);
    console.log('[probe]', probe);
  } else {
    console.log('[text]', JSON.stringify(text));
  }
  app.quit();
});
