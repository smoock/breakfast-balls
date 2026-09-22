import { ROOM_TTL_SECONDS, RoomError } from './rooms.mjs';

const CAS = `local raw = redis.call('GET', KEYS[1])
if not raw then return 0 end
local room = cjson.decode(raw)
if room.revision ~= tonumber(ARGV[1]) then return 0 end
redis.call('SET', KEYS[1], ARGV[2], 'EX', ARGV[3])
return 1`;
const RATE = `local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
return count`;

export class RedisRoomStore {
  constructor({ url, token, fetchImpl = fetch } = {}) {
    if (!url || !token) throw new RoomError(503, 'online_unavailable', 'Online play is not configured yet. Local play is available.');
    const endpoint = new URL(url);
    if (endpoint.protocol !== 'https:') throw new RoomError(503, 'online_unavailable', 'Online storage requires HTTPS.');
    this.url = endpoint.toString();
    this.token = token;
    this.fetch = fetchImpl;
  }
  async command(command) {
    try {
      const response = await this.fetch(this.url, { method: 'POST',
        headers: { Authorization: `Bearer ${this.token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(command), signal: AbortSignal.timeout(8000) });
      if (!response.ok) throw new Error('Storage request failed');
      const result = await response.json();
      if (result.error) throw new Error('Storage command failed');
      return result.result;
    } catch {
      throw new RoomError(503, 'storage_unavailable', 'Online storage is temporarily unavailable. Retry in a moment.');
    }
  }
  async get(code) {
    const raw = await this.command(['GET', `bb:room:${code}`]);
    return raw ? JSON.parse(raw) : null;
  }
  async create(room) {
    return await this.command(['SET', `bb:room:${room.code}`, JSON.stringify(room), 'EX', ROOM_TTL_SECONDS, 'NX']) === 'OK';
  }
  async compareAndSet(code, revision, room) {
    return await this.command(['EVAL', CAS, 1, `bb:room:${code}`, revision, JSON.stringify(room), ROOM_TTL_SECONDS]) === 1;
  }
  async rateLimit(key, limit, seconds) {
    return await this.command(['EVAL', RATE, 1, `bb:rate:${key}`, seconds]) <= limit;
  }
}

export function productionStore(env = process.env) {
  return new RedisRoomStore({ url: env.KV_REST_API_URL || env.UPSTASH_REDIS_REST_URL,
    token: env.KV_REST_API_TOKEN || env.UPSTASH_REDIS_REST_TOKEN });
}
