// Two independent browser contexts play the same room through visible controls.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const url = process.env.WEB_URL || 'http://127.0.0.1:8061';
const artifacts = new URL('../test-results/', import.meta.url);
await mkdir(artifacts, { recursive: true });
const browser = await chromium.launch({ channel: 'chrome', headless: process.env.HEADED !== '1' });
const contexts = await Promise.all([browser.newContext(), browser.newContext()]);
const pages = await Promise.all(contexts.map(context => context.newPage()));
const errors = [];
const checks = [];
for (const [index, page] of pages.entries()) {
  await page.setViewportSize({ width: 1440, height: 1000 });
  page.on('pageerror', error => errors.push(`seat ${index}: ${error.message}`));
  page.on('response', async response => {
    if (response.url().endsWith('/api/room') && response.status() >= 400) {
      const body = await response.json().catch(() => ({}));
      console.log(`ROOM seat ${index + 1}: ${response.status()} ${body.error || ''} ${body.message || ''}`);
    }
  });
  page.on('console', message => {
    if (message.type() === 'error') errors.push(`seat ${index}: ${message.text()}`);
  });
}
const [host, guest] = pages;
const state = page => page.evaluate(() => window.__breakfastBallsState);
const pass = label => { checks.push(label); console.log('PASS', label); };
async function wait(page, predicate, argument = null) {
  await page.waitForFunction(predicate, argument, { timeout: 90000 });
}
async function phase(page, expected) {
  await wait(page, expected => window.__breakfastBallsState?.state === expected, expected);
}
async function settledPair(expected, seat) {
  for (const page of pages) {
    await wait(page, ({ expected, seat }) => {
      const s = window.__breakfastBallsState;
      return s?.state === expected && s.player_index === seat && !s.online_pending;
    }, { expected, seat });
  }
  // Wait for the saved revision to reach both clients, not just predicted visuals.
  const revision = (await state(pages[seat])).online_revision;
  await wait(pages[1 - seat], revision => window.__breakfastBallsState?.online_revision === revision, revision);
  const snapshots = await Promise.all(pages.map(state));
  assert.deepEqual(snapshots[0].player_strokes, snapshots[1].player_strokes);
  assert.deepEqual(snapshots[0].player_scores, snapshots[1].player_scores);
  assert.deepEqual(snapshots[0].ball, snapshots[1].ball);
}
async function swing(seat) {
  const player = pages[seat];
  const watcher = pages[1 - seat];
  await wait(player, () => window.__breakfastBallsState?.online_can_act && !window.__breakfastBallsState?.online_pending);
  await player.locator('#canvas').focus();
  await player.keyboard.down('Space');
  await wait(player, () => window.__breakfastBallsState?.charge > 0.3);
  await player.keyboard.up('Space');
  await phase(player, 'flight');
  await phase(watcher, 'flight');
  pass(`seat ${seat + 1} swings and the other computer watches flight`);
  await settledPair('result', seat);
  pass('both computers agree on the saved shot result');
}
async function advance(seat) {
  await pages[seat].locator('#canvas').focus();
  await pages[seat].keyboard.press('Enter');
}

try {
  await host.goto(url);
  await host.locator('#play-online').click();
  await host.locator('#online-name').fill('ALPHA');
  await host.locator('#online-mode').selectOption('2');
  await host.locator('#online-create').click();
  await host.locator('#online-room-code').waitFor({ state: 'visible' });
  const code = (await host.locator('#online-room-code').textContent()).trim();
  console.log('Room created; joining second browser.');
  assert.match(code, /^[A-Z2-9]{6}$/);
  await guest.goto(`${url}/?room=${code}`);
  await guest.locator('#online-name').fill('BRAVO');
  await guest.locator('#online-golfer').selectOption('7');
  assert.equal(await guest.locator('#online-code').inputValue(), code);
  await guest.locator('#online-join').click();
  await host.locator('#online-start').waitFor({ state: 'visible' });
  await host.waitForFunction(() => !document.getElementById('online-start').disabled);
  await host.locator('#online-start').click();
  console.log('Starting the shared round.');
  await settledPair('aim', 0);
  assert.equal((await state(host)).online_seat, 0);
  assert.equal((await state(guest)).online_seat, 1);
  pass('invite link joins a second independent browser and starts a shared round');

  await guest.locator('#canvas').focus();
  await guest.keyboard.down('Space');
  await guest.waitForTimeout(600);
  await guest.keyboard.up('Space');
  await guest.keyboard.press('Enter');
  assert.equal((await state(guest)).strokes, 0);
  assert.equal((await state(guest)).keyboard_charge, false);
  pass('watching player cannot swing or advance someone else’s turn');

  await host.locator('#canvas').focus();
  await host.keyboard.down('Space');
  await wait(host, () => window.__breakfastBallsState?.charge > 0.1);
  await host.locator('#canvas').evaluate(canvas => canvas.blur());
  await wait(host, () => !window.__breakfastBallsState?.keyboard_charge);
  await host.keyboard.up('Space');
  assert.equal((await state(host)).state, 'aim');
  assert.equal((await state(host)).strokes, 0);
  pass('focus loss cancels an unfinished online swing without pausing the room');

  for (let hole = 0; hole < 3; hole++) {
    await swing(0);
    await advance(0);
    await settledPair('aim', 1);
    if (hole === 0) {
      const before = await state(guest);
      await guest.reload();
      await wait(guest, () => window.__breakfastBallsState?.online_active && window.__breakfastBallsState?.state === 'aim');
      await settledPair('aim', 1);
      const after = await state(guest);
      assert.equal(after.online_seat, 1);
      assert.equal(after.online_revision, before.online_revision);
      assert.deepEqual(after.player_strokes, before.player_strokes);
      pass('refresh reconnects to the same seat and saved turn');

      await contexts[0].setOffline(true);
      await host.waitForFunction(() => /connect|offline|retry/i.test(document.getElementById('online-bar-status').textContent), null, { timeout: 20000 });
      await contexts[0].setOffline(false);
      await host.waitForFunction(() => !/reconnect|offline/i.test(document.getElementById('online-bar-status').textContent), null, { timeout: 30000 });
      pass('temporary network interruption reconnects without losing the round');
    }
    await swing(1);
    await advance(1);
    await settledPair('scorecard', 1);
    pass(`both golfers share the scorecard for pin ${hole + 1}`);
    await advance(1);
    await settledPair(hole === 2 ? 'finished' : 'aim', hole === 2 ? 1 : 0);
  }
  pass('both computers finish the full three-hole Pin Challenge');
  const final = await Promise.all(pages.map(state));
  assert.equal(final[0].player_scores[0].length, 3);
  assert.deepEqual(final[0].player_scores, final[1].player_scores);
  // Offline simulation intentionally creates failed network console messages.
  const unexpectedErrors = errors.filter(error => !/ERR_INTERNET_DISCONNECTED|Failed to fetch|net::ERR_NETWORK_CHANGED/.test(error));
  assert.deepEqual(unexpectedErrors, []);
  for (const [seat, page] of pages.entries()) {
    await page.screenshot({ path: fileURLToPath(new URL(`online-seat-${seat + 1}.png`, artifacts)) });
  }
  await writeFile(new URL('online-report.json', artifacts), JSON.stringify({ url, checks, final, errors }, null, 2));
  console.log(`ONLINE_JOURNEY: ${checks.length} checks passed.`);
} catch (error) {
  console.error('STATES', JSON.stringify(await Promise.all(pages.map(page => state(page).catch(() => null)))));
  console.error('ERRORS', errors);
  for (const [seat, page] of pages.entries()) {
    await page.screenshot({ path: fileURLToPath(new URL(`online-failure-${seat + 1}.png`, artifacts)) }).catch(() => {});
  }
  throw error;
} finally {
  await browser.close();
}
