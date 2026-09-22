import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const url = process.env.WEB_URL || 'https://breakfast-balls.vercel.app';
const output = new URL('../test-results/', import.meta.url);
await mkdir(output, { recursive: true });
const local = JSON.parse(await readFile(new URL('../builds/web/build-info.json', import.meta.url), 'utf8'));
const response = await fetch(url + '/build-info.json');
assert.equal(response.status, 200);
assert.deepEqual(await response.json(), local, 'public build matches the tested local manifest');
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = [];
page.on('pageerror', e => errors.push(e.message));
page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
const waitState = state => page.waitForFunction(state => window.__breakfastBallsState?.state === state, state, { timeout: 90000 });
try {
  await page.goto(url);
  assert.equal(await page.evaluate(() => window.isSecureContext), true);
  await page.locator('#play').click();
  await waitState('menu');
  console.log('PASS public HTTPS build launches');
  const box = await page.locator('#canvas').boundingBox();
  await page.mouse.click(box.x + 232 * box.width / 1280, box.y + 726 * box.height / 800);
  await waitState('aim');
  await page.keyboard.down('Space');
  await page.waitForFunction(() => window.__breakfastBallsState?.charge > 0.3);
  await page.keyboard.up('Space');
  await waitState('flight');
  await waitState('result');
  console.log('PASS public game completes a real practice shot');
  assert.equal(errors.length, 0, errors.join('\n'));
  await page.screenshot({ path: fileURLToPath(new URL('web-live.png', output)) });
  await writeFile(new URL('web-live-report.json', output), JSON.stringify({ url, manifestMatches: true,
    errors, state: await page.evaluate(() => window.__breakfastBallsState) }, null, 2));
  console.log('LIVE_SMOKE: manifest matches, playable shot, zero browser errors.');
} finally { await browser.close(); }
