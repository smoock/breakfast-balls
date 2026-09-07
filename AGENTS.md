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

Local setup (verified during this conversation; recheck when needed):

- Godot project: `/Users/stephenmoock/Documents/ChatGPT/Godot/breakfast-balls` (outside this workspace).
- Godot MCP editor port: 9876.
- Blender MCP port: 9878. Its installed add-on defaults were locally adjusted; updates may reset them.
- Blender telemetry disabled.
