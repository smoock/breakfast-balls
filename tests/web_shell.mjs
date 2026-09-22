// Launcher/browser integration checks against the real exported game.
// Run with the preview server active: node tests/web_shell.mjs
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const baseURL = process.env.WEB_URL || 'http://127.0.0.1:8060';
const browserOptions = { channel: process.env.BROWSER_CHANNEL || 'chrome', headless: true };
const checks = [];
const pass = message => { checks.push(message); console.log(`PASS ${message}`); };
const browser = await chromium.launch(browserOptions);
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  const downloads = [];
  page.on('request', request => {
    if (/\.(wasm|pck)(\?|$)/.test(request.url())) downloads.push(request.url());
  });
  await page.goto(baseURL);
  assert.equal(downloads.length, 0);
  pass('game payload downloads only after Play');
  await page.getByRole('button', { name: 'Controls', exact: true }).focus();
  await page.keyboard.press('Enter');
  assert.equal(await page.locator('#help').evaluate(dialog => dialog.open), true);
  await page.keyboard.press('Escape');
  assert.equal(await page.locator('#help').evaluate(dialog => dialog.open), false);
  assert.equal(await page.evaluate(() => document.activeElement.id), 'controls');
  pass('keyboard opens/closes controls and restores focus');
  await page.getByRole('button', { name: 'Play in browser' }).click();
  await page.waitForFunction(() => document.documentElement.dataset.gameState === 'playing', null, { timeout: 90000 });
  assert(downloads.length >= 2);
  const bounds = await page.locator('#canvas').boundingBox();
  assert(Math.abs(bounds.width / bounds.height - 1.6) < 0.001);
  pass('one Play click starts real engine with exact 16:10 canvas');
  await page.keyboard.press('Shift+Tab');
  assert.equal(await page.evaluate(() => document.activeElement.id), 'controls');
  await page.getByRole('button', { name: 'Back to game' }).click();
  assert.equal(await page.evaluate(() => document.activeElement.id), 'canvas');
  pass('Shift+Tab leaves game input and Back to game restores focus');
  if (await page.evaluate(() => document.fullscreenEnabled)) {
    await page.getByRole('button', { name: /Full screen/ }).click();
    await page.waitForFunction(() => Boolean(document.fullscreenElement));
    await page.getByRole('button', { name: /Exit full screen/ }).click();
    await page.waitForFunction(() => !document.fullscreenElement);
    pass('user gestures enter and exit fullscreen');
  }
  await page.close();

  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await mobile.goto(baseURL);
  assert.equal(await mobile.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  await mobile.getByRole('button', { name: 'Controls', exact: true }).click();
  assert.equal(await mobile.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  pass('mobile landing and controls have no horizontal overflow');
  await mobile.close();

  const offline = await browser.newPage();
  await offline.route('**/index.js', route => route.abort('failed'));
  await offline.goto(baseURL);
  await offline.getByRole('button', { name: 'Play in browser' }).click();
  await offline.waitForFunction(() => document.documentElement.dataset.gameState === 'error', null, { timeout: 90000 });
  assert(await offline.locator('#error-message').textContent());
  await offline.getByRole('button', { name: 'Try again' }).click();
  await offline.waitForFunction(() => document.documentElement.dataset.gameState === 'idle');
  pass('failed engine script download shows error and retry reloads cleanly');
  await offline.close();

  const noJS = await browser.newPage({ javaScriptEnabled: false });
  await noJS.goto(baseURL);
  assert.equal(await noJS.locator('noscript').isVisible(), true);
  assert.equal(await noJS.getByRole('button', { name: 'Play in browser' }).isDisabled(), true);
  pass('JavaScript-disabled page explains the requirement');
  await noJS.close();
} finally {
  await browser.close();
}

// Real browser feature restriction, without substituting the engine or game state.
const unsupported = await chromium.launch({ ...browserOptions, args: ['--disable-webgl'] });
try {
  const page = await unsupported.newPage();
  await page.goto(baseURL);
  await page.getByRole('button', { name: 'Play in browser' }).click();
  assert.equal(await page.locator('html').getAttribute('data-game-state'), 'error');
  assert.match(await page.locator('#error-message').textContent(), /WebGL 2/);
  pass('browser without WebGL gets an actionable fallback');
} finally {
  await unsupported.close();
}
console.log(`\n${checks.length} shell checks passed.`);
