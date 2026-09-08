extends SceneTree

const Main=preload("res://game/main.gd")
var checks: int=0
var failures: int=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+label)

func run() -> void:
	var game=Main.new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.sound_enabled=false; game.records_enabled=false; game.mode=0
	game.round_length=18; game.player_count=1; game.start_round()
	var max_jump: float=0.0
	for hole in range(18):
		game.hole_index=hole; game.round_position=hole; game.start_hole()
		var course: Node3D=game.course
		check(course.terrain_mesh.mesh.get_surface_count()==1,"hole %d uses a continuous surface"%[hole+1])
		check(course.bunkers.size()<=8 and course.ponds.size()<=24,"all hazards fit material uniforms")
		for i in range(1,course.creek_points.size()):
			for sample in range(11):
				var p: Vector2=course.creek_points[i-1].lerp(course.creek_points[i],sample/10.0)
				check(course.lie_at(Vector3(p.x,0,p.y))=="WATER","creek remains water between authored control points")
		if hole==15:
			var bunker: Vector4=course.bunkers[1]
			for sample in range(64):
				var a: float=TAU*sample/64.0
				var p:=Vector3(bunker.x+cos(a)*bunker.z,0,bunker.y+sin(a)*bunker.w)
				check(course.lie_at(p)!="WATER","hole 16 greenside bunker stays inland of lake")
		for e in course.bunkers+course.ponds:
			for sample in range(64):
				var a: float=TAU*sample/64.0
				var p:=Vector2(e.x+cos(a)*e.z,e.y+sin(a)*e.w)
				var n:=Vector2(cos(a),sin(a))*0.01
				var jump: float=absf(course.height_at(p.x+n.x,p.y+n.y)-course.height_at(p.x-n.x,p.y-n.y))
				max_jump=maxf(max_jump,jump)
				check(jump<0.08,"hole %d hazard boundary has no height discontinuity"%[hole+1])
		game.wind=Vector2.ZERO; game.shoot(0.9)
		for frame in range(2400):
			if game.state!="flight": break
			game._physics_process(1.0/60.0)
		check(game.state in ["result","replay"],"hole %d actual tee shot settles"%[hole+1])
		check(game.ball_pos.is_finite(),"hole %d ball remains finite"%[hole+1])
	game.hole_index=0; game.start_hole()
	for heading in [0.0,0.7,-1.2,2.6]:
		game.aim=heading; game._align_golfer()
		for sample in range(91):
			var angle: float=lerpf(-2.25,2.25,float(sample)/90.0)
			game._pose_swing(angle)
			var shoe: Node3D=game.golfer.get_node("Shoe-1")
			var contact: Vector3=shoe.to_global(Vector3(0,-0.075,0.10))
			check(absf(contact.y-game.course.height_at(contact.x,contact.z))<0.025,"lead foot stays planted through swing")
			for limb in game.swing_parts:
				check(limb.global_transform.is_finite(),"swing transform remains finite")
			check(absf(game.swing_parts[6].mesh.height-1.16)<0.001,"shaft length preserved")
			for arm in range(2):
				check(game.swing_parts[arm*3].mesh.height<0.45 and game.swing_parts[arm*3+1].mesh.height<0.43,"anatomical arm reach preserved")
		game._pose_swing(0)
		check(game.swing_parts[7].global_position.distance_to(game.ball_pos)<0.001,"impact stays on ball for every heading")
	print("COURSE_SURFACE_TESTS: %d checks, %d failures; max boundary jump %.5f m"%[checks,failures,max_jump])
	game.free(); quit(1 if failures else 0)
