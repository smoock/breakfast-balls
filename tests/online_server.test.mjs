import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { RoomService, RoomError, RECOVER_AFTER_MS, ROOM_TTL_SECONDS, publicRoom } from '../server/rooms.mjs';
import { MemoryRoomStore } from '../server/memory-store.mjs';
import { productionStore, RedisRoomStore } from '../server/redis-store.mjs';
import { roomHTTP } from '../server/http.mjs';

const CONFIG = { mode: 0, holes: 3, nine: 0, tees: 0 };
function fixture() {
  let now = 1_800_000_000_000;
  const store = new MemoryRoomStore({ now: () => now });
  const service = new RoomService(store, { now: () => now });
  return { service, store, tick: ms => { now += ms; } };
}
function snapshot(room, overrides = {}) {
  return { schema_version: 1, state: 'aim', player_count: room.seats.length, player_index: 0,
    mode: room.config.mode, round_tees: room.config.tees, round_length: room.config.holes,
    round_holes: room.config.mode === 2 ? [5, 11, 15] : [0, 2, 4], round_position: 0, hole_index: room.config.mode === 2 ? 5 : 0,
    players: room.seats.map(s => ({ golfer: s.golfer, tag: s.name, pos: [0, 0, 0], strokes: 0, done: false,
      breakfast_used: false, skins: 0, scores: [], challenge_shot: {}, challenge_results: [] })),
    ball_pos: [0, 0, 0], velocity: [0, 0, 0], last_safe: [0, 0, 0], shot_origin: [0, 0, 0], wind: [0, 0],
    breakfast_offer: false, hole_done: false, nine_side: room.config.nine, skin_pot: 1, hole_message: '', club: 0,
    spin: 0, shot_style: 0, aim: 0, result_title: '', result_detail: '', last_shot: '', shot_range: 0,
    shot_distance: 0, shot_carry: 0, shot_roll: 0, shot_landed: false, shot_face: 0, shot_start_angle: 0,
    shot_quality: 1, shot_shape: 'STRAIGHT', in_air: false, bounced: false, shot_time: 0, swing_elapsed: 0,
    impact_pending: false, curve_rate: 0, flight_gravity: 9.81, ball_visible: true, tree_hits: [], ...overrides };
}
async function joined(f = fixture(), config = CONFIG) {
  const host = await f.service.handle({ op: 'create', name: 'Tommy!', golfer: 0, config });
  const guest = await f.service.handle({ op: 'join', code: host.code, name: 'Birdy', golfer: 1 });
  return { ...f, host, guest, room: guest.room };
}
let sequence = 0;
async function act(f, player, op, snap, extra = {}) {
  const result = await f.service.handle({ op, code: f.host.code, token: player.token, revision: f.room.revision,
    actionId: `test-action-${++sequence}`, ...(snap ? { snapshot: snap } : {}), ...extra });
  f.room = result.room;
  return result;
}
async function started() {
  const f = await joined();
  await act(f, f.host, 'start', snapshot(f.room));
  return f;
}
const rejects = (promise, status, error) => assert.rejects(promise, e => e instanceof RoomError && e.status === status && e.error === error);

test('create, join, and reconnect keep identity private and normalize input', async () => {
  const f = await joined();
  assert.match(f.host.code, /^[A-HJ-NP-Z2-9]{6}$/);
  assert.equal(f.host.token.length, 43);
  assert.equal(f.host.seat, 0);
  assert.equal(f.guest.seat, 1);
  assert.equal(f.room.seats[0].name, 'TOMMY');
  assert.equal(JSON.stringify(f.room).includes(f.host.token), false);
  assert.equal(JSON.stringify(f.room).includes('tokenHash'), false);
  const resumed = await f.service.handle({ op: 'join', code: f.host.code.toLowerCase(), token: f.guest.token });
  assert.equal(resumed.seat, 1);
  assert.equal(resumed.room.seats.length, 2);
  const other = await f.service.handle({ op: 'create', name: 'OTHER', golfer: 1, config: CONFIG });
  await rejects(f.service.handle({ op: 'poll', code: f.host.code, token: other.token }), 401, 'invalid_token');
  await rejects(f.service.handle({ op: 'poll', code: f.host.code, token: 'invalid' }), 401, 'invalid_token');
});

test('only host starts after two players; membership locks at start', async () => {
  const f = fixture();
  f.host = await f.service.handle({ op: 'create', name: 'HOST', golfer: 0, config: CONFIG });
  f.room = f.host.room;
  await rejects(act(f, f.host, 'start', snapshot(f.room)), 409, 'not_ready');
  f.guest = await f.service.handle({ op: 'join', code: f.host.code, name: 'GUEST', golfer: 1 });
  f.room = f.guest.room;
  await rejects(act(f, f.guest, 'start', snapshot(f.room)), 403, 'host_only');
  await act(f, f.host, 'start', snapshot(f.room));
  await rejects(f.service.handle({ op: 'join', code: f.host.code, name: 'LATE', golfer: 2 }), 409, 'already_started');
});

test('concurrent joins do not exceed four seats', async () => {
  const f = await joined();
  const results = await Promise.allSettled(Array.from({ length: 4 }, (_, i) => f.service.handle({ op: 'join',
    code: f.host.code, name: `EXTRA${i}`, golfer: i + 2 })));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 2);
  assert.equal((await f.store.get(f.host.code)).seats.length, 4);
});

test('turn ownership, stale revisions, and duplicate action retry', async () => {
  const f = await started();
  const shot = structuredClone(f.room.snapshot);
  shot.state = 'flight';
  shot.players[0].strokes = 1;
  await rejects(act(f, f.guest, 'shot', shot), 403, 'not_your_turn');
  const request = { op: 'shot', code: f.host.code, token: f.host.token,
    revision: f.room.revision, actionId: 'repeat-shot-123', snapshot: shot };
  const first = await f.service.handle(request);
  const second = await f.service.handle(request);
  assert.equal(second.room.revision, first.room.revision);
  assert.equal(second.room.snapshot.players[0].strokes, 1);
  await rejects(f.service.handle({ ...request, actionId: 'different-shot-123' }), 409, 'stale_revision');
  await rejects(f.service.handle({ ...request, snapshot: { ...shot, club: 4 } }), 409, 'action_reused');
  await rejects(f.service.handle({ ...request, actionId: 'x' }), 400, 'invalid_action');
});

test('concurrent distinct shots admit exactly one revision', async () => {
  const f = await started();
  const shot = { ...f.room.snapshot, state: 'flight' };
  const make = actionId => f.service.handle({ op: 'shot', code: f.host.code, token: f.host.token,
    revision: f.room.revision, actionId, snapshot: shot });
  const results = await Promise.allSettled([make('parallel-shot-one'), make('parallel-shot-two')]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.error, 'stale_revision');
});

test('settled results, breakfast ball, and turn advance form an authenticated journey', async () => {
  const f = await started();
  let snap = structuredClone(f.room.snapshot);
  snap.state = 'flight'; snap.players[0].strokes = 1;
  await act(f, f.host, 'shot', snap);
  snap.state = 'result'; snap.breakfast_offer = true;
  await act(f, f.host, 'settle', snap);
  snap.state = 'aim'; snap.breakfast_offer = false; snap.players[0].breakfast_used = true; snap.players[0].strokes = 0;
  await act(f, f.host, 'breakfast', snap);
  snap.state = 'flight'; snap.players[0].strokes = 1;
  await act(f, f.host, 'shot', snap);
  snap.state = 'result';
  await act(f, f.host, 'settle', snap);
  snap.state = 'aim'; snap.player_index = 1;
  await act(f, f.host, 'advance', snap);
  await rejects(act(f, f.host, 'shot', { ...snap, state: 'flight' }), 403, 'not_your_turn');
  await act(f, f.guest, 'shot', { ...snap, state: 'flight' });
  const resumed = await f.service.handle({ op: 'poll', code: f.host.code, token: f.guest.token });
  assert.equal(resumed.room.snapshot.player_index, 1);
  assert.equal(resumed.room.snapshot.state, 'flight');
});

test('recovery rolls interrupted flight back after sixty seconds without losing a stroke', async () => {
  const f = await started();
  const original = structuredClone(f.room.snapshot);
  const shot = structuredClone(original);
  shot.state = 'flight'; shot.players[0].strokes++;
  await act(f, f.host, 'shot', shot);
  await rejects(act(f, f.guest, 'recover'), 409, 'recovery_not_ready');
  f.tick(RECOVER_AFTER_MS);
  await act(f, f.guest, 'recover');
  assert.deepEqual(f.room.snapshot, original);
  assert.match(f.room.notice, /Interrupted shot/);
  assert.equal(f.room.shotStartedAt, undefined);
  await rejects(act(f, f.guest, 'settle', { ...shot, state: 'result' }), 403, 'not_your_turn');
});

test('snapshots cannot change membership, immutable configuration, or other golfers', async () => {
  const f = await started();
  for (const change of [s => { s.players[0].golfer = 3; }, s => { s.players[1].tag = 'FAKE'; },
    s => { s.round_tees = 1; }, s => { s.round_holes = [0, 0, 0]; }, s => { s.players[0].pos = [NaN, 0, 0]; },
    s => { s.players[1].strokes = 8; }, s => { s.player_index = 1; }, s => { delete s.ball_pos; },
    s => { s.wind = [0]; }, s => { s.hole_done = 'false'; }, s => { s.club = 99; }, s => { delete s.shot_quality; },
    s => { s.players[0].challenge_results = {}; }, s => { s.players[0].challenge_shot = []; }]) {
    const snap = structuredClone(f.room.snapshot); snap.state = 'flight'; change(snap);
    await assert.rejects(act(f, f.host, 'shot', snap), e => e.status === 400);
  }
  const malicious = JSON.parse('{"__proto__":{"polluted":true}}');
  await rejects(act(f, f.host, 'shot', { ...f.room.snapshot, state: 'flight', malicious }), 400, 'invalid_snapshot');
  assert.equal({}.polluted, undefined);
});

test('unchanged other-player JSON tolerates float serialization drift and object key order only', async () => {
  const f = await joined();
  const initial = snapshot(f.room);
  initial.players[1].pos = [0.123456789, 0, 0];
  initial.players[1].challenge_shot = { feet: 123.4, points: 0, valid: false, holed: false };
  await act(f, f.host, 'start', initial);
  const shot = structuredClone(f.room.snapshot);
  shot.state = 'flight';
  shot.players[1] = Object.fromEntries(Object.entries(shot.players[1]).reverse());
  shot.players[1].pos[0] += 1e-16;
  shot.players[1].challenge_shot.feet = 123.40000000000002;
  await act(f, f.host, 'shot', shot);
  const result = structuredClone(shot); result.state = 'result';
  result.players[1].pos[0] += 0.001;
  await rejects(act(f, f.host, 'settle', result), 400, 'invalid_transition');
  result.players[1].pos = shot.players[1].pos;
  result.players[1].strokes = 1;
  await rejects(act(f, f.host, 'settle', result), 400, 'invalid_transition');
});

test('scorecard and next-hole actions require complete hole and correct owner', async () => {
  const f = await started();
  // Inject an already completed result fixture to focus this check on next-hole transitions.
  const stored = await f.store.get(f.host.code);
  stored.snapshot.state = 'result'; stored.snapshot.player_index = 1;
  for (const p of stored.snapshot.players) { p.strokes = 3; p.done = true; }
  await f.store.compareAndSet(stored.code, stored.revision, stored);
  f.room = publicRoom(stored);
  const scorecard = structuredClone(f.room.snapshot);
  scorecard.state = 'scorecard'; scorecard.hole_done = true;
  for (const p of scorecard.players) p.scores.push(3);
  await act(f, f.guest, 'advance', scorecard);
  const next = structuredClone(scorecard);
  next.state = 'aim'; next.hole_done = false; next.round_position++; next.hole_index = next.round_holes[1]; next.player_index = 0;
  for (const p of next.players) { p.strokes = 0; p.done = false; }
  await rejects(act(f, f.host, 'next', next), 403, 'not_your_turn');
  await act(f, f.guest, 'next', next);
  assert.equal(f.room.snapshot.hole_index, 2);
});

test('pin challenge normalizes holes and tees to game rules', async () => {
  const f = await joined(fixture(), { mode: 2, holes: 18, nine: 1, tees: 1 });
  assert.deepEqual(f.room.config, { mode: 2, holes: 3, nine: 1, tees: 0 });
  await act(f, f.host, 'start', snapshot(f.room));
});

test('back-nine course order and final scorecard preserve the selected round', async () => {
  const f = await joined(fixture(), { mode: 0, holes: 9, nine: 1, tees: 1 });
  const holes = Array.from({ length: 9 }, (_, i) => i + 9);
  const initial = snapshot(f.room, { round_holes: holes, hole_index: 9 });
  await rejects(act(f, f.host, 'start', { ...initial, round_holes: Array.from({ length: 9 }, (_, i) => i), hole_index: 0 }), 400, 'invalid_snapshot');
  await act(f, f.host, 'start', initial);
  const stored = await f.store.get(f.host.code);
  stored.snapshot.state = 'scorecard'; stored.snapshot.hole_done = true;
  stored.snapshot.round_position = 8; stored.snapshot.hole_index = 17; stored.snapshot.player_index = 1;
  for (const p of stored.snapshot.players) { p.done = true; p.scores = Array(9).fill(4); }
  await f.store.compareAndSet(stored.code, stored.revision, stored);
  f.room = publicRoom(stored);
  await act(f, f.guest, 'next', { ...f.room.snapshot, state: 'finished' });
  assert.equal(f.room.status, 'finished');
  const resumed = await f.service.handle({ op: 'poll', code: f.host.code, token: f.host.token });
  assert.equal(resumed.room.snapshot.players[0].scores.length, 9);
  await rejects(act(f, f.guest, 'shot', { ...f.room.snapshot, state: 'flight' }), 409, 'not_playing');
});

test('room expiry and atomic request rate limits', async () => {
  const f = await joined();
  f.tick(ROOM_TTL_SECONDS * 1000 + 1);
  await rejects(f.service.handle({ op: 'poll', code: f.host.code, token: f.host.token }), 404, 'room_not_found');
  const throttled = fixture();
  const results = await Promise.allSettled(Array.from({ length: 14 }, () => throttled.service.handle({ op: 'create', name: 'HOST', golfer: 0, config: CONFIG }, 'one-ip')));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 12);
  assert.equal(results.filter(r => r.status === 'rejected' && r.reason.error === 'rate_limited').length, 2);
});

test('production requires Redis, and REST store uses atomic CAS without leaking provider details', async () => {
  assert.throws(() => productionStore({}), e => e.status === 503 && e.error === 'online_unavailable');
  const commands = [];
  const store = new RedisRoomStore({ url: 'https://test.upstash.io', token: 'secret', fetchImpl: async (_url, options) => {
    commands.push(JSON.parse(options.body)); return { ok: true, json: async () => ({ result: 1 }) };
  } });
  assert.equal(await store.compareAndSet('ABC234', 9, { revision: 10 }), true);
  assert.equal(commands[0][0], 'EVAL');
  assert.match(commands[0][1], /room.revision ~= tonumber/);
  assert.deepEqual(commands[0].slice(2), [1, 'bb:room:ABC234', 9, '{"revision":10}', ROOM_TTL_SECONDS]);
  const failed = new RedisRoomStore({ url: 'https://test.upstash.io', token: 'secret', fetchImpl: async () => { throw Error('SECRET_PROVIDER_DETAIL'); } });
  await rejects(failed.get('ABC234'), 503, 'storage_unavailable');
});

test('HTTP rejects cross-origin requests, non-JSON, oversized body, and unsupported methods', async t => {
  const f = fixture();
  const server = createServer(roomHTTP(() => f.service));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const body = JSON.stringify({ op: 'create', name: 'HOST', golfer: 0, config: CONFIG });
  let response = await fetch(base, { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: 'https://evil.example' }, body });
  assert.equal(response.status, 403);
  response = await fetch(base, { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body });
  assert.equal(response.status, 415);
  response = await fetch(base, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: 'x'.repeat(100_000) });
  assert.equal(response.status, 413);
  response = await fetch(base, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{broken' });
  assert.equal(response.status, 400);
  response = await fetch(base);
  assert.equal(response.status, 405);
  response = await fetch(base, { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: base }, body });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const result = await response.json();
  assert.equal(result.room.seats.length, 1);
});

test('live Redis REST executes Lua CAS and simultaneous shot authorization', { skip: process.env.RUN_REDIS_TESTS !== '1' }, async t => {
  const store = productionStore();
  const service = new RoomService(store);
  const ip = `integration-test-${process.pid}-${Date.now()}`;
  const host = await service.handle({ op: 'create', name: 'HOST', golfer: 0, config: CONFIG }, ip);
  t.after(async () => { await store.command(['DEL', `bb:room:${host.code}`]); });
  const guest = await service.handle({ op: 'join', code: host.code, name: 'GUEST', golfer: 1 }, ip);
  const start = await service.handle({ op: 'start', code: host.code, token: host.token, revision: guest.room.revision,
    actionId: 'redis-live-start', snapshot: snapshot(guest.room) }, ip);
  const shot = structuredClone(start.room.snapshot);
  shot.state = 'flight'; shot.players[0].strokes = 1;
  const send = actionId => service.handle({ op: 'shot', code: host.code, token: host.token,
    revision: start.room.revision, actionId, snapshot: shot }, ip);
  const race = await Promise.allSettled([send('redis-live-shot-a'), send('redis-live-shot-b')]);
  assert.equal(race.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(race.find(result => result.status === 'rejected').reason.error, 'stale_revision');
  const persisted = await service.handle({ op: 'poll', code: host.code, token: guest.token }, ip);
  assert.equal(persisted.room.revision, start.room.revision + 1);
  assert.equal(persisted.room.snapshot.state, 'flight');
  assert.equal(persisted.room.snapshot.players[0].strokes, 1);
  assert.equal(JSON.stringify(persisted).includes(host.token), false);
});
