// Real browser inputs against the exported game; snapshots are observation only.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const baseURL = process.env.WEB_URL || 'http://127.0.0.1:8060';
const output = new URL('../test-results/', import.meta.url);
const artifactPath = name => fileURLToPath(new URL(name, output));
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ channel: process.env.BROWSER_CHANNEL || 'chrome', headless: process.env.HEADED !== '1' });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const errors = [];
const checks = [];
page.on('pageerror', error => errors.push(error.message));
page.on('console', msg => {
  if (msg.type() === 'error') errors.push(msg.text());
});
const snapshot = () => page.evaluate(() => window.__breakfastBallsState);
async function waitFor(predicate, label, timeout = 90000) {
  await page.waitForFunction(predicate, null, { timeout });
  if (label) { checks.push(label); console.log(`PASS ${label}`); }
}
async function state(value, label = value) {
  await page.waitForFunction(value => window.__breakfastBallsState?.state === value, value, { timeout: 90000 });
  if (label) { checks.push(label); console.log(`PASS ${label}`); }
}
async function clickGame(x, y) {
  const box = await page.locator('#canvas').boundingBox();
  assert(box, 'canvas has a visible layout box');
  await page.mouse.click(box.x + x * box.width / 1280, box.y + y * box.height / 800);
}
async function key(key) { await page.keyboard.press(key); }
async function swing(duration = 600) {
  await page.keyboard.down('Space');
  await waitFor(() => window.__breakfastBallsState?.keyboard_charge, 'Space starts charging');
  await page.waitForTimeout(duration);
  await page.keyboard.up('Space');
  await state('flight', 'release launches the ball');
  await state('result', 'shot physically settles at a result');
}
async function leaveRound() {
  await key('Escape');
  await state('pause');
  await clickGame(640, 486);
  await state('menu', 'return to clubhouse');
}
async function launch() {
  await page.getByRole('button', { name: /play.*(browser|golf)|tee off|let.s play|enter.*clubhouse/i }).first().click();
  await state('menu', 'web engine loads into the clubhouse');
  // Keep gameplay input on the canvas, without clicking a game action.
  await page.locator('#canvas').focus();
}

try {
  await page.goto(baseURL);
  await page.screenshot({ path: artifactPath('web-launcher.png'), fullPage: true });
  await launch();
  const gl = await page.evaluate(() => {
    const gl = document.getElementById('canvas').getContext('webgl2');
    const ext = gl?.getExtension('WEBGL_debug_renderer_info');
    return { renderer: gl?.getParameter(ext ? ext.UNMASKED_RENDERER_WEBGL : gl.RENDERER),
      vendor: gl?.getParameter(ext ? ext.UNMASKED_VENDOR_WEBGL : gl.VENDOR) };
  });
  console.log('RENDERER', JSON.stringify(gl));
  await page.screenshot({ path: artifactPath('web-clubhouse.png') });

  // Preferences exercise actual IndexedDB persistence across a page reload.
  await clickGame(370, 670);
  await waitFor(() => window.__breakfastBallsState?.settings_open, 'open browser settings');
  await clickGame(755, 238);
  await waitFor(() => window.__breakfastBallsState?.input_style === 1, 'save mouse guidance');
  await clickGame(840, 670);
  await page.waitForTimeout(1800);
  await page.reload();
  await launch();
  assert.equal((await snapshot()).input_style, 1, 'browser preference survives reload');
  checks.push('browser preference survives reload');

  // Repeatable short-game scenes reached through the visible clubhouse button.
  await clickGame(232, 726);
  await state('aim', 'practice entered through the menu');
  assert.equal((await snapshot()).practice_station, 0);
  assert.equal((await snapshot()).club, 13);
  const origin = (await snapshot()).ball;
  await swing(550);
  assert.notDeepEqual((await snapshot()).ball, origin, 'ball moved physically');
  await key('r');
  await state('aim', 'R retries a practice shot');
  const retry = (await snapshot()).ball;
  assert(Math.hypot(retry.x - origin.x, retry.z - origin.z) < 0.01, 'retry returns to origin');
  for (const station of [1, 2]) {
    await key(String(station + 1));
    await page.waitForFunction(index => window.__breakfastBallsState?.practice_station === index, station);
    await swing(550);
    await page.screenshot({ path: artifactPath(`web-practice-${station}.png`) });
    await key('r'); await state('aim');
  }

  // Mouse/trackpad swing uses the same visible gold swing pad as the native game.
  const padBox = await page.locator('#canvas').boundingBox();
  const padPoint = (x, y) => ({ x: padBox.x + x * padBox.width / 1280, y: padBox.y + y * padBox.height / 800 });
  const top = padPoint(1100, 607);
  const bottom = padPoint(1100, 680);
  await page.mouse.move(top.x, top.y);
  await page.mouse.down();
  await waitFor(() => window.__breakfastBallsState?.dragging, 'mouse starts a swing on the gold pad');
  await page.mouse.move(bottom.x, bottom.y, { steps: 8 });
  await page.mouse.move(top.x, top.y, { steps: 8 });
  await page.mouse.up();
  await state('flight', 'mouse release launches a shot');
  await state('result', 'mouse shot settles');
  await key('r'); await state('aim');

  // Lost focus must cancel a charged shot; key release after returning cannot fire it.
  await page.keyboard.down('Space');
  await waitFor(() => window.__breakfastBallsState?.charge > 0.1, 'charge before focus loss');
  await page.locator('#canvas').evaluate(canvas => canvas.blur());
  await state('pause', 'focus loss pauses the game');
  assert.equal((await snapshot()).keyboard_charge, false);
  await page.keyboard.up('Space');
  await clickGame(640, 370);
  await state('aim', 'resume does not fire a stale shot');
  assert.equal((await snapshot()).strokes, 0);
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.locator('#canvas').focus();
  const resized = await page.locator('#canvas').boundingBox();
  assert(resized.width <= 1024 && resized.height <= 768, 'canvas fits the viewport');
  await page.screenshot({ path: artifactPath('web-resized.png') });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await leaveRound();

  // Original round journey, including scorecard and opening-shot Breakfast Ball.
  await key('Enter'); await state('name_entry', 'start normal round');
  await key('Enter'); await state('aim', 'confirm player name');
  await key('Tab'); await state('scorecard', 'Tab opens scorecard without moving browser focus');
  assert.equal(await page.evaluate(() => document.activeElement?.id), 'canvas');
  await key('Enter'); await state('aim', 'return from scorecard');
  await swing(650);
  assert.equal((await snapshot()).breakfast_offer, true, 'first tee shot offers Breakfast Ball');
  await key('b'); await state('aim', 'Breakfast Ball returns to tee');
  assert.equal((await snapshot()).strokes, 0);
  await swing(550);
  assert.equal((await snapshot()).breakfast_offer, false, 'Breakfast Ball cannot repeat');
  await key('Enter'); await state('aim', 'continue from shot result');
  await leaveRound();

  // Finish the entire three-pin mode through player inputs, not state injection.
  await clickGame(185, 305);
  await waitFor(() => window.__breakfastBallsState?.player_count === 2, 'select two-player hot-seat play');
  await clickGame(370, 390);
  await waitFor(() => window.__breakfastBallsState?.mode === 2, 'select Pin Challenge');
  await key('Enter'); await state('name_entry');
  await key('Enter');
  await page.waitForTimeout(350);
  await key('Enter'); await state('aim');
  for (let hole = 0; hole < 3; hole++) {
    await swing(650);
    await key('Enter'); await state('aim', 'pass controls to player two');
    assert.equal((await snapshot()).player_index, 1);
    await swing(650);
    await key('Enter'); await state('scorecard', `pin ${hole + 1} scorecard`);
    await key('Enter');
    await state(hole === 2 ? 'finished' : 'aim', hole === 2 ? 'finish complete Pin Challenge' : 'next pin');
  }
  await page.screenshot({ path: artifactPath('web-challenge-finished.png') });
  const last = await snapshot();
  assert.equal(errors.length, 0, `browser errors: ${errors.join('\n')}`);
  await writeFile(new URL('web-report.json', output), JSON.stringify({ url: baseURL, checks, renderer: gl, last, errors }, null, 2));
  console.log(`WEB_JOURNEY: ${checks.length} checks passed; zero browser errors.`);
} catch (error) {
  await page.screenshot({ path: artifactPath('web-failure.png') }).catch(() => {});
  console.error('STATE', JSON.stringify(await snapshot().catch(() => null)));
  console.error('BROWSER ERRORS', errors);
  throw error;
} finally {
  await browser.close();
}
