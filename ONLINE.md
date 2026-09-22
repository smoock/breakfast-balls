# Private online rounds

The browser edition supports two to four golfers on separate computers. Choose **Play online**, enter a five-letter name, create a room, and share its link or six-character code. Once everyone has joined, the host starts the round. The golfer whose turn it is controls the shot and continues from the result; everyone else watches. Stroke Play, Skins, and the three-hole Pin Challenge use the existing Godot rules.

Rooms are private by invitation, without player accounts or public matchmaking. A seat token is kept in that tab's session storage. Refreshing the same tab reconnects to that seat. Leaving pauses automatic reconnect; the online dialog offers **Resume room**. Clearing that storage loses the reconnect token, and opening the invite in a different browser does not recover an occupied seat. Keep the original tabs open for the round. A started room does not accept replacement players.

Saved rooms expire 24 hours after their last accepted change. If a shot is interrupted before its result can be saved, a golfer can recover the previous lie after 60 seconds and retry it. There is no permanent online career, leaderboard, or cross-device account recovery. Online play does not write local club records. Local play and practice remain available without the room service.

## Implementation

The game remains Godot 4.7.2 with its existing course, character assets, and swing physics. The page adds a small JavaScript room client. A Node.js Vercel Function handles `/api/room`; Upstash Redis stores room membership and checkpoints.

The server authenticates a seat with an unpredictable token, enforces current-player ownership, checks phase transitions and snapshot bounds, and advances room revisions atomically. Action IDs make network retries idempotent. Redis compare-and-swap prevents two server instances from accepting conflicting updates. Credentials are server-only; they never enter the game pack, static files, invite links, or repository.

The active golfer runs the physics locally. After the server accepts the start of the shot, the other browsers animate the transmitted flight state. The golfer submits the settled result, and all browsers reconcile to that exact checkpoint. This is suitable for friendly private games: turn ownership is enforced, but the server does not independently simulate physics or provide competitive anti-cheat.

The page polls for revisions, backs off after network failures, and locks gameplay while an action is uncertain. Online focus loss cancels an unfinished swing without pausing everyone else's game. Offline play retains its existing pause behavior. Replays are disabled online so the shared ball position always represents the live shot or saved result.

HTTP synchronization fits golf's turn-based interactions and avoids a persistent connection lifecycle. [Vercel's WebSocket support](https://vercel.com/docs/functions/websockets) is available, but connections still end at function duration limits and reconnects can land on another instance. Redis would remain necessary. [Upstash's REST API](https://upstash.com/docs/redis/features/restapi) supports the atomic Lua operations used for room updates.

## Run locally

```sh
python3 tools/build_web.py
npm ci
npm run serve:online
```

Open two separate browser profiles at `http://127.0.0.1:8061`. The local development server serves the exported files and room API using an in-memory store, bound to loopback. Restarting it clears local rooms. Production never falls back to memory storage.

```sh
npm run test:online
npm run test:online:browser
godot --headless --path . --script res://tests/online_game_tests.gd
```

The browser test uses two isolated Chrome contexts, visible room controls, real swings, spectator input checks, refresh recovery, a network interruption, and a complete three-hole Pin Challenge. It compares shared scores and positions. Use `WEB_URL` to run it against a deployed site. The September 21 local and public Vercel runs both passed all 21 browser checks, including a full round through production Redis. Backend tests passed 15 cases, Godot online tests passed 51 checks, and native golf rules passed 237 checks. This verifies separate browser sessions through the server; real players on different networks should still playtest timing and feel.

## Production setup

The existing Vercel project is `breakfast-balls` in `smoocks-projects`. Provision Upstash Redis through the Vercel marketplace on its **free** plan, with automatic paid upgrades disabled. The first installation requires the account owner to accept the marketplace terms. From the linked `builds/vercel` directory, a current Vercel CLI supports:

```sh
vercel integration add upstash/upstash-kv \
  --name breakfast-balls-online --plan free \
  -m primaryRegion=sfo1 -m autoUpgrade=false -m prodPack=false \
  --environment production --environment preview \
  --no-env-pull --scope smoocks-projects
```

The API accepts `KV_REST_API_URL` / `KV_REST_API_TOKEN`, or `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN`, from Vercel's server environment. Use a read/write token. Do not publish `.env` files or download credentials into browser assets. Missing storage configuration returns a clear service-unavailable response; local play remains usable.

Build and test, then publish with `python3 tools/deploy_web.py`. The wrapper stages static assets under `public/` and the API separately. Generated ZIPs and static-only hosting do not contain a working online backend. See [WEB.md](WEB.md) for the pinned CLI and existing deployment workflow.

The free database has finite quotas; polling consumes requests even while waiting in a room. Completed rounds stop polling automatically; close unused lobbies and unfinished rounds to reduce idle traffic. Monitor usage in the Vercel/Upstash dashboards before expanding beyond a small group. Paid upgrades are an explicit future decision. Current limits and plans are described in [Upstash pricing](https://upstash.com/pricing/redis).

Production multiplayer was verified at [breakfast-balls.vercel.app](https://breakfast-balls.vercel.app) on September 21, 2026. The public build matched the local manifest, completed a local practice shot with zero browser errors, and kept API responses uncached. Server modules and environment files returned 404 from public paths. Upstash resource `breakfast-balls-online` uses the free plan with automatic paid upgrades disabled.
