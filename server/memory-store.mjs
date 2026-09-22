import { ROOM_TTL_SECONDS } from './rooms.mjs';

// Used only by the explicitly launched localhost development server and tests.
// Production never imports this module or silently falls back to process memory.
export class MemoryRoomStore {
  constructor({ now = Date.now } = {}) { this.rooms = new Map(); this.limits = new Map(); this.now = now; }
  async get(code) {
    const entry = this.rooms.get(code);
    if (!entry || entry.expires <= this.now()) { this.rooms.delete(code); return null; }
    return structuredClone(entry.room);
  }
  async create(room) {
    const old = this.rooms.get(room.code);
    if (old && old.expires > this.now()) return false;
    this.rooms.set(room.code, { room: structuredClone(room), expires: this.now() + ROOM_TTL_SECONDS * 1000 });
    return true;
  }
  async compareAndSet(code, revision, room) {
    const old = this.rooms.get(code);
    if (!old || old.expires <= this.now() || old.room.revision !== revision) return false;
    this.rooms.set(code, { room: structuredClone(room), expires: this.now() + ROOM_TTL_SECONDS * 1000 });
    return true;
  }
  async rateLimit(key, limit, seconds) {
    let entry = this.limits.get(key);
    if (!entry || entry.expires <= this.now()) {
      entry = { count: 0, expires: this.now() + seconds * 1000 };
      this.limits.set(key, entry);
    }
    return ++entry.count <= limit;
  }
}
