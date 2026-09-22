#!/usr/bin/env node
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { RoomService } from '../server/rooms.mjs';
import { MemoryRoomStore } from '../server/memory-store.mjs';
import { roomHTTP } from '../server/http.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
let port = 8061;
let directory = path.join(root, 'builds/web');
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--port') port = Number(args[++i]);
  else if (args[i] === '--directory') directory = path.resolve(args[++i]);
  else throw new Error(`Unknown argument: ${args[i]}. Use --port or --directory.`);
}
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid port.');
await stat(path.join(directory, 'index.html'));
const service = new RoomService(new MemoryRoomStore());
const online = roomHTTP(() => service);
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.txt': 'text/plain; charset=utf-8' };
const server = createServer(async (req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname === '/api/room') return online(req, res);
  try {
    if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405); res.end(); return; }
    const decoded = decodeURIComponent(pathname);
    if (decoded.split('/').some(part => part.startsWith('.'))) { res.writeHead(404); res.end(); return; }
    const target = path.resolve(directory, `.${decoded === '/' ? '/index.html' : decoded}`);
    if (!target.startsWith(`${directory}${path.sep}`)) { res.writeHead(404); res.end(); return; }
    const data = await readFile(target);
    res.writeHead(200, { 'Content-Type': types[path.extname(target)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(req.method === 'HEAD' ? undefined : data);
  } catch { res.writeHead(404); res.end('Not found'); }
});
server.listen(port, '127.0.0.1', () => {
  console.log(`Breakfast Balls online development: http://127.0.0.1:${port}`);
  console.log('Local memory storage: rooms disappear when this development server stops.');
});
