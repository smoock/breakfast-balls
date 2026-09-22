import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

export const ROOM_TTL_SECONDS = 24 * 60 * 60;
export const RECOVER_AFTER_MS = 60_000;
export const MAX_BODY_BYTES = 96 * 1024;
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const GAME_OPS = new Set(['start', 'shot', 'settle', 'advance', 'breakfast', 'next', 'recover']);
const STATES = new Set(['aim', 'flight', 'result', 'scorecard', 'finished']);

export class RoomError extends Error {
  constructor(status, error, message, room) {
    super(message);
    this.status = status;
    this.error = error;
    if (room) this.room = room;
  }
}
const fail = (status, code, message, room) => { throw new RoomError(status, code, message, room); };
const integer = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const hash = value => createHash('sha256').update(value).digest('hex');
const clone = value => structuredClone(value);
// Godot's double -> JSON -> double round trip can differ in the final bit.
// Compare integer rules exactly, tolerate only tiny float serialization drift,
// and ignore object insertion order. Action fingerprints remain exact below.
function same(a, b) {
  if (a === b) return true;
  if (typeof a !== typeof b || a === null || b === null) return false;
  if (typeof a === 'number') {
    if (Number.isInteger(a) || Number.isInteger(b)) return false;
    return Number.isFinite(a) && Number.isFinite(b)
      && Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length
      && a.every((item, index) => same(item, b[index]));
  }
  if (object(a) && object(b)) {
    const keys = Object.keys(a);
    return keys.length === Object.keys(b).length && keys.every(key => Object.hasOwn(b, key) && same(a[key], b[key]));
  }
  return false;
}

export function publicRoom(room) {
  const result = {
    code: room.code, revision: room.revision, status: room.status,
    seats: room.seats.map(({ name, golfer }) => ({ name, golfer })),
    config: clone(room.config), snapshot: clone(room.snapshot), updatedAt: room.updatedAt,
  };
  if (room.shotStartedAt !== null) result.shotStartedAt = room.shotStartedAt;
  if (room.notice) result.notice = room.notice;
  return result;
}

export function normalizeIdentity(name, golfer) {
  if (typeof name !== 'string' || name.length > 100 || !integer(golfer, 0, 7)) {
    fail(400, 'invalid_player', 'Choose a name and a golfer.');
  }
  name = name.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5);
  if (!name) fail(400, 'invalid_player', 'Use 1–5 letters for your name.');
  return { name, golfer };
}

export function normalizeConfig(config) {
  if (!object(config) || !integer(config.mode, 0, 2) || ![3, 9, 18].includes(config.holes)
      || !integer(config.nine, 0, 1) || !integer(config.tees, 0, 1)) {
    fail(400, 'invalid_config', 'Choose valid round settings.');
  }
  return { mode: config.mode, holes: config.mode === 2 ? 3 : config.holes,
    nine: config.nine, tees: config.mode === 2 ? 0 : config.tees };
}

function validateJSON(value, depth = 0, budget = { count: 0 }) {
  if (++budget.count > 8000 || depth > 12) fail(400, 'invalid_snapshot', 'The game state is too complex.');
  if (value === null || typeof value === 'boolean') return;
  if (typeof value === 'number') {
    if (!Number.isFinite(value) || Math.abs(value) > 1e7) fail(400, 'invalid_snapshot', 'Invalid game coordinates.');
    return;
  }
  if (typeof value === 'string') {
    if (value.length > 512) fail(400, 'invalid_snapshot', 'Game text is too long.');
    return;
  }
  if (!object(value) && !Array.isArray(value)) fail(400, 'invalid_snapshot', 'Invalid game state.');
  if (Array.isArray(value) && value.length > 2000) fail(400, 'invalid_snapshot', 'Game list is too large.');
  for (const [key, item] of Object.entries(value)) {
    if (['__proto__', 'constructor', 'prototype'].includes(key) || key.length > 64) {
      fail(400, 'invalid_snapshot', 'Invalid game state field.');
    }
    validateJSON(item, depth + 1, budget);
  }
}

function vector(value, dimensions = 3) {
  return Array.isArray(value) && value.length === dimensions
    && value.every(v => typeof v === 'number' && Number.isFinite(v) && Math.abs(v) <= 100_000);
}

function challengeResult(value) {
  return object(value) && (Object.keys(value).length === 0
    || (typeof value.feet === 'number' && value.feet >= 0 && value.feet <= 100_000
      && integer(value.points, 0, 100) && typeof value.valid === 'boolean' && typeof value.holed === 'boolean'));
}

export function validateSnapshot(snapshot, room) {
  if (!object(snapshot)) fail(400, 'invalid_snapshot', 'A complete game snapshot is required.');
  validateJSON(snapshot);
  if (Buffer.byteLength(JSON.stringify(snapshot)) > 64 * 1024) fail(413, 'snapshot_too_large', 'Game snapshot is too large.');
  const count = room.seats.length;
  if (snapshot.schema_version !== 1 || !STATES.has(snapshot.state)
      || snapshot.player_count !== count || !integer(snapshot.player_index, 0, count - 1)
      || snapshot.mode !== room.config.mode || snapshot.round_tees !== room.config.tees
      || snapshot.nine_side !== room.config.nine
      || snapshot.round_length !== room.config.holes
      || !Array.isArray(snapshot.players) || snapshot.players.length !== count
      || !Array.isArray(snapshot.round_holes) || snapshot.round_holes.length !== room.config.holes
      || new Set(snapshot.round_holes).size !== room.config.holes
      || !snapshot.round_holes.every(h => integer(h, 0, 17))
      || !integer(snapshot.round_position, 0, room.config.holes - 1)
      || snapshot.hole_index !== snapshot.round_holes[snapshot.round_position]) {
    fail(400, 'invalid_snapshot', 'The game snapshot does not match this room.');
  }
  const expectedHoles = room.config.mode === 2 ? [5, 11, 15]
    : room.config.holes === 9 ? Array.from({ length: 9 }, (_, i) => i + room.config.nine * 9)
      : room.config.holes === 18 ? Array.from({ length: 18 }, (_, i) => i) : null;
  if (expectedHoles && !same(snapshot.round_holes, expectedHoles)) {
    fail(400, 'invalid_snapshot', 'The course order does not match this room.');
  }
  for (const field of ['hole_done', 'breakfast_offer', 'shot_landed', 'in_air', 'bounced', 'impact_pending', 'ball_visible']) {
    if (typeof snapshot[field] !== 'boolean') fail(400, 'invalid_snapshot', `Invalid ${field} flag.`);
  }
  for (const field of ['hole_message', 'result_title', 'result_detail', 'last_shot', 'shot_shape']) {
    if (typeof snapshot[field] !== 'string') fail(400, 'invalid_snapshot', `Invalid ${field} text.`);
  }
  for (const field of ['aim', 'shot_range', 'shot_distance', 'shot_carry', 'shot_roll', 'shot_face', 'shot_start_angle',
    'shot_quality', 'shot_time', 'swing_elapsed', 'curve_rate', 'flight_gravity']) {
    if (typeof snapshot[field] !== 'number' || !Number.isFinite(snapshot[field])) fail(400, 'invalid_snapshot', `Invalid ${field} value.`);
  }
  if (!integer(snapshot.club, 0, 13) || !integer(snapshot.spin, -1, 1) || !integer(snapshot.shot_style, 0, 2)
      || !integer(snapshot.skin_pot, 0, 1000) || snapshot.shot_quality < 0 || snapshot.shot_quality > 1
      || !vector(snapshot.wind, 2) || !Array.isArray(snapshot.tree_hits) || snapshot.tree_hits.length > 256
      || !snapshot.tree_hits.every(index => integer(index, 0, 100_000))) {
    fail(400, 'invalid_snapshot', 'Invalid shot settings.');
  }
  for (let i = 0; i < count; i++) {
    const player = snapshot.players[i];
    if (!object(player) || player.golfer !== room.seats[i].golfer || player.tag !== room.seats[i].name
        || !vector(player.pos) || !integer(player.strokes, 0, 1000)
        || typeof player.done !== 'boolean' || typeof player.breakfast_used !== 'boolean'
        || !integer(player.skins, 0, 1000) || !Array.isArray(player.scores)
        || player.scores.length > room.config.holes || !player.scores.every(s => integer(s, 0, 1000))
        || !Array.isArray(player.challenge_results) || player.challenge_results.length > 3
        || !player.challenge_results.every(challengeResult) || !challengeResult(player.challenge_shot)) {
      fail(400, 'invalid_snapshot', 'Invalid player state or room membership.');
    }
  }
  for (const field of ['ball_pos', 'velocity', 'last_safe', 'shot_origin']) {
    if (!vector(snapshot[field])) fail(400, 'invalid_snapshot', 'Invalid ball position.');
  }
  return clone(snapshot);
}

function authenticate(room, token) {
  if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) {
    fail(401, 'invalid_token', 'Rejoin this room from the browser where you joined.');
  }
  const candidate = Buffer.from(hash(token), 'hex');
  const seat = room.seats.findIndex(player => timingSafeEqual(candidate, Buffer.from(player.tokenHash, 'hex')));
  if (seat < 0) fail(401, 'invalid_token', 'This player token does not belong to the room.');
  return seat;
}

function mutation(room, request, seat, now) {
  if (!Number.isSafeInteger(request.revision) || request.revision < 0
      || typeof request.actionId !== 'string' || !/^[A-Za-z0-9_-]{8,96}$/.test(request.actionId)) {
    fail(400, 'invalid_action', 'A revision and unique action ID are required.');
  }
  const fingerprint = hash(JSON.stringify({ op: request.op, snapshot: request.snapshot ?? null }));
  const prior = room.actions.find(a => a.seat === seat && a.id === request.actionId);
  if (prior) {
    if (prior.fingerprint !== fingerprint) fail(409, 'action_reused', 'Use a new action ID for a different action.', publicRoom(room));
    return null;
  }
  if (request.revision !== room.revision) fail(409, 'stale_revision', 'The round changed. The latest state has been loaded.', publicRoom(room));
  const next = clone(room);
  const current = room.snapshot;
  if (request.op === 'start') {
    if (seat !== 0) fail(403, 'host_only', 'Only the room host can start the round.');
    if (room.status !== 'lobby' || room.seats.length < 2) fail(409, 'not_ready', 'Wait for at least two players before starting.', publicRoom(room));
    next.snapshot = validateSnapshot(request.snapshot, room);
    if (next.snapshot.state !== 'aim' || next.snapshot.player_index !== 0 || next.snapshot.round_position !== 0
        || next.snapshot.players.some(p => p.strokes !== 0 || p.done || p.scores.length !== 0 || p.breakfast_used)) {
      fail(400, 'invalid_transition', 'A round must start at the first tee.');
    }
    next.status = 'playing';
  } else if (request.op === 'recover') {
    if (room.status !== 'playing' || current?.state !== 'flight' || !room.beforeShot
        || now - room.shotStartedAt < RECOVER_AFTER_MS) {
      fail(409, 'recovery_not_ready', 'An interrupted shot can be restored after 60 seconds.', publicRoom(room));
    }
    next.snapshot = clone(room.beforeShot);
    next.beforeShot = null;
    next.shotStartedAt = null;
    next.notice = 'Interrupted shot restored. The same golfer can try again.';
  } else {
    if (room.status !== 'playing') fail(409, 'not_playing', 'This room is not playing a round.', publicRoom(room));
    if (seat !== current.player_index) fail(403, 'not_your_turn', 'It is another golfer’s turn.');
    const allowed = { shot: ['aim', ['flight']], settle: ['flight', ['result']],
      advance: ['result', ['aim', 'scorecard']], breakfast: ['result', ['aim']], next: ['scorecard', ['aim', 'finished']] }[request.op];
    if (!allowed || current.state !== allowed[0]) fail(409, 'invalid_phase', 'That action is not available now.', publicRoom(room));
    const snapshot = validateSnapshot(request.snapshot, room);
    if (!allowed[1].includes(snapshot.state) || !same(snapshot.round_holes, current.round_holes)) {
      fail(400, 'invalid_transition', 'Invalid round transition.');
    }
    if (request.op !== 'next' && (snapshot.round_position !== current.round_position || snapshot.hole_index !== current.hole_index)) {
      fail(400, 'invalid_transition', 'Only the next-hole action can change holes.');
    }
    if (['shot', 'settle', 'breakfast'].includes(request.op) && snapshot.player_index !== current.player_index) {
      fail(400, 'invalid_transition', 'That action cannot change the active golfer.');
    }
    if (request.op === 'shot') {
      next.beforeShot = clone(current);
      next.shotStartedAt = now;
    }
    if (request.op === 'settle') next.shotStartedAt = null;
    if (request.op === 'breakfast' && (room.config.mode === 2 || !current.breakfast_offer
        || current.players[seat].breakfast_used || !snapshot.players[seat].breakfast_used)) {
      fail(400, 'invalid_transition', 'No breakfast ball is available.');
    }
    if (request.op === 'advance' && snapshot.state === 'scorecard' && !current.players.every(p => p.done)) {
      fail(400, 'invalid_transition', 'Every golfer must finish before the scorecard.');
    }
    if (request.op === 'advance' && snapshot.state === 'aim' && snapshot.players[snapshot.player_index].done) {
      fail(400, 'invalid_transition', 'A golfer who finished cannot take the next turn.');
    }
    if (request.op === 'next') {
      const final = current.round_position === room.config.holes - 1;
      if (!current.hole_done || (final ? snapshot.state !== 'finished' || snapshot.round_position !== current.round_position
        : snapshot.state !== 'aim' || snapshot.round_position !== current.round_position + 1 || snapshot.player_index !== 0)) {
        fail(400, 'invalid_transition', 'Invalid next-hole transition.');
      }
      if (final) next.status = 'finished';
    }
    // Physics remain client-authoritative for private games. These checks protect
    // turn ownership and membership; they do not claim competitive anti-cheat.
    if (['shot', 'settle', 'breakfast'].includes(request.op)) {
      for (let i = 0; i < room.seats.length; i++) {
        if (i !== seat && !same(snapshot.players[i], current.players[i])) fail(400, 'invalid_transition', 'A shot cannot change another golfer.');
      }
    }
    next.snapshot = snapshot;
    if (['advance', 'breakfast', 'next'].includes(request.op)) next.beforeShot = null;
    next.notice = '';
  }
  next.revision++;
  next.updatedAt = now;
  next.actions.push({ seat, id: request.actionId, fingerprint });
  next.actions = next.actions.slice(-128);
  return next;
}

export class RoomService {
  constructor(store, { now = Date.now, bytes = randomBytes } = {}) {
    this.store = store;
    this.now = now;
    this.bytes = bytes;
  }
  async handle(request, ip = 'unknown') {
    if (!object(request) || !['create', 'join', 'poll', ...GAME_OPS].includes(request.op)) fail(400, 'invalid_operation', 'Unknown room action.');
    const group = request.op === 'create' ? 'create' : request.op === 'join' ? 'join' : request.op === 'poll' ? 'poll' : 'play';
    const [limit, seconds] = { create: [12, 3600], join: [60, 600], poll: [300, 60], play: [180, 60] }[group];
    if (!await this.store.rateLimit(`${group}:${hash(ip).slice(0, 24)}`, limit, seconds)) {
      fail(429, 'rate_limited', 'Too many requests. Please wait a moment and retry.');
    }
    const now = this.now();
    if (request.op === 'create') {
      const identity = normalizeIdentity(request.name, request.golfer);
      const config = normalizeConfig(request.config);
      const token = this.bytes(32).toString('base64url');
      for (let attempt = 0; attempt < 8; attempt++) {
        const code = [...this.bytes(6)].map(byte => CODE_ALPHABET[byte % CODE_ALPHABET.length]).join('');
        const room = { code, revision: 0, status: 'lobby', seats: [{ ...identity, tokenHash: hash(token) }],
          config, snapshot: null, updatedAt: now, shotStartedAt: null, beforeShot: null, actions: [], notice: '' };
        if (await this.store.create(room)) return { code, token, seat: 0, room: publicRoom(room) };
      }
      fail(503, 'room_unavailable', 'Could not create a room. Try again.');
    }
    const code = typeof request.code === 'string' ? request.code.trim().toUpperCase() : '';
    if (!/^[A-HJ-NP-Z2-9]{6}$/.test(code)) fail(400, 'invalid_code', 'Enter the six-character room code.');
    for (let attempt = 0; attempt < 5; attempt++) {
      const room = await this.store.get(code);
      if (!room) fail(404, 'room_not_found', 'This room expired or does not exist. Create a new room.');
      if (request.op === 'join' && !request.token) {
        if (room.status !== 'lobby') fail(409, 'already_started', 'This round already started. Reconnect with your saved player token.');
        if (room.seats.length >= 4) fail(409, 'room_full', 'This room already has four golfers.');
        const identity = normalizeIdentity(request.name, request.golfer);
        const token = this.bytes(32).toString('base64url');
        const next = clone(room);
        next.seats.push({ ...identity, tokenHash: hash(token) });
        next.revision++;
        next.updatedAt = now;
        if (await this.store.compareAndSet(code, room.revision, next)) {
          return { code, token, seat: next.seats.length - 1, room: publicRoom(next) };
        }
        continue;
      }
      const seat = authenticate(room, request.token);
      if (request.op === 'poll' || request.op === 'join') return { room: publicRoom(room), seat };
      const next = mutation(room, request, seat, now);
      if (!next) return { room: publicRoom(room), seat };
      if (await this.store.compareAndSet(code, room.revision, next)) return { room: publicRoom(next), seat };
    }
    fail(409, 'room_busy', 'The room is busy. Reload its state and retry.');
  }
}
