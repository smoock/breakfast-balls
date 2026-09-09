extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game=load("res://game/main.gd").new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.records_enabled=false
	var failures: int=0
	for name in ["golfer_polo","golfer_pelvis","golfer_shoe","tree_pine_a","tree_broadleaf_a"]:
		if game.course._mesh_from_scene("res://game/assets/models/%s.glb"%name)==null:
			printerr("MISSING MODEL: "+name); failures+=1
	for i in range(8):
		if load("res://game/assets/portraits/golfer-%d.png"%i)==null:
			printerr("MISSING PORTRAIT: %d"%i); failures+=1
	game.sound_enabled=true; game._start_music()
	if game.music.stream==null or not game.music.playing:
		printerr("MUSIC NOT PLAYING"); failures+=1
	else:
		if game.music.stream.get_length()<20 or game.music.stream.loop_end<=0:
			printerr("INVALID MUSIC LOOP"); failures+=1
		print("MUSIC: %.2f seconds, loop end %d, playing %s"%[game.music.stream.get_length(),game.music.stream.loop_end,game.music.playing])
	print("EXPORT_ASSET_TESTS: %d failures"%failures)
	game.free(); quit(1 if failures else 0)
