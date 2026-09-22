import { MAX_BODY_BYTES, RoomError } from './rooms.mjs';

export function roomHTTP(serviceFactory, { trustProxy = false } = {}) {
  return async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const send = (status, payload) => { res.statusCode = status; res.end(JSON.stringify(payload)); };
    try {
      if (req.method !== 'POST') { res.setHeader('Allow', 'POST'); throw new RoomError(405, 'method_not_allowed', 'Use POST for room requests.'); }
      const origin = req.headers.origin;
      const host = req.headers.host;
      if (req.headers['sec-fetch-site'] === 'cross-site') throw new RoomError(403, 'wrong_origin', 'Open the game website to play online.');
      if (origin) {
        let parsed;
        try { parsed = new URL(origin); } catch { throw new RoomError(403, 'wrong_origin', 'Invalid request origin.'); }
        if (parsed.host !== host || !['http:', 'https:'].includes(parsed.protocol)) throw new RoomError(403, 'wrong_origin', 'Open the game website to play online.');
      }
      if (!/^application\/json(?:\s*;|$)/i.test(req.headers['content-type'] || '')) throw new RoomError(415, 'json_required', 'Send room requests as JSON.');
      if (Number(req.headers['content-length']) > MAX_BODY_BYTES) throw new RoomError(413, 'request_too_large', 'Room request is too large.');
      let body;
      if (req.body !== undefined) {
        if (typeof req.body === 'string' || Buffer.isBuffer(req.body)) {
          if (Buffer.byteLength(req.body) > MAX_BODY_BYTES) throw new RoomError(413, 'request_too_large', 'Room request is too large.');
          try { body = JSON.parse(req.body.toString()); } catch { throw new RoomError(400, 'invalid_json', 'Invalid JSON.'); }
        } else {
          body = req.body;
          if (Buffer.byteLength(JSON.stringify(body)) > MAX_BODY_BYTES) throw new RoomError(413, 'request_too_large', 'Room request is too large.');
        }
      } else {
        const chunks = [];
        let size = 0;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > MAX_BODY_BYTES) throw new RoomError(413, 'request_too_large', 'Room request is too large.');
          chunks.push(chunk);
        }
        try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new RoomError(400, 'invalid_json', 'Invalid JSON.'); }
      }
      // Vercel supplies/overwrites x-forwarded-for. Local development uses the
      // socket address and does not trust caller-supplied forwarding headers.
      const ip = trustProxy ? String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim()
        : req.socket?.remoteAddress || 'localhost';
      send(200, await serviceFactory().handle(body, ip));
    } catch (error) {
      if (error instanceof RoomError) {
        if (error.status === 429) res.setHeader('Retry-After', '60');
        send(error.status, { error: error.error, message: error.message, ...(error.room ? { room: error.room } : {}) });
      } else {
        // Do not log request bodies, player tokens, or provider credentials.
        send(500, { error: 'server_error', message: 'Online play encountered an error. Please retry.' });
      }
    }
  };
}
