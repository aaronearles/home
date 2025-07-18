#!/usr/bin/env node

// Override Playwright launch behavior to use system browsers
const originalModule = await import('./dist/toolHandler.js');

// Replace the ensureBrowser function with our own implementation
if (originalModule.ensureBrowser) {
  console.log('Overriding ensureBrowser function...');
  
  const { chromium, firefox, webkit } = await import('playwright');
  
  let browser;
  let page;
  let currentBrowserType = 'chromium';
  
  function resetBrowserState() {
    browser = undefined;
    page = undefined;
  }
  
  // Our custom ensureBrowser function
  async function customEnsureBrowser(browserSettings) {
    try {
      // Check if browser exists but is disconnected
      if (browser && !browser.isConnected()) {
        console.error("Browser exists but is disconnected. Cleaning up...");
        try {
          await browser.close().catch(err => console.error("Error closing disconnected browser:", err));
        } catch (e) {
          // Ignore errors when closing disconnected browser
        }
        resetBrowserState();
      }

      // Launch new browser if needed
      if (!browser) {
        const { viewport, userAgent, headless = true, browserType = 'chromium' } = browserSettings ?? {};
        
        console.error(`Launching new ${browserType} browser instance with system executable...`);
        
        // Use the appropriate browser engine
        let browserInstance;
        let executablePath;
        
        switch (browserType) {
          case 'firefox':
            browserInstance = firefox;
            executablePath = '/usr/bin/firefox-esr';
            break;
          case 'webkit':
            browserInstance = webkit;
            executablePath = '/usr/bin/webkit'; // May not be available
            break;
          case 'chromium':
          default:
            browserInstance = chromium;
            executablePath = '/usr/bin/chromium';
            break;
        }

        console.log(`Using executable: ${executablePath}`);

        browser = await browserInstance.launch({
          headless,
          executablePath,
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
            '--disable-ipc-flooding-protection'
          ]
        });
        
        currentBrowserType = browserType;

        // Add cleanup logic when browser is disconnected
        browser.on('disconnected', () => {
          console.error("Browser disconnected event triggered");
          browser = undefined;
          page = undefined;
        });

        const context = await browser.newContext({
          ...userAgent && { userAgent },
          viewport: {
            width: viewport?.width ?? 1280,
            height: viewport?.height ?? 720,
          },
          deviceScaleFactor: 1,
        });

        page = await context.newPage();
      }

      return page;
    } catch (error) {
      console.error('Failed to initialize browser:', error.message);
      throw new Error(`Failed to initialize browser: ${error.message}. Please try again.`);
    }
  }
  
  // Override the original function
  originalModule.ensureBrowser = customEnsureBrowser;
}

export * from './dist/toolHandler.js';