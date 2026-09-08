# Breakfast Balls

A playable native Godot 4.7 golf prototype: local hot-seat golf, playful golfers, tour-scale distances, and an original 18-hole par-72 course called **Magnolia Pines**. No account, network connection, or downloaded assets are required to play.

## Play

Open `project.godot` in Godot and press **F6** with the main scene open, or **F5** to run the project. Choose 1–4 players, each golfer, Stroke Play or Skins, and a 3-, 9-, or 18-hole round. Three-hole rounds draw three distinct random holes in random order. Nine-hole rounds offer Front 9 (1–9) or Back 9 (10–18). All eight golfers have identical gameplay stats.

For free remote play, choose **Parsec Remote Play** on the clubhouse screen. The setup card can open Parsec and explains the host flow: enable Hosting, share the computer link, accept each guest, and grant keyboard and mouse permission. Return to the game, choose a player count, and enable **Timing**. Player 1 is the host and remains unadjusted. Before the round, each guest completes three one-way meter passes; the median measured delay corrects that player's clubface evaluation while leaving the visible meter, its speed, and the swing mechanic unchanged.

Parsec requires no game SDK, App ID, submission fee, or game server. It streams the host's screen and merges guest input into the existing local hot-seat controls. On macOS, Parsec hosting requires Screen Recording and Accessibility permission. Guests need keyboard and mouse permission because Breakfast Balls does not currently use gamepads. For safer sharing, close private windows before hosting; Parsec's macOS host does not support its Approved Apps restriction.

- Aim by dragging across the course or using Left/Right.
- Select one of the 14 clubs along the bottom; Q/E or mouse wheel cycles clubs.
- In the gold swing pad, click and hold near the top, pull down for power, then push forward and release. Sideways offset at the bottom sets swing path. The moving meter sets clubface at release; returning off-center adds face error. Power retains the deepest backswing, so a trackpad works too.
- For straight shots, keep the path centered and release with the face needle in the green center zone. A rightward backswing with a square face draws; a leftward backswing fades. Large face/path mismatches hook or slice; aligned face/path errors push or pull. Curvature is simulated throughout flight, not just applied as a launch-angle change. Putts use face error for starting direction but do not curve aerodynamically.
- Alternatively, hold Space for power, tap A/D to adjust path, and time release against the same clubface meter. Keyboard shots no longer bypass accuracy.
- S cycles spin, V shows the whole hole, Tab opens the scorecard, H opens help, and Escape pauses.
- Enter continues after a shot or advances from a completed-hole scorecard.
- On greens, the gold arrow shows the local downhill direction. Adjust aim and power for the break.

## Breakfast Ball and Pin Challenge

In Stroke Play and Skins, each golfer may retry their first tee shot of the round once. After the ball settles (and after any replay), choose **PLAY IT** / Enter to keep it, or **BREAKFAST BALL** / B to return to the tee. The retry clears that shot and any water/OB penalty, keeps the same golfer and wind, and plays an egg-crack sound with a fresh-start message. The offer expires when you keep the shot; it cannot be saved for a later hole. The HUD marks **BREAKFAST BALL USED**, and the scorecard marks that golfer with an asterisk. Using a Breakfast Ball makes that golfer's round ineligible for club records. Opening-shot records are saved only after choosing to keep the shot, so discarded drives and aces never enter the record book.

Choose **Pin Challenge** in the clubhouse for the closest-to-pin Diner Special. One to four golfers play holes **6, 12, and 16**, with one tee shot each per hole and the same wind for everyone. There are no mulligans or follow-up putts. A hole-out earns 100 points. Otherwise, finish on the green to earn `max(0, 100 - ceil(distance in feet))`, capped at 99; distance is measured at rest to the nearest tenth of a foot. Missed greens, water, and OB earn zero. The scorecard shows distance and points for each attempt. Highest total out of 300 wins; tied leaders share the win. Solo play shows your total, and **Another Serving** starts a fresh challenge with the same players. Challenge results do not affect the normal golf record book.

Run feature checks with `godot --headless --path . --script res://tests/breakfast_challenge_tests.gd`. They cover opening-shot decisions, penalties, record handling, replay return, and a full four-player challenge using ball physics. For rendered menu/result/scorecard checks, run `godot --path . --script res://tests/feature_visual_qa.gd`; screenshots are written to `/private/tmp/breakfast-*.png`. These checks supplement human playtesting of swing feel.

## Rules and physics

Revision 6: putter power estimates roll distance by integrating rolling resistance and slope along the aimed path, including transitions from longer grass onto the green. Launch and rolling physics now share the same resistance values instead of using a mismatched off-green launch constant. This is an assisted distance estimate, not a guarantee: lateral break, impacts, hazards and overswing can still change the result. Regression tests cover two power levels on every grass/sand surface and fairway/rough-to-green transitions on flat, uphill and downhill paths.

Clubface timing now depends on the starting lie for both mouse and keyboard: tee/fairway/green 1.00×, first cut 1.25×, second cut 1.60× and bunker 1.90× slider speed. The swing panel displays the multiplier. Power charging and overswing thresholds do not speed up with the contact slider.

Revision 5: both mouse and keyboard power continue charging while held, capped at 160%. Beyond 100%, overswing progressively reduces clean contact (up to 39% power loss) and adds face error; the meter and shot result flag the penalty. Waiting just below 100% does not bypass it. Trunks use swept collisions and explicit separation; foliage slows a ball only once per tree per shot. First cut has a 92% carry factor and moderate roll resistance; second cut retains the former rough's 80% factor and heavier resistance.

Tee, fairway, first cut, second cut and green have distinct mowing, color and grain treatments. Sand has distance-filtered rake marks and grain; water has animated ripples, highlights and shallow-edge coloring. The mini-map uses equal X/Z scale, actual fairway boundaries and hazard ellipses, player markers, shot trail, target line, tee-origin 100-yard guides and a 50-yard scale bar.

Flight/swing revision: the simulation now runs at real time rather than the original 2.4× speed. Full-power airborne shots use a calibrated 6.0-second driver to 4.4-second lob-wedge flight envelope on level ground, with power, lie, spin and elevation changing actual hang time. Carry baselines are preserved; this remains an arcade ballistic model, not a full aerodynamic simulation. The club animates through backswing, downswing, impact and follow-through; the ball launches at 0.85 seconds, and the camera stays at the golfer until 1.65 seconds. An airborne ring, edge pointer, height/time readout and longer trail track the ball.

Players tee off in order, then the farthest unfinished ball plays next. Stroke Play rewards the lowest total. Skins requires at least two players: the unique lowest score wins the hole's pot; tied lows carry the pot forward. An unresolved pot on the final hole expires. Tied final leaders share the win.

Water and out-of-bounds use a simple house rule: one penalty stroke and replay from the previous lie. Each hole caps at par + 5. These are arcade rules, not a complete implementation of tournament golf rules.

The shared terrain model controls ball bounce, roll, green slope, rough, bunkers, water and bounds. Wind affects airborne balls, trees can deflect shots, and spin changes flight and landing behavior. The cup is deliberately forgiving. Distances vary with elevation, lie, wind and roll; the displayed bag distances are carry baselines. Physics is simplified for accessible play, not a professional golf simulator.

## Distance source

The [Trackman PGA Tour averages chart, published May 2, 2024](https://www.trackman.com/blog/introducing-updated-tour-averages), supplies these carry baselines in yards: Driver 282, 3W 249, 5W 236, hybrid 231, 5i 199, 6i 188, 7i 176, 8i 164, 9i 152, PW 142.

The chart does not specify a 4-hybrid or the three specialty wedges. The 4H uses its generic hybrid figure as a proxy; GW 120, SW 105 and LW 85 are explicitly gameplay estimates, not measured PGA averages. The putter uses a variable 6–35-yard power scale rather than a fictitious carry average. Estimated values are identified in the game data/UI.

## Course and visual direction

Revision 7 uses the 18 diagram images and yardages in [Today's Golfer's Augusta National course guide](https://www.todays-golfer.com/news-and-events/majors/the-masters/augusta-national-hole-by-hole-course-guide/). Each hole now has separate routing and width profiles, individual bunker groups, water features and elliptical green proportions. The game preserves its fictional hole names. See `game/layouts.gd` for editable values. Diagram interpretation is approximate: elevations remain stylized, distances are longitudinal baselines rather than surveyed centerline lengths, greens do not reproduce every contour, hazards use ellipse unions, and holes are loaded individually rather than arranged geographically on one estate. This is not an exact Augusta replica.

Eight generated cartoon portraits are in `game/assets/portraits/golfer-0.png` through `golfer-7.png`. They appear in the home screen and player HUD. They also served as visual references for the higher-detail procedural models in `game/character.gd`: facial geometry, eyes, brows, ears, noses, hair/beards, distinct builds, caps, collars and buttons. The models are genuinely 3D but simpler than the portrait renders; the portrait images are not automatically converted into meshes or pasted onto billboard characters. All portraits were created with the built-in image-generation tool; full prompts are retained at `references/portrait-prompts.md` in the development workspace.

Magnolia Pines is an original, stylized course inspired by Augusta's pine corridors, azaleas, rolling terrain, strategic water and dramatic greens. It is not a surveyed replica, and has no affiliation with Augusta National, the Masters or Golden Tee. Geometry and golfer models are editable procedural Godot code; no Blender asset pipeline is required for this first build.

## Development and verification

### Swing and feedback revision 4

The [user-supplied swing GIF](https://i.imgur.com/A72Bu.gif) was inspected at address, takeaway and the top of the swing. The procedural rig now uses a forward hip hinge, shoulder turn, staged hand positions, wrist hinge and constant shaft length instead of a single pendulum rotation. This is a stylized keyframed approximation, not motion capture. Swing-stage badges are removed. Eight distinct vector portraits replace the old recolored faces. Per-category commentary cycles without consecutive repetition, distinguishing short/long putts, holed shots, approaches, drives, fairway, rough, sand and penalties.

### Graphics revision 2

The two supplied references are retained in `references/` in the development workspace. The illustrated image guides teal atmospheric distance, warm sunlight and softer silhouettes; the course screenshot guides vegetation density, turf detail and shadow depth. This is a stylized interpretation, not a photorealistic match.

The revision adds branched, multi-crown trees; subtle procedural turf shading; clustered shrubs and small azalea blossoms; layered distant hills and cloud banks; tee furniture; a closer golfer-level camera; a more articulated golfer; and 4× MSAA with higher-resolution directional shadows. Gameplay terrain and rules remain shared with the first version. Short 1280×800 Apple M1 checks measured about 70–85 FPS before the final flower refinement; these are spot checks, not a sustained performance benchmark. Screenshots are retained under `screenshots/` in the development workspace.

Visual v2 replaces the course's identical sphere-crown vegetation with two Blender-authored, color-separated tree families, batched through Godot `MultiMesh` instances. Editable generation source is retained in `tools/build_visual_v2_assets.py` and `game/assets/source_blender/visual_v2_trees.blend`; portable GLB exports live in `game/assets/models/`. The golfer now has a tapered torso, pelvis, neck, shoulder caps and knee forms while retaining the code-driven swing and impact timing. Compound ponds are rendered as one seam-free surface over the existing gameplay ellipses, with a damp bank, depth color, Fresnel response and subtle moving normals. Bunkers use recessed geometry, darker lips, multiscale sand grain and curved rake marks. A fixed Hole 13 Apple M1 Compatibility-renderer spot check measured 52 FPS, 924 draw calls and 2.69 million visible triangles; this is a representative visual-quality check, not a hardware-wide benchmark.

The broadcast presentation pass adds the original 26.7-second looping cue **Magnolia Morning**, generated from the retained source in `tools/generate_magnolia_morning.py`. It uses soft electric-piano, string, bass and brush textures and does not reproduce any broadcast theme. Starting a round now collects one five-letter local tag per player. `user://leaderboard.json` retains the longest valid first-shot drive, best front nine, best back nine, full-course total and the most recent player tags without an account or network connection. Hole-in-ones, eagles, long hole-outs, long putts, exceptional approaches and record drives can trigger a skippable slow-motion replay using the actual sampled ball path, a moving cinematic camera, gold afterimages and broadcast framing. Repeatable `--qa-name`, `--qa-board` and `--qa-replay` scenes cover the new presentation states.

Main scene: `game/main.tscn`. Gameplay and input: `game/main.gd`. Shared course geometry/terrain: `game/course.gd`. Roster, club and hole data: `game/data.gd`. Interface: `game/hud.gd`.

Run automated checks with `godot --headless --path . --script res://tests/golf_tests.gd`. These cover input events, settling shots, a real short putt, penalties, player separation, Skins carryovers, pause, and 18-hole scoring progression. Full-round scoring tests inject hole scores; they are not a claim that every hole has been manually played. Visual QA: `godot --path . -- --qa --qa-play --qa-exit` saves a screenshot in `/private/tmp/breakfast-balls-qa.png`. Use `--qa-calibration` for remote timing or `--qa-parsec` for the Parsec setup card.

This first version does not include saved rounds, gamepad support, authored character animations, tournament-accurate rules, or a packaged standalone app. Playtesting should guide the next pass on swing feel, difficulty, camera and art.
