# Breakfast Balls in the browser

The web edition runs the existing golf game in a browser: Magnolia Pines, the same swing and ball physics, practice, Stroke Play, Skins, Pin Challenge, 1–4 players sharing one device, and private online rooms for 2–4 players. Players open a link and press Play; they do not install Godot or download a desktop application.

**Play now: [breakfast-balls.vercel.app](https://breakfast-balls.vercel.app).** The public HTTPS build was verified against the local manifest on September 21, 2026. It completed an actual practice shot with zero browser errors and a full online round in two independent browser sessions, including refresh and network recovery.

## Stack and decision

| Layer | Choice | Reason |
| --- | --- | --- |
| Game | Godot 4.7.2, GDScript | Reuses the existing course, physics, menus, and gameplay tests. |
| Art | Blender sources and exported GLB models | Keeps the current editable asset pipeline. |
| Browser runtime | Single-threaded WebAssembly, WebGL 2 Compatibility renderer | Matches the renderer already used by the native game. |
| Web page | Small HTML/CSS/JavaScript shell | Provides loading, controls, fullscreen, and startup errors without a separate application framework. |
| Hosting / room API | Vercel static files and Node.js Functions | Keeps the existing game URL and coordinates authenticated room actions. |
| Room storage | Upstash Redis over HTTPS | Atomic revisions, saved round checkpoints, and reconnects across server instances. |

Godot's [web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) identifies single-threaded export as the default and preferred option. It avoids the cross-origin isolation headers needed for threaded builds. Web exports require WebAssembly and WebGL 2; they use the Compatibility renderer. Use the matching editor and export templates from the [official Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).

Three.js with TypeScript and Vite would be a good foundation for a new browser game; its [official installation guide](https://threejs.org/manual/pages/installation.html) supports that workflow. For this project it would require reimplementing the existing game and revalidating its feel. Keeping Godot gives both editions one gameplay implementation.

## Build and preview

Prerequisites: Python 3, Godot 4.7.2, and matching standard export templates. Install templates through Godot's **Editor → Manage Export Templates**. Blender and Node.js are not required to build the browser edition from the retained GLB assets.

Run from the repository root:

```sh
python3 tools/build_web.py
python3 tools/serve_web.py --port 8060
```

Open [the local preview](http://127.0.0.1:8060/). The preview server serves only the generated website, with the WebAssembly MIME type set correctly. Stop it with Ctrl+C. It is a development server, not a production host.

If Godot is installed elsewhere, select its executable explicitly:

```sh
python3 tools/build_web.py --godot "/Applications/Godot.app/Contents/MacOS/Godot"
```

The `GODOT` environment variable is also supported. `--output` selects a different dedicated output directory.

The default outputs are:

- `builds/web/index.html` and its adjacent runtime, game pack, and image files: upload the whole directory together.
- `builds/web/build-info.json`: engine version, byte sizes, estimated gzip sizes, and SHA-256 hashes for generated files. The gzip figures are estimates, not measured network transfers.
- `builds/breakfast-balls-web.zip`: a portable archive of the static website, with `index.html` at its root.

The finished browser bundle is approximately 43.9 MiB uncompressed, or 15.4 MiB using the build script's gzip estimate. The builder imports a temporary clean staging project. Only staged portrait imports receive a 512-pixel size limit; retained portrait images and native export settings keep their original quality. Blender source files, development tools, tests, backups, and review screenshots are excluded from the game pack. Browser-specific graphics settings reduce MSAA and shadow-map size. Service-worker/PWA caching is disabled for this first edition, so ordinary reloads retrieve the current build.

This build reads the checkout at `/Users/stephenmoock/Documents/ChatGPT/Breakfast Balls`. Its starting game source matched the separate desktop project at `/Users/stephenmoock/Documents/ChatGPT/Godot/breakfast-balls`. The two folders are independent: later changes in the desktop editor are not automatically copied here, and changes here are not automatically copied into that editor project. Reconcile the intended source changes before exporting a new edition.

## Browser scope

The first release targets desktop and laptop browsers with a keyboard and mouse or trackpad. Chrome, Edge, and Firefox are the initial browser targets. Safari and mobile devices need their own gameplay and performance checks; a page loading on a phone does not establish usable touch controls or acceptable frame rate. Native performance measurements are not browser performance results.

Choose **Play online** to create a private room, share its invite link or six-character code, and start when two to four players have joined. Everyone uses their own computer and controls their own golfer. Local hot-seat play remains available. Online rooms need the configured room API and Redis database; a static-only copy supports local play. See [ONLINE.md](ONLINE.md) for setup, reconnect behavior, and verification. There are no player accounts, public matchmaking, or online leaderboards.

Swing-input guidance and local club records remain in the current browser's storage. Local rounds are not saved; online rooms retain their shared checkpoint for 24 hours. Online rounds do not write local club records. Tee selection and sound choice are not saved as browser preferences. Clearing site data removes them; another browser or device has a separate record book. Browser storage restrictions can prevent persistence. Audio and fullscreen depend on player interaction. See [Godot's browser limitations](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#limitations).

## Publish and update

Vercel hosts the generated game and private-room API in its own project. The account's GitHub Pages address inherits the existing `smoock.com` custom domain, which does not serve this game. A separate Vercel project provides a working game address without changing that domain. The `gh-pages` branch, if present, is a generated mirror rather than the production host.

After building and checking the game, use the deployment wrapper from the repository root:

```sh
python3 tools/deploy_web.py
```

The wrapper is the publication entry point: it validates every generated file's hash and prepares `builds/vercel`, keeping Vercel's project metadata outside `builds/web`. Generated assets go in `builds/vercel/public`; `api/room.js` and its server modules are deployed separately from public files. It targets project `breakfast-balls` in scope `smoocks-projects` by default; `--project` and `--scope` override those values. `--prepare-only` validates and stages without publishing. Development environment files created by the CLI are excluded and removed before publication.

Use a current Vercel CLI (at least 47.2.2) and an authenticated account with access to the project. Deployment was verified with CLI 59.25.0 and Node 22.22.1. If the globally installed CLI is older, use a current executable with `--vercel /path/to/vercel`, or run the pinned CLI without changing the global installation:

```sh
npx --yes --package=vercel@59.25.0 -c 'python3 tools/deploy_web.py'
```

For a direct CLI deployment, first run `python3 tools/deploy_web.py --prepare-only`, then deploy the prepared directory:

```sh
vercel deploy builds/vercel --prod
```

Use the generated `vercel.json`: **Other** framework, no application build step, `public` output directory, and the Node.js room function. Redis credentials belong only in Vercel's server environment; never add them to HTML or JavaScript. Serve `.wasm` as `application/wasm`. The [official Vercel CLI documentation](https://vercel.com/docs/cli/deploy) describes directory deployment and the `--prod` option. Check the actual game after publication.

For repeatable builds, `.github/workflows/web.yml` provides **Build web artifact**. Run it through **Actions → Build web artifact → Run workflow**. The workflow must first be on the repository's default branch for that entry point to appear. It downloads the pinned official Godot editor and template archive, verifies both against the official SHA-512 manifest, installs the web templates, runs the same Python builder, and uploads `breakfast-balls-web.zip` as an Actions artifact. The archive includes the static website and build manifest. Online play also requires the API source and Redis configuration from this repository; the archive by itself is a local-play website.

The workflow is manual-only and does not publish a site or change hosting settings. It needs no Vercel credentials or Pages permissions. Commits do not automatically change the live game.

## Release verification

With the browser build served on port 8060, install the locked test dependencies and run the browser journey from a second terminal:

```sh
npm ci
npm run test:web
node tests/web_shell.mjs
```

The test runner requires Node.js 20 or later and an installed Google Chrome. It uses Playwright's `chrome` channel and runs headlessly by default. `HEADED=1 npm run test:web` shows the browser. `WEB_URL` selects another served build, and `BROWSER_CHANNEL` selects another installed compatible browser channel. Screenshots and the JSON report are written under `test-results/`.

Run the shared-gameplay and web-policy checks with the same Godot executable used for export:

```sh
godot --headless --path . --script res://tests/web_compat_tests.gd
godot --headless --path . --script res://tests/feedback_tests.gd
```

Use the executable's full path in place of `godot` if it is not on `PATH`. The final local verification recorded **76 web compatibility and font checks** and **76 feedback checks**, all with zero failures. The exported-browser journey recorded **72 checks and zero browser errors**, including mouse swings and a complete two-player Pin Challenge. Another **9 launcher checks** passed for keyboard focus, fullscreen, resize, download failure, and unsupported browsers. Its WebGL renderer reported **ANGLE Metal Renderer: Apple M1**, indicating the browser used the hardware graphics path. These are observed functional test results on that machine, not frame-rate benchmarks or a claim about other browsers and devices. Later releases should record their own results.

Check a real player journey in the exported browser game: launch, enter practice, putt/chip/pitch, start a round, charge and release a shot, keep or retry the opening shot, open the scorecard, and return to the clubhouse. Also check window resizing, fullscreen, sound, focus loss during a charged swing, and preference persistence after reloading. Inspect the browser console for engine or WebGL errors. Compare performance on the same hole, view, browser, and hardware; report software-rendered checks separately.

The repository's existing headless gameplay checks still validate shared rules and physics. They do not validate the browser launcher, graphics, audio policy, keyboard focus, or storage behavior. Human playtesting remains the deciding check for swing feel.

## Third-party notices

`web/THIRD_PARTY_NOTICES.txt` retains Godot 4.7.2's complete upstream engine license and copyright notices with source links. The font files retain their own notices under `game/assets/fonts`. Distribute the generated website's `third-party-notices.txt` alongside the game, including both the engine notices and font licenses. Godot's [license guidance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html) recommends including its upstream copyright file to cover bundled engine dependencies.
