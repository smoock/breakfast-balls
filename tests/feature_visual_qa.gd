extends SceneTree

const Main=preload("res://game/main.gd")
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	game._process(0.0)
	game._update_camera(1.0,true)
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/breakfast-"+label+".png")
	print("FEATURE_QA_CAPTURE "+label)

func swing(power: float) -> void:
	game.shoot(power)
	for frame in range(2400):
		if game.state!="flight": return
		game._physics_process(1.0/60.0)
	printerr("FEATURE_QA shot failed to settle")
	quit(1)

func run() -> void:
	game=Main.new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.toggle_sound()
	game.records_enabled=false; game.qa_mode=true; game.qa_step=1
	game.mode=0
	await capture("normal-menu")
	game.round_length=9; game.player_count=2; game.start_round()
	swing(0.35)
	await capture("opening-choice")
	game.hud._action("breakfast")
	await capture("retry-tee")
	game.mode=2; game.state="menu"
	await capture("challenge-menu")
	game.player_count=4; game.start_round()
	await capture("challenge-tee")
	for hole in range(3):
		for golfer in range(4):
			swing(0.97 if golfer==0 else 1.0 if golfer==1 else 0.85 if golfer==2 else 0.05)
			if hole==0 and golfer==0: await capture("challenge-result")
			game.hud._action("continue")
		if hole==0: await capture("challenge-scorecard")
		game.hud._action("next")
	await capture("challenge-final")
	game.hud._action("retrychallenge")
	await capture("challenge-rematch")
	print("FEATURE_VISUAL_QA_COMPLETE")
	game.free()
	quit()
