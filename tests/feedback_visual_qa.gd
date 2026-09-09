extends SceneTree

const Main=preload("res://game/main.gd")
var game: Node3D
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+label)

func capture(label: String) -> void:
	game._process(0.0); game._update_camera(1.0,true); game.hud.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/breakfast-feedback-"+label+".png")
	print("FEEDBACK_QA_CAPTURE "+label)

func click_action(action: String) -> void:
	game.hud.queue_redraw(); await process_frame; await process_frame
	for entry in game.hud.buttons:
		if entry[1]!=action: continue
		var event:=InputEventMouseButton.new(); event.position=entry[0].get_center()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; Input.parse_input_event(event)
		await process_frame
		event=event.duplicate(); event.pressed=false; Input.parse_input_event(event)
		await process_frame
		return
	check(false,"button available: "+action)

func key(code: Key,pressed: bool=true) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	game=Main.new(); game.sound_enabled=false; root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.records_enabled=false; game.qa_mode=true; game.qa_step=1
	game.preferences_path="/private/tmp/breakfast-feedback-visual-preferences.cfg"
	game.leaderboard_path="/private/tmp/breakfast-feedback-visual-records.json"
	game.input_style=0
	await capture("menu")
	for action in ["input:0","input:1","tees:0","tees:1","sound","remote","parsec"]:
		check(not game.hud.buttons.any(func(entry): return entry[1]==action),"setting removed from home: "+action)
	await click_action("settings"); await capture("settings")
	await key(KEY_ENTER); await key(KEY_H)
	check(game.settings_open and game.state=="menu" and not game.help_open,"settings blocks background shortcuts")
	await click_action("sound"); check(game.sound_enabled,"settings enables sound")
	await click_action("sound"); check(not game.sound_enabled,"settings disables sound")
	await click_action("remote"); check(game.remote_timing_enabled,"settings enables guest timing")
	await click_action("parsec"); await capture("settings-parsec")
	await key(KEY_ESCAPE)
	check(game.settings_open and not game.parsec_setup_open,"Escape from Parsec returns to settings")
	await click_action("parsec"); await click_action("closeparsec")
	check(game.settings_open and not game.parsec_setup_open,"Parsec back button returns to settings")
	await click_action("remote")
	await click_action("input:1"); await click_action("tees:1")
	await click_action("closesettings")
	check(not game.settings_open and game.input_style==1 and game.tees==1,"Done retains settings")
	await click_action("settings"); await key(KEY_ESCAPE)
	check(not game.settings_open and game.state=="menu","Escape closes settings")
	await click_action("mode:2"); await click_action("settings"); await capture("settings-challenge")
	check(not game.hud.buttons.any(func(entry): return entry[1].begins_with("tees:")),"challenge uses locked tees")
	await click_action("closesettings"); await click_action("mode:0")
	game.input_style=0
	await click_action("help"); await capture("help-keyboard")
	await click_action("input:1"); await capture("help-trackpad")
	await click_action("closehelp"); await click_action("settings"); await click_action("input:0"); await click_action("closesettings")
	await click_action("practice")
	check(game.practice_active and game.state=="aim","click enters practice")
	await capture("putt")
	await key(KEY_SPACE); game._process(0.9)
	await capture("putt-power")
	await key(KEY_SPACE,false)
	for frame in range(2400):
		if game.state!="flight": break
		game._physics_process(1.0/60.0)
	check(game.state=="result","keyboard practice shot completes")
	await capture("putt-result")
	await click_action("station:1")
	check(game.state=="aim" and game.style_index()==2,"result button switches to chip")
	await capture("chip")
	await key(KEY_SPACE); game._process(PI/5.6); await key(KEY_SPACE,false)
	for frame in range(2400):
		if game.state!="flight": break
		game._physics_process(1.0/60.0)
	await capture("chip-result")
	await click_action("continue")
	check(game.state=="aim" and game.players[0].strokes==0,"retry button restores shot")
	await click_action("station:2"); await capture("pitch")
	await key(KEY_ESCAPE); await click_action("menu")
	check(not game.practice_active and game.state=="menu","pause exits practice")
	await click_action("settings"); await click_action("tees:1"); await click_action("closesettings"); await click_action("play")
	check(game.state=="name_entry","normal round still collects name")
	game.name_entry_value="TESTY"; await key(KEY_ENTER)
	check(game.round_tees==1 and game.state=="aim","name confirmation enters club tees")
	game.hole_index=2; game.round_holes[0]=2; game.start_hole(); await capture("club-tee")
	await click_action("card"); await capture("scorecard")
	game.return_to_menu(); await click_action("leaderboard"); await capture("records")
	print("FEEDBACK_VISUAL_QA: %d failures"%failures)
	game.free(); quit(1 if failures else 0)
