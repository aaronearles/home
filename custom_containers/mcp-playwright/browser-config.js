#!/usr/bin/env node

// Browser configuration override for system browsers
export function getBrowserLaunchOptions(browserType = 'chromium') {
  const baseOptions = {
    headless: true, // Run headless in container
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--disable-gpu',
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      '--disable-features=TranslateUI',
      '--disable-ipc-flooding-protection',
      '--single-process'
    ]
  };

  switch (browserType) {
    case 'firefox':
      return {
        ...baseOptions,
        executablePath: process.env.PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH || '/usr/bin/firefox-esr',
        args: [
          '--headless',
          '--no-sandbox',
          '--disable-gpu'
        ]
      };
    
    case 'webkit':
      return {
        ...baseOptions,
        executablePath: '/usr/bin/webkit', // May not be available
        args: [
          '--headless',
          '--no-sandbox'
        ]
      };
    
    case 'chromium':
    default:
      return {
        ...baseOptions,
        executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH || '/usr/bin/chromium',
      };
  }
}