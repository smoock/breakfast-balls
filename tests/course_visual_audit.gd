extends SceneTree

const Main=preload("res://game/main.gd")
var game: Node3D
var output: String="/private/tmp/breakfast-audit"
var metrics: Array=[]
var motion_only: bool=false
var selected_holes: Array=[]

func _initialize() -> void:
	call_deferred("run")

func capture(label: String,focus: Vector3,offset: Vector3) -> void:
	game.camera.position=focus+offset
	game.camera.look_at(focus,Vector3.UP)
	for frame in range(8): await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
	metrics.append({"view":label,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	print("AUDIT_CAPTURE "+label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg=="--motion-only": motion_only=true
		if arg.begins_with("--holes="):
			for value in arg.trim_prefix("--holes=").split(","): selected_holes.append(int(value)-1)
	DirAccess.make_dir_recursive_absolute(output)
	game=Main.new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.sound_enabled=false; game.music.stop(); game.records_enabled=false
	game.qa_mode=true; game.qa_step=1; game.mode=0; game.round_length=18; game.player_count=1
	game.start_round(); game.hud.hide(); game.marker.hide()
	for hole in range(18):
		if motion_only: break
		if not selected_holes.is_empty() and not hole in selected_holes: continue
		game.hole_index=hole; game.round_position=hole; game.start_hole()
		game.golfer.hide(); game.ball.hide(); game.marker.hide()
		var pin: Vector3=game.course.pin
		await capture("%02d-green"%[hole+1],pin,Vector3(28,36,48))
		var focus: Vector3=pin
		if not game.course.bunkers.is_empty():
			var e: Vector4=game.course.bunkers[0]
			focus=game.course.ground_point(e.x,e.y)
		await capture("%02d-bunker"%[hole+1],focus,Vector3(11,12,17))
		for index in range(game.course.bunkers.size()):
			var e: Vector4=game.course.bunkers[index]
			var center: Vector3=game.course.ground_point(e.x,e.y)
			var radius: float=maxf(e.z,e.w)
			await capture("%02d-sand-%02d"%[hole+1,index+1],center,Vector3(radius*0.75,radius*1.25,radius*1.5))
			await capture("%02d-lip-%02d"%[hole+1,index+1],center,Vector3(radius*0.3,3.5,radius+6.0))
		var point: Vector3=game.course.ground_point(game.course.center_x(-game.course.length_m*0.6),-game.course.length_m*0.6)
		await capture("%02d-fairway"%[hole+1],point,Vector3(38,60,75))
		if not game.course.ponds.is_empty():
			var e: Vector4=game.course.ponds[0]
			await capture("%02d-water"%[hole+1],game.course.ground_point(e.x,e.y),Vector3(20,25,35))
			if game.course.ponds.size()>2:
				var creek: Vector4=game.course.ponds[game.course.ponds.size()/2]
				await capture("%02d-creek"%[hole+1],game.course.ground_point(creek.x,creek.y),Vector3(13,18,25))
		# Normal player view is included alongside the overhead inspection cameras.
		game.players[0].pos=game.course.ground_point(pin.x,pin.z+9,0.22)
		game._prepare_turn(); game.golfer.show(); game.ball.show(); game.marker.hide()
		var player_offset: Vector3=game.camera.position-game.ball_pos
		await capture("%02d-play"%[hole+1],game.ball_pos,player_offset)
	game.hole_index=0; game.start_hole(); game.golfer.show(); game.ball.show()
	for i in range(7):
		var angle: float=[0.0,-1.0,-2.25,-0.6,0.0,1.2,2.25][i]
		game._pose_swing(angle)
		await capture("swing-%d"%i,game.golfer.position+Vector3(0,1.25,0),Vector3(1.8,1.0,4.3))
	# Capture an actual simulated swing and ball release, not just selected poses.
	game._prepare_turn(); game.breakfast_offer=false; game.shoot(1.0)
	DirAccess.make_dir_recursive_absolute(output+"/motion")
	for frame in range(100):
		game._physics_process(1.0/50.0)
		game.camera.position=game.golfer.position+Vector3(1.8,2.25,4.3)
		game.camera.look_at(game.golfer.position+Vector3(0,1.25,0),Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/motion/%03d.png"%frame)
	var file:=FileAccess.open(output+"/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	game.free(); print("VISUAL_AUDIT_COMPLETE"); quit()
