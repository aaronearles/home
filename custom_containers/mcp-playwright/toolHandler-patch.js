#!/usr/bin/env node

// Patch for toolHandler to use system browsers
import { getBrowserLaunchOptions } from './browser-config.js';

// Override the browser launch function
export function patchBrowserLaunch() {
  // Set environment variables for Playwright to use system browsers
  process.env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = '1';
  process.env.PLAYWRIGHT_BROWSERS_PATH = '0'; // Use system browsers
  
  // Override Chrome executable path to use the environment variable
  if (!process.env.CHROME_EXECUTABLE_PATH) {
    process.env.CHROME_EXECUTABLE_PATH = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH || '/usr/bin/chromium';
  }
  
  console.log('Browser configuration:');
  console.log('- Chromium:', process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH);
  console.log('- Firefox:', process.env.PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH);
  console.log('- Chrome fallback:', process.env.CHROME_EXECUTABLE_PATH);
}