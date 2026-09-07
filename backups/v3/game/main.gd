extends Node3D

const Data = preload("res://game/data.gd")
const Course = preload("res://game/course.gd")
const Hud = preload("res://game/hud.gd")
const YARD: float = 0.9144
var course: Node3D
var camera: Camera3D
var hud: Control
var ball: MeshInstance3D
var golfer: Node3D
var marker: Node3D
var trajectory: MeshInstance3D
var audio: AudioStreamPlayer
var state: String = "menu"
var previous_state: String = "aim"
var player_count: int = 1
var mode: int = 0
var round_length: int = 3
var roster: Array = [0,1,2,3]
var active_slot: int = 0
var players: Array = []
var player_index: int = 0
var hole_index: int = 0
var club: int = 0
var spin: int = 0
var aim: float = 0.0
var wind := Vector2.ZERO
var velocity := Vector3.ZERO
var ball_pos := Vector3.ZERO
var shot_origin := Vector3.ZERO
var last_safe := Vector3.ZERO
var in_air: bool = false
var bounced: bool = false
var shot_time: float = 0.0
var total_time: float = 0.0
var result_time: float = 0.0
var result_title: String = ""
var result_detail: String = ""
var hole_message: String = ""
var last_shot: String = ""
var hole_done: bool = false
var skin_pot: int = 1
var help_open: bool = false
var overview: bool = false
var dragging: bool = false
var aiming_drag: bool = false
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var pull: float = 0.0
var peak_y: float = 0.0
var keyboard_charge: bool = false
var charge: float = 0.0
var shot_quality: float = 1.0
var shot_distance: float = 0.0
var trail: Array = []
var trail_tick: float = 0.0
var score_return: String = "aim"
var sound_enabled: bool = true
var qa_mode: bool = false
var qa_elapsed: float = 0.0
var qa_step: int = 0
const IMPACT_TIME: float = 0.85
var swing_elapsed: float = 0.0
var impact_pending: bool = false
var swing_parts: Array = []
var flight_gravity: float = 9.81

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("b5d4cf"))
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("78b4ba")
	sky_mat.sky_horizon_color=Color("f3edcc")
	sky_mat.ground_bottom_color=Color("66834b")
	sky_mat.ground_horizon_color=Color("d3dbc0")
	sky.sky_material=sky_mat
	env.background_mode=Environment.BG_SKY
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("a4cdd0")
	env.ambient_light_energy=0.38
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.fog_enabled=true
	env.fog_light_color=Color("a9c9bc")
	env.fog_density=0.00045
	world.environment=env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-32,-48,0)
	sun.light_color=Color("fff0cc")
	sun.light_energy=0.9
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=280
	sun.shadow_bias=0.03
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	course=Course.new(); add_child(course); course.build(0)
	camera=Camera3D.new(); camera.far=1500; camera.fov=58; add_child(camera); camera.current=true
	ball=course.sphere(Vector3.ZERO,0.17,Color("fffceb"),self)
	var bm: StandardMaterial3D = ball.material_override
	bm.emission_enabled=true; bm.emission=Color("e6e3cd"); bm.emission_energy_multiplier=0.18
	marker=Node3D.new(); add_child(marker)
	for i in range(16):
		var a: float=TAU*i/16.0
		course.sphere(Vector3(cos(a)*2.5,0,sin(a)*2.5),0.24,Color("f5d376"),marker)
	trajectory=MeshInstance3D.new(); add_child(trajectory)
	var tm:=StandardMaterial3D.new(); tm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; tm.albedo_color=Color("fff4c3"); trajectory.material_override=tm
	_build_golfer()
	var layer:=CanvasLayer.new(); add_child(layer)
	hud=Hud.new(); hud.game=self; layer.add_child(hud)
	audio=AudioStreamPlayer.new(); add_child(audio)
	ball_pos=course.tee; ball.position=ball_pos
	_update_camera(1.0,true)
	qa_mode="--qa" in OS.get_cmdline_user_args()
	if "--qa-play" in OS.get_cmdline_user_args(): start_round()
	if "--qa-green" in OS.get_cmdline_user_args():
		start_round(); ball_pos=course.pin+Vector3(0,0,9); ball_pos.y=course.height_at(ball_pos.x,ball_pos.z)+0.2; players[0].pos=ball_pos; _prepare_turn()
	if "--qa-flight" in OS.get_cmdline_user_args() or "--qa-swing" in OS.get_cmdline_user_args():
		start_round(); shoot(1.0)

func _build_golfer() -> void:
	if is_instance_valid(golfer): golfer.queue_free()
	swing_parts.clear()
	golfer=Node3D.new(); add_child(golfer)
	golfer.scale=Vector3.ONE*1.3
	var c:=Color(Data.GOLFERS[roster[player_index] if players.is_empty() else players[player_index].golfer][2])
	# Tailored proportions, articulated limbs and a forward address stance.
	var pants:=Color("496478"); var skin:=Color("c68f6c")
	for side in [-1,1]:
		var hip:=Vector3(side*0.17,1.15,0.04)
		var knee:=Vector3(side*0.23,0.64,-0.10)
		var ankle:=Vector3(side*0.29,0.16,0.02)
		_limb(hip,knee,0.14,0.115,pants,golfer)
		_limb(knee,ankle,0.115,0.075,pants,golfer)
		var shoe=course.sphere(ankle+Vector3(0,-0.04,-0.10),0.16,Color("f4eddc"),golfer); shoe.scale=Vector3(0.65,0.50,1.6)
		var sole=course.sphere(ankle+Vector3(0,-0.09,-0.10),0.16,Color("243c45"),golfer); sole.scale=Vector3(0.68,0.16,1.65)
	var torso:=Node3D.new(); torso.name="SwingTorso"; torso.position=Vector3(0,1.12,0); golfer.add_child(torso)
	var shirt=course.sphere(Vector3(0,0.36,-0.08),0.39,c,torso); shirt.scale=Vector3(0.80,1.12,0.54); shirt.rotation.x=-0.16
	course.cylinder(Vector3(0,0.015,0),0.275,0.065,Color("24343e"),-1,torso)
	_limb(Vector3(0,0.69,-0.14),Vector3(0,0.82,-0.18),0.09,0.08,skin,torso)
	var head=course.sphere(Vector3(0,0.94,-0.20),0.19,skin,torso); head.scale=Vector3(0.85,1.15,0.90)
	var cap=course.sphere(Vector3(0,1.07,-0.19),0.20,Color("faf3dd"),torso); cap.scale=Vector3(0.95,0.55,0.95)
	var brim=course.sphere(Vector3(0,1.055,-0.35),0.20,Color("faf3dd"),torso); brim.scale=Vector3(0.83,0.10,0.90)
	for side in [-1,1]:
		swing_parts.append(_limb(Vector3.ZERO,Vector3.UP,0.115,0.085,c,torso))
		swing_parts.append(_limb(Vector3.ZERO,Vector3.UP,0.075,0.052,skin,torso))
		swing_parts.append(course.sphere(Vector3.ZERO,0.065,Color("f5f2e4") if side==-1 else skin,torso))
	swing_parts.append(_limb(Vector3.ZERO,Vector3.UP,0.025,0.018,Color("cadce5"),torso))
	var clubhead=course.sphere(Vector3.ZERO,0.11,Color("1e3544"),torso); clubhead.scale=Vector3(1.35,0.65,0.8)
	swing_parts.append(clubhead)
	_pose_swing(0)

func _limb(a: Vector3,b: Vector3,r1: float,r2: float,col: Color,parent: Node3D) -> MeshInstance3D:
	var n=course.cylinder((a+b)*0.5,r1,a.distance_to(b),col,r2,parent)
	_place_limb(n,a,b)
	return n

func _place_limb(n: MeshInstance3D,a: Vector3,b: Vector3) -> void:
	n.position=(a+b)*0.5
	n.mesh.height=a.distance_to(b)
	var axis: Vector3=(b-a).normalized()
	var tangent: Vector3=Vector3.FORWARD.cross(axis).normalized()
	n.basis=Basis(tangent,axis,tangent.cross(axis).normalized())

func _pose_swing(angle: float) -> void:
	if swing_parts.size()!=8: return
	var pivot:=Vector3(0,0.55,-0.12)
	var rotation_basis:=Basis(Vector3.FORWARD,angle)
	for i in range(2):
		var side: float=-1.0 if i==0 else 1.0
		var shoulder:=Vector3(side*0.28,0.60,-0.06)
		var hand: Vector3=pivot+rotation_basis*(Vector3(side*0.055,0.01,-0.52)-pivot)
		var elbow: Vector3=shoulder.lerp(hand,0.52)+Vector3(side*0.13,-0.06,0.06)
		_place_limb(swing_parts[i*3],shoulder,elbow)
		_place_limb(swing_parts[i*3+1],elbow,hand)
		swing_parts[i*3+2].position=hand
	var grip: Vector3=pivot+rotation_basis*(Vector3(0,0.02,-0.53)-pivot)
	var head: Vector3=pivot+rotation_basis*(Vector3(0.44,-1.02,-0.75)-pivot)
	_place_limb(swing_parts[6],grip,head)
	swing_parts[7].position=head

func _align_golfer() -> void:
	# Feet run along the target line; the golfer faces across it toward the ball.
	golfer.rotation.y=-aim-PI/2
	var contact_local:=Vector3(0.44,0.10,-0.75)*1.3
	golfer.position=ball_pos-Basis(Vector3.UP,-aim-PI/2)*contact_local
	_pose_swing(0)

func start_round() -> void:
	players.clear(); hole_index=0; player_index=0; skin_pot=1; last_shot=""; help_open=false
	if mode==1 and player_count<2: player_count=2
	for i in range(player_count):
		players.append({"golfer":roster[i],"scores":[],"strokes":0,"pos":Vector3.ZERO,"done":false,"skins":0})
	start_hole()

func start_hole() -> void:
	course.build(hole_index)
	wind=Vector2(sin(hole_index*2.6+0.7),cos(hole_index*1.7))*float(3+hole_index%7)
	for p in players:
		p.strokes=0; p.pos=course.tee; p.done=false
	player_index=0; hole_done=false; overview=false; last_shot=""
	_prepare_turn()

func _prepare_turn() -> void:
	ball_pos=players[player_index].pos
	last_safe=ball_pos
	ball.position=ball_pos
	ball.visible=true
	var direction: Vector3=course.pin-ball_pos
	aim=atan2(direction.x,-direction.z)
	club=_recommended_club()
	spin=0; state="aim"; pull=0; charge=0; dragging=false; keyboard_charge=false
	trail.clear(); _draw_trail(); _build_golfer()
	impact_pending=false
	_align_golfer()
	_update_camera(1.0,true)
	_update_marker()

func distance_to_pin() -> float:
	return Vector2(ball_pos.x-course.pin.x,ball_pos.z-course.pin.z).length()/YARD

func _recommended_club() -> int:
	var dist: float=distance_to_pin()
	if course.lie_at(ball_pos)=="GREEN" or dist<10: return 13
	if course.lie_at(ball_pos)=="BUNKER" and dist<100: return 11
	for i in range(12,-1,-1):
		if Data.CLUBS[i][2]*lie_factor() >= dist*0.97: return i
	return 0

func lie_factor() -> float:
	match course.lie_at(ball_pos):
		"ROUGH": return 0.8
		"BUNKER": return 0.68 if club>=9 else 0.42
	return 1.0

func club_range() -> float:
	if club==13: return clampf(distance_to_pin()*1.7,6.0,35.0)
	return Data.CLUBS[club][2]

func aim_direction() -> Vector3:
	return Vector3(sin(aim),0,-cos(aim))

func _update_marker() -> void:
	if state=="aim": _align_golfer()
	var p: Vector3=ball_pos+aim_direction()*club_range()*YARD*(1.0 if club==13 else lie_factor())
	p.y=course.height_at(p.x,p.z)+0.45
	marker.position=p
	marker.scale=Vector3.ONE*(0.3 if club==13 else 1.0)

func change_club(delta: int) -> void:
	if state!="aim" or dragging: return
	club=clampi(club+delta,0,13); _update_marker()

func shoot(power: float, error: float=0.0) -> void:
	if state!="aim": return
	players[player_index].strokes+=1
	shot_origin=ball_pos; last_safe=ball_pos; trail.clear(); bounced=false; shot_time=0; shot_distance=0
	shot_quality=clampf(1.0-absf(error)*2,0,1)
	var shot_aim: float=aim+error*0.20
	var dir:=Vector3(sin(shot_aim),0,-cos(shot_aim))
	var distance: float=club_range()*YARD*clampf(power,0.015,1.08)
	if club==13:
		var friction: float=1.3 if course.lie_at(ball_pos)=="GREEN" else 3.0
		velocity=dir*sqrt(2.0*friction*distance)
		in_air=false
	else:
		distance*=lie_factor()
		# Time-of-flight envelope preserves stock carry while making the arc readable.
		# Gameplay calibration, not a full aerodynamic lift/drag solver.
		var hang: float=lerpf(6.0,4.4,float(club)/12.0)*sqrt(clampf(power,0.015,1.08))
		hang*=sqrt(lie_factor())*(1.0+spin*0.06)
		velocity=dir*(distance/hang)+Vector3.UP*(flight_gravity*hang*0.5)
		in_air=true
	state="flight"; dragging=false; keyboard_charge=false; overview=false
	swing_elapsed=0; impact_pending=true
	last_shot="%d%% POWER  ·  %s" % [int(power*100),"PURE" if absf(error)<0.1 else ("FADE" if error>0 else "DRAW")]

func _physics_process(delta: float) -> void:
	if state!="flight": return
	swing_elapsed+=delta
	var angle: float=0
	if swing_elapsed<0.55: angle=lerpf(0, -2.25,smoothstep(0,0.55,swing_elapsed))
	elif swing_elapsed<IMPACT_TIME: angle=lerpf(-2.25,0,pow((swing_elapsed-0.55)/0.30,2))
	else: angle=lerpf(0,2.45,smoothstep(IMPACT_TIME,1.50,swing_elapsed))
	_pose_swing(angle*(0.16 if club==13 else 1.0))
	if impact_pending:
		if swing_elapsed<IMPACT_TIME: return
		impact_pending=false
		_tone(430 if club==13 else 180,0.1,0.15)
	# Fixed substeps keep fast drives and cup crossings stable on slow frames.
	var dt: float=delta/4.0
	for sub in range(4):
		if state!="flight": break
		shot_time+=dt
		var old:=ball_pos
		var ground: float=course.height_at(ball_pos.x,ball_pos.z)+0.22
		if in_air:
			velocity.y-=flight_gravity*dt
			velocity.x+=wind.x*0.045*dt
			velocity.z+=wind.y*0.045*dt
			ball_pos+=velocity*dt
			ground=course.height_at(ball_pos.x,ball_pos.z)+0.22
			# Trunks and crowns deflect low shots; no invisible wall at the fairway edge.
			for tree in course.trees:
				if Vector2(ball_pos.x-tree.x,ball_pos.z-tree.z).length()<2.6 and absf(ball_pos.y-tree.y)<tree.y-course.height_at(tree.x,tree.z)+2:
					velocity.x*=-0.18; velocity.z*=-0.18; velocity.y=minf(velocity.y,0); break
			if ball_pos.y<=ground:
				ball_pos.y=ground
				var lie: String=course.lie_at(ball_pos)
				if lie in ["WATER","OUT OF BOUNDS"]: _penalty(lie); break
				if not bounced and club<9 and lie!="BUNKER" and absf(velocity.y)>5:
					velocity.y=absf(velocity.y)*0.16
					velocity.x*=0.32; velocity.z*=0.32; bounced=true
				else:
					velocity.y=0; velocity.x*=0.4 if bounced else 0.18; velocity.z*=0.4 if bounced else 0.18
					if club>=9: velocity*=0.5 if spin==1 else 1.0
					in_air=false
		else:
			var lie: String=course.lie_at(ball_pos)
			if lie in ["WATER","OUT OF BOUNDS"]: _penalty(lie); break
			var friction: float=1.3
			if lie=="ROUGH": friction=5.0
			elif lie=="BUNKER": friction=9.0
			elif lie!="GREEN": friction=2.8
			var gradient:=Vector3((course.height_at(ball_pos.x+0.3,ball_pos.z)-course.height_at(ball_pos.x-0.3,ball_pos.z))/0.6,0,(course.height_at(ball_pos.x,ball_pos.z+0.3)-course.height_at(ball_pos.x,ball_pos.z-0.3))/0.6)
			velocity-=gradient*9.81*dt*0.7
			velocity=velocity.move_toward(Vector3.ZERO,friction*dt)
			ball_pos+=velocity*dt
			ball_pos.y=course.height_at(ball_pos.x,ball_pos.z)+0.22
			var a:=Vector2(old.x,old.z); var b:=Vector2(ball_pos.x,ball_pos.z); var cup:=Vector2(course.pin.x,course.pin.z)
			var closest: Vector2=Geometry2D.get_closest_point_to_segment(cup,a,b)
			if closest.distance_to(cup)<0.65 and velocity.length()<5.0: _sink(); break
			if velocity.length()<0.13: _finish_shot(); break
		shot_distance=Vector2(ball_pos.x-shot_origin.x,ball_pos.z-shot_origin.z).length()/YARD
		if shot_time>30: _finish_shot(); break
	ball.position=ball_pos

func _penalty(reason: String) -> void:
	players[player_index].strokes+=1
	ball_pos=last_safe; ball.position=ball_pos
	_finish_shot(reason+" · +1 PENALTY", "Stroke and distance. Replay from your previous lie.")

func _sink() -> void:
	ball_pos=course.pin; ball.visible=false; velocity=Vector3.ZERO
	players[player_index].done=true
	result_title=Data.score_name(players[player_index].strokes,Data.HOLES[hole_index][1])
	result_detail="%s · %d strokes" % [Data.GOLFERS[players[player_index].golfer][0],players[player_index].strokes]
	state="result"; result_time=0
	_tone(880,0.35,0.15)

func _finish_shot(title: String="", detail: String="") -> void:
	velocity=Vector3.ZERO
	players[player_index].pos=ball_pos
	if players[player_index].strokes>=Data.HOLES[hole_index][1]+5:
		players[player_index].done=true
		title="PICKUP · BREAKFAST IS WAITING"
		detail="Maximum score: par + 5. On to the next hole."
	result_title=title if title!="" else ("ON THE DANCE FLOOR" if course.lie_at(ball_pos)=="GREEN" else "NICE & EASY" if shot_quality>0.8 else "THAT'LL PLAY")
	result_detail=detail if detail!="" else "%d yd traveled · %s · %s to the cup" % [int(shot_distance),course.lie_at(ball_pos).capitalize(),distance_text()]
	state="result"; result_time=0

func distance_text() -> String:
	var d: float=distance_to_pin()
	return "%.1f ft" % (d*3.0) if d<30 else "%d yd" % roundi(d)

func advance_turn() -> void:
	if state!="result": return
	var all_done: bool=true
	for p in players:
		if not p.done: all_done=false
	if all_done:
		var scores: Array=[]
		for p in players:
			p.scores.append(p.strokes); scores.append(p.strokes)
		var winner: int=Data.skin_winner(scores)
		hole_message="Hole complete. Fresh tee, fresh start."
		if mode==1:
			if winner>=0:
				players[winner].skins+=skin_pot
				hole_message="%s wins %d %s!" % [Data.GOLFERS[players[winner].golfer][0],skin_pot,"skin" if skin_pot==1 else "skins"]
				skin_pot=1
			else:
				skin_pot+=1
				hole_message="Tied hole. %d skins carry to the next." % skin_pot
				if hole_index==round_length-1: hole_message="Tied final hole. %d unclaimed skins expire; no playoff." % (skin_pot-1)
		hole_done=true; state="scorecard"
		return
	# Everyone tees off, then the player farthest from the hole plays next.
	var farthest: float=-1.0
	for i in range(players.size()):
		if players[i].done: continue
		var d: float=players[i].pos.distance_to(course.pin)
		if players[i].strokes==0: d+=10000
		if d>farthest: farthest=d; player_index=i
	_prepare_turn()

func next_hole() -> void:
	if not hole_done:
		state=score_return; return
	if hole_index+1>=round_length: state="finished"; return
	hole_index+=1; start_hole()

func total_score(i: int) -> int:
	var s: int=0
	for x in players[i].scores: s+=x
	return s

func relative_score(i: int) -> String:
	var par: int=0
	for h in range(players[i].scores.size()): par+=Data.HOLES[h][1]
	var d: int=total_score(i)-par
	return "E" if d==0 else "%+d" % d

func winners_text() -> String:
	var best: int=-999 if mode==1 else 999
	var names: Array=[]
	for i in range(players.size()):
		var score: int=players[i].skins if mode==1 else total_score(i)
		if (mode==1 and score>best) or (mode==0 and score<best): best=score; names=[Data.GOLFERS[players[i].golfer][0]]
		elif score==best: names.append(Data.GOLFERS[players[i].golfer][0])
	return (" & ".join(names))+ (" share the honors." if names.size()>1 else " takes the clubhouse!")

func _process(delta: float) -> void:
	total_time+=delta
	if state=="result": result_time+=delta
	if keyboard_charge and state=="aim": charge=clampf(charge+delta*0.55,0,1)
	if state=="aim" and not help_open:
		var axis: float=Input.get_axis("ui_left","ui_right")
		if axis!=0: aim+=axis*delta*0.55; _update_marker()
	_update_camera(delta)
	marker.visible=state=="aim" and not help_open
	golfer.visible=state in ["aim","flight","result"]
	if state=="flight":
		trail_tick+=delta
		if trail_tick>0.04:
			trail_tick=0; trail.append(ball_pos)
			if trail.size()>240: trail.pop_front()
			_draw_trail()
	hud.queue_redraw()
	if qa_mode:
		qa_elapsed+=delta
		if qa_elapsed>(0.5 if "--qa-swing" in OS.get_cmdline_user_args() else 3.0) and qa_step==0:
			qa_step=1
			get_viewport().get_texture().get_image().save_png("/private/tmp/breakfast-balls-qa.png")
			print("QA_SCREENSHOT_SAVED")
			print("QA_RENDER fps=%d draw_calls=%d objects=%d triangles=%d"%[Engine.get_frames_per_second(),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
			if "--qa-exit" in OS.get_cmdline_user_args(): get_tree().quit()

func _draw_trail() -> void:
	if trail.size()<2: trajectory.mesh=null; return
	var mesh:=ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in trail: mesh.surface_add_vertex(p)
	mesh.surface_end(); trajectory.mesh=mesh

func _update_camera(delta: float, instant: bool=false) -> void:
	var target: Vector3
	var pos: Vector3
	if state=="menu":
		target=course.ground_point(course.center_x(-course.length_m*0.7),-course.length_m*0.7,0)
		pos=target+Vector3(115+sin(total_time*0.035)*12,95,140)
	elif overview or state in ["scorecard","finished"]:
		target=course.ground_point(course.center_x(-course.length_m*0.5),-course.length_m*0.5,0)
		pos=target+Vector3(75,course.length_m*0.75,course.length_m*0.6)
	elif state=="flight" and swing_elapsed>1.65:
		target=ball_pos+aim_direction()*9
		pos=ball_pos-aim_direction()*28+Vector3(0,15,0)
	else:
		var putting: bool=club==13
		var focus: Vector3=shot_origin if state=="flight" else ball_pos
		target=focus+aim_direction()*(1 if putting else 3)
		target.y=course.height_at(target.x,target.z)+0.4
		pos=focus-aim_direction()*(10 if putting else 11)+Vector3(0,8 if putting else 3.3,0)
	var k: float=1.0 if instant else 1.0-exp(-delta*3.8)
	camera.position=camera.position.lerp(pos,k)
	if camera.position.distance_to(target)>0.1: camera.look_at(target,Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_H:
			help_open=not help_open; dragging=false; keyboard_charge=false; return
		if event.keycode==KEY_ESCAPE:
			if help_open: help_open=false
			elif state=="pause": state=previous_state
			elif state in ["aim","flight","result"]: previous_state=state; state="pause"; dragging=false; keyboard_charge=false
			return
		if event.keycode==KEY_ENTER:
			if state=="menu": start_round()
			elif state=="result": advance_turn()
			elif state=="scorecard": next_hole()
			return
		if state=="aim" and not help_open:
			if event.keycode==KEY_Q: change_club(-1)
			if event.keycode==KEY_E: change_club(1)
			if event.keycode==KEY_V: overview=not overview
			if event.keycode==KEY_S: spin=(spin+2)%3-1
			if event.keycode==KEY_TAB: score_return=state; state="scorecard"
			if event.keycode==KEY_SPACE: keyboard_charge=true; charge=0
	if event is InputEventKey and not event.pressed and event.keycode==KEY_SPACE and keyboard_charge:
		shoot(maxf(charge,0.04))
	if help_open or state!="aim": return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: change_club(-1)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: change_club(1)
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and hud.swing_rect.has_point(event.position):
				dragging=true; drag_start=event.position; drag_current=event.position; peak_y=event.position.y; pull=0
			elif event.pressed and event.position.y>106 and event.position.y<560 and event.position.x<1020:
				aiming_drag=true; drag_current=event.position
			elif not event.pressed:
				if dragging:
					var error: float=clampf((event.position.x-drag_start.x)/75.0,-1,1)
					if pull>0.06: shoot(pull,error)
					dragging=false
				aiming_drag=false
	if event is InputEventMouseMotion:
		if dragging:
			drag_current=event.position; peak_y=maxf(peak_y,event.position.y)
			pull=clampf((peak_y-drag_start.y)/92.0,0,1)
		elif aiming_drag:
			aim+=(event.position.x-drag_current.x)*0.004; drag_current=event.position; _update_marker()

func _tone(freq: float, seconds: float, loudness: float) -> void:
	if not sound_enabled: return
	var stream:=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050
	var bytes:=PackedByteArray(); bytes.resize(int(seconds*22050)*2)
	for i in range(bytes.size()/2):
		var t: float=float(i)/22050.0
		var value: int=int(sin(t*TAU*freq)*exp(-t*14)*loudness*32767)
		bytes.encode_s16(i*2,value)
	stream.data=bytes; audio.stream=stream; audio.play()
