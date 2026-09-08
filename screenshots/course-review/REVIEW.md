# Magnolia Pines visual review — September 7, 2026

## Coverage

- All 18 holes: green surrounds, fairways and normal player-camera views.
- All 44 authored bunker ellipses: overhead interiors and low-angle lips (some form compound bunkers).
- All water-bearing holes, plus a dedicated view down Hole 13's creek.
- Seven swing checkpoints and 100 rendered frames of an actual simulated swing/ball release.

The contact sheets are assembled from Godot captures, not generated concept art. Hole numbers and view names appear above each image. The final character foot/buckle corrections are shown in the swing sheets and `swing.gif`; the full-hole player sheets precede those small character-only corrections.

## Findings and corrections

The former independent turf, green, rim, sand and water meshes intersected. Replacing them with one 1.25-metre indexed terrain surface removed the grass islands and overlapping strips. Shared hazard masks, smooth vertex normals, recessed sand bowls, level ponds and distance-filtered texture detail eliminate the broken transitions shown in the user's screenshots. The course remains stylized rather than photorealistic.

The individual-hole review additionally found a disconnected creek on Hole 13 and an overlapping lake/bunker on Hole 16. The creek now uses a continuous capsule path for rendering, terrain, lie detection and the yardage book. Hole 16's affected bunker moved slightly inland, leaving a grass bank. Final dedicated views are retained here.

Tree branch-coordinate conversion and joined-mesh origins were corrected in Blender. Editable tree and golfer component sources are retained in `game/assets/source_blender/`, with generator scripts in `tools/`.

The golfer now has tailored body/shoe meshes, hip/shoulder separation, weight shift, knee movement, a grounded lead foot, a lifted trailing heel, constrained two-bone arms and target-facing head movement after impact. The belt buckle follows the pelvis. Shaft length, impact alignment and existing launch timing remain intact.

## Automated checks

- Core golf suite: 237 checks, zero failures.
- Breakfast Ball / Pin Challenge suite: 121 checks, zero failures, including a four-player three-hole physics journey.
- Surface/swing suite: 9,197 checks, zero failures. Includes a settling tee shot on every hole, continuous creek classifications, Hole 16 lake separation, hazard-edge height continuity, finite articulated transforms, arm reach, planted lead foot and exact impact alignment at four aim headings.
- Largest sampled height change across a 2-cm hazard-boundary interval: 0.00849 m (continuous terrain slope, not a gap).

These are repeatable visual and simulation checks, not a claim that a human manually played 18 full holes or that every possible camera/lie combination was inspected. Human playtesting remains useful for judging swing feel.

The synced live project also passed the 9,197-check surface/swing suite. A separate short Apple M1 Compatibility/OpenGL rendering run measured 95.9 FPS on Hole 1, 86.9 on Hole 13 and 115.5 on Hole 16, with 233/233/265 draw calls respectively. These fixed-view samples exclude scene construction and are not sustained whole-round or cross-hardware guarantees.

## Reproduction

Run the commands in the README's “Continuous-surface visual revision” section. The audit writes raw captures to a temporary output folder; the companion Pillow script assembles the retained sheet format and animation. `tests/course_performance.gd` warms up and samples fixed Hole 1, 13 and 16 views on the active renderer, excluding course construction from timing. Headless gameplay tests do not measure rendering performance.
