extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game=load("res://game/main.gd").new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.records_enabled=false; game.sound_enabled=false; game.music.stop()
	game.mode=0; game.player_count=1; game.round_length=18; game.start_round()
	for hole in [0,12,15]:
		game.hole_index=hole; game.start_hole()
		game.camera.position=game.course.pin+Vector3(28,36,48)
		game.camera.look_at(game.course.pin)
		for frame in range(60): await process_frame
		var start: int=Time.get_ticks_usec()
		for frame in range(180): await process_frame
		var seconds: float=(Time.get_ticks_usec()-start)/1000000.0
		print("COURSE_RENDER_CHECK hole=%d fps=%.1f draw_calls=%d triangles=%d"%[hole+1,180.0/seconds,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	game.free(); quit()
