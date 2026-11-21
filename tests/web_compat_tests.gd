extends SceneTree

const Main=preload("res://game/main.gd")
const WebBridge=preload("res://game/web_bridge.gd")

# Exercise web policy on the native test runner, without exporting a runtime
# override or any browser command/debug interface in the shipped game.
class BrowserGame extends Main:
	func is_web() -> bool:
		return true

var game: Node3D
var checks: int=0
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+label)

func key(code: Key,pressed: bool=true) -> void:
	var event:=InputEventKey.new()
	event.keycode=code; event.pressed=pressed
	game._input(event)

func mouse(position: Vector2,pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.position=position; event.pressed=pressed
	game._input(event)

func run() -> void:
	game=BrowserGame.new()
	game.sound_enabled=false; game.records_enabled=false
	game.preferences_path=OS.get_cache_dir()+"/breakfast-web-test-preferences.cfg"
	game.leaderboard_path=OS.get_cache_dir()+"/breakfast-web-test-records.json"
	root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.qa_mode=true; game.qa_step=1
	check(game.hud.font.get_font_name()=="Noto Sans" and game.hud.bold.get_font_name()=="Noto Sans" and game.hud.serif.get_font_name()=="Libre Baskerville","web uses bundled body, bold and clubhouse serif fonts")
	for face in [game.hud.font,game.hud.bold,game.hud.serif]:
		for character in "→↵←↑↓°×—·Ⅱ–−●◯⚑":
			check(face.has_char(character.unicode_at(0)),"bundled fonts cover UI glyph U+%04X"%character.unicode_at(0))
	check(game.hud.serif.get_string_size("Breakfast",HORIZONTAL_ALIGNMENT_LEFT,-1,58).x<405,"web title fits clubhouse panel")
	check(game.hud.font.get_string_size("Swing guidance and local club records save in this browser.",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<668,"web save notice fits settings panel")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.state=="menu" and not game.focus_paused,"focus loss keeps clubhouse usable")
	game.hud._action("remote"); game.hud._action("parsec")
	check(not game.remote_timing_enabled and not game.parsec_setup_open,"desktop remote controls unavailable on web")
	game.player_count=2; game.remote_timing_enabled=true
	game.begin_name_entry()
	check(not game.remote_timing_enabled,"web name entry disables guest calibration")
	game.name_entry_value="ALPHA"; game._accept_name_entry()
	game.name_entry_value="BRAVO"; game._accept_name_entry()
	check(game.state=="aim" and game.players.size()==2,"two players start same-device round directly")
	game.remote_timing_enabled=true; game.timing_offsets[1]=0.3
	check(game.player_timing_offset(1)==0.0,"web cannot apply stale remote timing")
	game.start_practice()
	var origin: Vector3=game.ball_pos
	key(KEY_SPACE); game._process(0.8)
	check(game.keyboard_charge and game.charge>0.4,"actual keyboard input builds power")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state=="pause" and game.previous_state=="aim" and game.focus_paused,"tab focus loss pauses aiming")
	check(not game.keyboard_charge and not game.dragging and not game.aiming_drag and game.charge==0.0 and game.pull==0.0 and game.swing_clock==0.0,"focus loss clears all swing input")
	key(KEY_SPACE,false)
	check(game.players[0].strokes==0 and game.ball_pos==origin,"release while unfocused does not shoot")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.previous_state=="aim","duplicate focus notifications preserve resume state")
	game.hud._action("resume"); key(KEY_SPACE,false)
	check(game.state=="aim" and not game.focus_paused and game.players[0].strokes==0,"stale key release after resume does not shoot")
	mouse(Vector2(1050,612),true)
	var motion:=InputEventMouseMotion.new()
	motion.position=Vector2(1090,702); game._input(motion)
	game._process(0.5)
	check(game.dragging and game.pull>0.9 and game.path_offset>0,"actual mouse gesture builds a shaped shot")
	game.pause_play(true); game.resume_play()
	mouse(Vector2(1090,702),false)
	check(game.state=="aim" and game.players[0].strokes==0 and game.path_offset==0.0,"stale drag release after refocus is cancelled")
	mouse(Vector2(500,350),true)
	check(game.aiming_drag,"course gesture begins aim drag")
	var old_aim: float=game.aim
	game.pause_play(true); game.resume_play()
	motion.position=Vector2(620,350); game._input(motion)
	check(not game.aiming_drag and game.aim==old_aim,"focus loss cancels course aiming drag")
	key(KEY_SPACE); game._process(0.4); key(KEY_SPACE,false)
	check(game.state=="flight" and game.players[0].strokes==1,"fresh input after resume fires one shot")
	game._physics_process(0.2)
	var before_flight: Array=[game.ball_pos,game.velocity,game.swing_elapsed,game.shot_time]
	game.pause_play(true)
	game._physics_process(1.0); game._process(1.0)
	check([game.ball_pos,game.velocity,game.swing_elapsed,game.shot_time]==before_flight,"focus pause freezes committed shot physics")
	game.resume_play(); game._physics_process(1.0/60.0)
	check(game.state=="flight" and game.swing_elapsed>before_flight[2] and game.players[0].strokes==1,"committed shot resumes once without adding strokes")
	game.retry_practice()
	game.help_open=true; game.pause_play(true)
	check(game.state=="pause" and game.help_open,"focus pause preserves open field guide")
	game.hud._action("closehelp"); game.resume_play()
	check(game.state=="aim" and not game.help_open,"field guide can close before resuming")
	game.state="replay"; game.replay_time=0.75
	game.pause_play(true); game._process(1.0)
	check(game.previous_state=="replay" and game.replay_time==0.75,"focus pause freezes replay progress")
	game.resume_play()
	check(game.state=="replay","replay resume restores replay state")
	game.retry_practice()
	game.hud._action("input:1")
	var state: Dictionary=WebBridge.snapshot(game)
	check(state.state=="aim" and state.practice_active and state.club==13 and state.input_style==1,"snapshot reflects real practice controls")
	check(state.player_count==1 and state.player_index==0 and state.player_strokes==[0] and state.hole_number==14,"snapshot exposes inspectable round and player state")
	check(state.ball.x==origin.x and state.ball.y==origin.y and state.ball.z==origin.z,"snapshot ball coordinates match physics")
	check(state.performance.has_all(["fps","draw_calls","primitives"]) and JSON.parse_string(JSON.stringify(state)) is Dictionary,"snapshot metrics are JSON serializable")
	state.player_strokes[0]=999; state.ball.x=999
	check(game.players[0].strokes==0 and game.ball_pos==origin,"snapshot mutations cannot alter gameplay")
	game.return_to_menu()
	check(game.state=="menu" and not game.practice_active and not game.focus_paused,"return to clubhouse clears focus pause")
	print("WEB_COMPAT_TESTS: %d checks, %d failures"%[checks,failures])
	game.free()
	quit(1 if failures else 0)
