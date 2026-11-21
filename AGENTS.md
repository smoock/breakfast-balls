# Breakfast Balls project context

The user asked to retain this reference for future game-development prompts:
[Building games with Astra — Thomas Ricouard, September 4, 2026](https://developers.openai.com/blog/how-to-build-games-with-astra).

Apply its workflow to Breakfast Balls:

- Describe the player experience and constraints before choosing implementation details.
- Start with a small playable interaction and refine its feel.
- Establish visual direction with references; save approved images for comparison.
- Build repeatable test scenes, inspectable state, and performance counters early.
- Test actual player journeys as well as isolated scenes; screenshots alone cannot validate gameplay.
- Reproduce issues, inspect state and visuals, fix, and rerun the same checks.
- Measure performance under comparable conditions; distinguish software-rendered tests from hardware performance.
- Use Blender for authored assets, retaining editable sources and checking export costs.
- Keep related visuals and physics consistent through shared underlying data.

Adapt these principles to the existing Godot/Blender workflow; the article's Three.js stack is not a request to change engines. The user's playtesting and visual feedback guide iteration.

## Repository and cloud development

- This repository's root `project.godot` is the active, portable project. Use the current checkout, not a hardcoded Mac directory. The older project under `Documents/ChatGPT/Godot/breakfast-balls` is a separate legacy copy.
- Engine: Godot **4.7.2**, standard edition, Compatibility renderer. Node.js **22** and Python **3** support the web build and tests. Keep Godot and export templates at the same version.
- On a fresh Linux cloud environment, run `bash tools/setup_cloud.sh`. See `CLOUD.md` for environment creation and the mobile workflow.
- Run `python3 tools/verify_cloud.py` for imported assets, gameplay, browser compatibility, online game state, and Node server tests. It checks Godot diagnostics as well as exit codes. Run `python3 tools/verify_cloud.py --build-web` when export or browser assets change.
- Run actual browser journeys for browser-facing changes: build, start `node tools/serve_online.mjs --port 8060`, and use `BROWSER_CHANNEL=chromium npm run test:web` or `BROWSER_CHANNEL=chromium npm run test:online:browser`. These journeys can take several minutes with software rendering. Do not claim they passed unless they ran.
- Cloud headless checks and software-rendered browser tests do not validate visual quality, swing feel, or Mac/GPU performance. Retain the local Godot/Blender playtesting loop.
- Editable Blender sources live under `game/assets/source_blender/` (ignored by Godot); portable runtime models are in `game/assets/models/`. Cloud coding and exports do not require a running Blender or Godot MCP server.
- Work on `codex/<short-description>` branches for mobile changes. Before pushing, inspect the diff, run relevant checks, and report the branch and test results. Never commit unrelated local changes, credentials, generated builds, or dependency caches. Production deployment is a separate action from pushing code.

Local editor integrations (recheck availability when needed):

- Godot MCP editor port: 9876.
- Blender MCP port: 9878. Its installed add-on defaults were locally adjusted; updates may reset them.
- Blender telemetry disabled.
