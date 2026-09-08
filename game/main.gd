extends Node3D

const Data = preload("res://game/data.gd")
const Course = preload("res://game/course.gd")
const Hud = preload("res://game/hud.gd")
const Character=preload("res://game/character.gd")
const YARD: float = 0.9144
var course: Node3D
var camera: Camera3D
var hud: Control
var ball: MeshInstance3D
var golfer: Node3D
var marker: Node3D
var trajectory: MeshInstance3D
var audio: AudioStreamPlayer
var music: AudioStreamPlayer
var state: String = "menu"
var previous_state: String = "aim"
var player_count: int = 1
var mode: int = 0
const CLOSEST_TO_PIN: int = 2
const CHALLENGE_HOLES: Array = [5,11,15]
var breakfast_offer: bool = false
var pending_shot_records: Array = []
var breakfast_flash: float = 0.0
var round_length: int = 3
var nine_side: int = 0
var round_holes: Array = []
var round_position: int = 0
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
var swing_clock: float = 0.0
var path_offset: float = 0.0
var curve_rate: float = 0.0
var shot_shape: String = "STRAIGHT"
var phrase_counts: Dictionary = {}
var full_power_hold: float = 0.0
var tree_hits: Dictionary = {}
var player_tags: Array=["TOMMY","BIRDY","SLICE","BACON"]
var name_entry_index: int=0
var name_entry_value: String=""
var leaderboard: Dictionary={}
var records_enabled: bool=true
var record_notice: String=""
var replay_path: Array=[]
var replay_time: float=0.0
var replay_duration: float=3.8
var replay_title: String=""
var replay_end_position:=Vector3.ZERO
var replay_return_state: String="result"
var remote_timing_enabled: bool=false
var timing_offsets: Array=[0.0,0.0,0.0,0.0]
var calibration_player: int=1
var calibration_samples: Array=[]
var calibration_clock: float=0.0
const CALIBRATION_CENTER: float=0.8
const CALIBRATION_DURATION: float=1.6
const MAX_TIMING_OFFSET: float=0.35
var parsec_setup_open: bool=false
var parsec_status: String="FREE REMOTE PLAY · HOST SHARES FROM PARSEC"

var leaderboard_path: String="user://leaderboard.json"

func swing_power() -> float:
	return charge if keyboard_charge else minf(1.6,maxf(pull+full_power_hold*0.4,swing_clock*0.55))

func _default_leaderboard() -> Dictionary:
	return {
		"hole_in_ones":{"value":0,"name":"-----","detail":"No aces recorded","by_name":{}},
		"longest_drive":{"value":0.0,"name":"-----","detail":"No drive recorded"},
		"front_nine":{"value":999,"name":"-----","detail":"No front nine recorded"},
		"back_nine":{"value":999,"name":"-----","detail":"No back nine recorded"},
		"course_total":{"value":999,"name":"-----","detail":"No full round recorded"},
		"last_tags":["TOMMY","BIRDY","SLICE","BACON"]
	}

func _load_leaderboard() -> void:
	leaderboard=_default_leaderboard()
	if FileAccess.file_exists(leaderboard_path):
		var file:=FileAccess.open(leaderboard_path,FileAccess.READ)
		if file:
			var parsed=JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for key in parsed: leaderboard[key]=parsed[key]
	var saved: Array=leaderboard.get("last_tags",player_tags)
	for i in range(mini(saved.size(),player_tags.size())): player_tags[i]=str(saved[i]).to_upper().left(5)

func _save_leaderboard() -> void:
	leaderboard["last_tags"]=player_tags.duplicate()
	var file:=FileAccess.open(leaderboard_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(leaderboard,"  "))

func begin_name_entry() -> void:
	timing_offsets=[0.0,0.0,0.0,0.0]
	name_entry_index=0
	name_entry_value=str(player_tags[0]).to_upper().left(5)
	state="name_entry"

func _accept_name_entry() -> void:
	if name_entry_value.length()!=5: return
	player_tags[name_entry_index]=name_entry_value
	name_entry_index+=1
	if name_entry_index>=player_count:
		_save_leaderboard()
		if remote_timing_enabled and player_count>1: begin_calibration()
		else: start_round()
	else:
		name_entry_value=str(player_tags[name_entry_index]).to_upper().left(5)

func begin_calibration() -> void:
	calibration_player=1
	calibration_samples.clear()
	calibration_clock=0.0
	state="calibration"

func calibration_meter() -> float:
	var progress: float=clampf(calibration_clock/CALIBRATION_DURATION,0.0,1.0)
	return lerpf(-0.85,0.85,smoothstep(0.0,1.0,progress))

func record_calibration_sample() -> void:
	if state!="calibration" or calibration_clock<CALIBRATION_CENTER: return
	calibration_samples.append(clampf(calibration_clock-CALIBRATION_CENTER,0.0,MAX_TIMING_OFFSET))
	if calibration_samples.size()<3:
		calibration_clock=0.0
		return
	calibration_samples.sort()
	timing_offsets[calibration_player]=float(calibration_samples[1])
	calibration_player+=1
	calibration_samples.clear()
	calibration_clock=0.0
	if calibration_player>=player_count: start_round()

func player_timing_offset(index: int=player_index) -> float:
	if not remote_timing_enabled or index<=0 or index>=timing_offsets.size(): return 0.0
	return float(timing_offsets[index])

func evaluated_face_meter() -> float:
	return sin((swing_clock-player_timing_offset())*5.6*contact_difficulty())*0.85

func open_parsec() -> void:
	if OS.get_name()=="macOS" and DirAccess.dir_exists_absolute("/Applications/Parsec.app"):
		var process_id: int=OS.create_process("/usr/bin/open",["-a","Parsec"])
		parsec_status="PARSEC OPENED · SHARE THIS COMPUTER" if process_id>=0 else "Open Parsec from Applications"
	else:
		OS.shell_open("https://parsec.app/downloads")
		parsec_status="INSTALL OR OPEN PARSEC · THEN SHARE THIS COMPUTER"

func _record(key: String,value: float,lower_is_better: bool,tag: String,detail: String) -> bool:
	if not records_enabled or mode==CLOSEST_TO_PIN: return false
	if key=="longest_drive" and not players.is_empty() and players[player_index].breakfast_used: return false
	var old: float=float(leaderboard[key]["value"])
	if (lower_is_better and value>=old) or (not lower_is_better and value<=old): return false
	if breakfast_offer and key=="longest_drive":
		pending_shot_records.append([key,value,lower_is_better,tag,detail])
		return true
	leaderboard[key]={"value":value,"name":tag,"detail":detail}
	record_notice="NEW CLUB RECORD · %s"%detail.to_upper()
	_save_leaderboard()
	return true

func _count_hole_in_one(tag: String) -> void:
	if not records_enabled or mode==CLOSEST_TO_PIN: return
	if not players.is_empty() and players[player_index].breakfast_used: return
	if breakfast_offer:
		pending_shot_records.append(["ace",tag])
		return
	var record: Dictionary=leaderboard.get("hole_in_ones",_default_leaderboard()["hole_in_ones"])
	var by_name: Dictionary=record.get("by_name",{})
	by_name[tag]=int(by_name.get(tag,0))+1
	var total: int=int(record.get("value",0))+1
	leaderboard["hole_in_ones"]={"value":total,"name":tag,"detail":"%s · %d career ace%s"%[tag,by_name[tag],"" if by_name[tag]==1 else "s"],"by_name":by_name}
	record_notice="ACE #%d IN THE LOCAL RECORD BOOK · %s"%[total,tag]
	_save_leaderboard()

func _start_music() -> void:
	# The retained cue is mono, 16-bit PCM at 22.05 kHz. Reading it directly keeps
	# development copies independent of editor-generated import caches.
	var file:=FileAccess.open("res://game/assets/audio/magnolia_morning.wav",FileAccess.READ)
	if not file: return
	var bytes:=file.get_buffer(file.get_length())
	if bytes.size()<=44: return
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	stream.stereo=false
	stream.data=bytes.slice(44)
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=stream.data.size()/2
	music.stream=stream
	if sound_enabled: music.play()

func toggle_sound() -> void:
	sound_enabled=not sound_enabled
	if sound_enabled:
		if music.stream and not music.playing: music.play()
	else:
		music.stop(); audio.stop()

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
	music=AudioStreamPlayer.new(); music.name="CourseMusic"; music.volume_db=-21.0; add_child(music)
	_load_leaderboard()
	_start_music()
	ball_pos=course.tee; ball.position=ball_pos
	_update_camera(1.0,true)
	qa_mode="--qa" in OS.get_cmdline_user_args()
	if "--qa-play" in OS.get_cmdline_user_args(): start_round()
	if "--qa-green" in OS.get_cmdline_user_args():
		start_round(); ball_pos=course.pin+Vector3(0,0,9); ball_pos.y=course.height_at(ball_pos.x,ball_pos.z)+0.2; players[0].pos=ball_pos; _prepare_turn()
	if "--qa-flight" in OS.get_cmdline_user_args() or "--qa-swing" in OS.get_cmdline_user_args() or "--qa-followthrough" in OS.get_cmdline_user_args():
		start_round(); shoot(1.0)
	if "--qa-water" in OS.get_cmdline_user_args():
		round_length=18; start_round(); round_position=12; hole_index=12; start_hole()
		players[0].pos=course.ground_point(course.pin.x,course.pin.z+60,0.22); _prepare_turn()
	if "--qa-name" in OS.get_cmdline_user_args(): begin_name_entry()
	if "--qa-board" in OS.get_cmdline_user_args(): state="leaderboard"
	if "--qa-parsec" in OS.get_cmdline_user_args(): parsec_setup_open=true
	if "--qa-calibration" in OS.get_cmdline_user_args():
		remote_timing_enabled=true; player_count=2; begin_calibration(); calibration_clock=CALIBRATION_CENTER
	if "--qa-replay" in OS.get_cmdline_user_args():
		start_round(); replay_path.clear()
		for i in range(80):
			var t: float=float(i)/79.0
			var p: Vector3=course.tee.lerp(course.pin,t)
			p.y=course.height_at(p.x,p.z)+0.25+sin(t*PI)*42.0
			replay_path.append(p)
		ball_pos=replay_path[-1]; trail=replay_path.duplicate(); _begin_replay("HOLE IN ONE")

func _build_golfer() -> void:
	if is_instance_valid(golfer): golfer.queue_free()
	swing_parts.clear()
	golfer=Node3D.new(); add_child(golfer)
	golfer.scale=Vector3.ONE*1.3
	var identity: int=roster[player_index] if players.is_empty() else players[player_index].golfer
	var c:=Color(Data.GOLFERS[identity][2])
	# Tailored proportions, articulated limbs and a forward address stance.
	var pants:=Color("496478"); var skin:=Color(Character.SKIN[identity])
	var pelvis=course.mesh_node(course._mesh_from_scene("res://game/assets/models/golfer_pelvis.glb"),course.material(pants),Vector3(0,1.08,0.035),golfer)
	pelvis.name="Pelvis"
	pelvis.scale.x*=Character.BUILD[identity]
	for side in [-1,1]:
		var hip:=Vector3(side*0.17,1.15,0.04)
		var knee:=Vector3(side*0.23,0.64,-0.10)
		var ankle:=Vector3(side*0.29,0.16,0.02)
		var thigh=_limb(hip,knee,0.14,0.115,pants,golfer); thigh.name="Thigh%d"%side
		var shin=_limb(knee,ankle,0.115,0.075,pants,golfer); shin.name="Shin%d"%side
		var knee_joint=course.sphere(knee,0.12,pants.darkened(0.035),golfer)
		knee_joint.name="Knee%d"%side
		knee_joint.scale=Vector3(0.92,0.78,0.92)
		var shoe=course.mesh_node(course._mesh_from_scene("res://game/assets/models/golfer_shoe.glb"),course.material(Color("f4eddc")),ankle+Vector3(0,-0.04,-0.10),golfer)
		shoe.name="Shoe%d"%side
		var sole=course.mesh_node(shoe.mesh,course.material(Color("243c45")),ankle+Vector3(0,-0.10,-0.10),golfer)
		sole.scale=Vector3(1.015,0.20,1.015); sole.name="Sole%d"%side
	var torso:=Node3D.new(); torso.name="SwingTorso"; torso.position=Vector3(0,1.12,0); golfer.add_child(torso)
	var shirt=course.mesh_node(course._mesh_from_scene("res://game/assets/models/golfer_polo.glb"),course.material(c),Vector3(0,0.36,-0.08),torso); shirt.rotation.x=-0.16
	shirt.scale.x*=Character.BUILD[identity]
	var belt=course.cylinder(Vector3(0,0.10,0),0.255,0.055,Color("24343e"),-1,pelvis)
	belt.scale.z=0.70
	var buckle:=BoxMesh.new(); buckle.size=Vector3(0.08,0.055,0.025)
	course.mesh_node(buckle,course.material(Color("b8b7a3"),0.3),Vector3(0,0.10,-0.18),pelvis)
	var neck=course.cylinder(Vector3(0,0.77,-0.16),0.085,0.19,skin,0.072,torso)
	neck.rotation.x=-0.10
	# Shoulder caps make the arms read as attached anatomy at gameplay distance.
	for side in [-1,1]:
		var shoulder=course.sphere(Vector3(side*0.31,0.57,-0.08),0.135,c,torso)
		shoulder.scale=Vector3(0.72,0.82,0.88)
	Character.face(course,torso,identity)
	Character.tailoring(course,torso,c)
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
	var pole: Vector3=Vector3.FORWARD if absf(axis.z)<0.95 else Vector3.RIGHT
	var tangent: Vector3=pole.cross(axis).normalized()
	n.basis=Basis(tangent,axis,tangent.cross(axis).normalized())

func _pose_swing(angle: float) -> void:
	if swing_parts.size()!=8: return
	var phase: float=clampf(absf(angle)/2.25,0,1)
	var back: bool=angle<0
	var finish: float=0.0 if back else smoothstep(0.0,1.0,phase)
	var coil: float=phase if back else 0.0
	var shift:=Vector3(0.055*coil-0.12*finish,0.015*coil+0.055*finish,0.0)
	var hip_turn: float=-0.34*coil+0.78*finish
	var pelvis: Node3D=golfer.get_node("Pelvis")
	pelvis.position=Vector3(0,1.08,0.035)+shift
	pelvis.rotation.y=hip_turn
	var torso: Node3D=golfer.get_node("SwingTorso")
	torso.position=Vector3(0,1.12,0)+shift
	torso.rotation=Vector3(-0.32+0.25*finish,-0.90*coil+1.15*finish,0.04*coil-0.06*finish)
	# Hold the eyes on the ball through impact, then track it down the target line.
	var face: Node3D=torso.get_node("HeadPivot")
	face.rotation=Vector3(0.10*coil,-torso.rotation.y*(0.85 if back else 0.0)+0.35*finish,0.0)
	for side in [-1,1]:
		var trail: bool=side==1
		var heel: float=0.22*sin(0.62*finish) if trail else 0.0
		var hip: Vector3=Vector3(side*0.17,1.15,0.04)+shift
		hip=pelvis.position+Basis(Vector3.UP,hip_turn)*(hip-pelvis.position)
		var foot_world: Vector3=golfer.to_global(Vector3(side*0.29,0,0.02))
		var ground_y: float=golfer.to_local(course.ground_point(foot_world.x,foot_world.z)).y
		var ankle:=Vector3(side*0.29,ground_y+0.115+heel,0.02)
		var knee:=Vector3(side*0.23-0.10*finish,0.64+0.07*finish,-0.10-0.07*coil)
		if trail: knee.x-=0.10*finish; knee.z-=0.08*finish
		_place_limb(golfer.get_node("Thigh%d"%side),hip,knee)
		_place_limb(golfer.get_node("Shin%d"%side),knee,ankle)
		golfer.get_node("Knee%d"%side).position=knee
		var shoe: Node3D=golfer.get_node("Shoe%d"%side)
		shoe.position=ankle+Vector3(0,-0.04,-0.10)
		shoe.rotation=Vector3(-0.62*finish if trail else 0.0,0.28*finish if trail else 0.10*finish,0.0)
		var sole: Node3D=golfer.get_node("Sole%d"%side)
		sole.position=shoe.position+shoe.basis*Vector3(0,-0.06,0)
		sole.rotation=shoe.rotation
	var grip:=Vector3(0,1.00,-0.42)
	var club_dir:=Vector3(0.10,-0.90,-0.66).normalized()
	if back:
		if phase<0.48:
			var t: float=smoothstep(0,0.48,phase)
			grip=grip.lerp(Vector3(0.46,1.27,-0.40),t)
			club_dir=club_dir.slerp(Vector3(1.0,0.10,-0.15).normalized(),t)
		else:
			var t: float=smoothstep(0.48,1.0,phase)
			grip=Vector3(0.46,1.27,-0.40).lerp(Vector3(0.48,2.02,0.02),t)
			club_dir=Vector3(1.0,0.10,-0.15).normalized().slerp(Vector3(-0.92,0.15,0.35).normalized(),t)
	elif phase>0:
		if phase<0.50:
			var t: float=smoothstep(0,0.50,phase)
			grip=grip.lerp(Vector3(-0.52,1.45,-0.42),t)
			club_dir=club_dir.slerp(Vector3(-0.95,0.18,-0.15).normalized(),t)
		else:
			var t: float=smoothstep(0.50,1.0,phase)
			grip=Vector3(-0.52,1.45,-0.42).lerp(Vector3(-0.32,2.00,0.15),t)
			club_dir=Vector3(-0.95,0.18,-0.15).normalized().slerp(Vector3(0.65,0.65,0.40).normalized(),t)
	# Both hands share a grip; constrain it to the intersection of arm reach spheres.
	if phase>0.001:
		for iteration in range(3):
			for side in [-1,1]:
				var shoulder: Vector3=torso.transform*Vector3(side*0.28,0.60,-0.06)
				var delta: Vector3=grip-shoulder
				if delta.length()>0.80: grip=shoulder+delta.normalized()*0.80
	var inv: Transform3D=torso.transform.affine_inverse()
	for i in range(2):
		var side: float=-1.0 if i==0 else 1.0
		var shoulder:=Vector3(side*0.28,0.60,-0.06)
		var hand: Vector3=inv*(grip+club_dir*side*0.027)
		var delta: Vector3=hand-shoulder
		var distance: float=maxf(0.001,delta.length())
		var axis: Vector3=delta/distance
		var pole:=Vector3(side*0.75,-0.10,0.60)
		var bend_dir: Vector3=(pole-axis*pole.dot(axis)).normalized()
		var upper: float=0.43; var forearm: float=0.40
		var along: float=(upper*upper-forearm*forearm+distance*distance)/(2.0*distance)
		var elbow: Vector3=shoulder+axis*along+bend_dir*sqrt(maxf(0.0001,upper*upper-along*along))
		_place_limb(swing_parts[i*3],shoulder,elbow)
		_place_limb(swing_parts[i*3+1],elbow,hand)
		swing_parts[i*3+2].position=hand
	var head: Vector3=grip+club_dir*1.16
	_place_limb(swing_parts[6],inv*grip,inv*head)
	swing_parts[7].position=inv*head

func _align_golfer() -> void:
	# Feet run along the target line; the golfer faces across it toward the ball.
	golfer.rotation.y=-aim-PI/2
	var contact_local: Vector3=(Vector3(0,1.00,-0.42)+Vector3(0.10,-0.90,-0.66).normalized()*1.16)*1.3
	golfer.position=ball_pos-Basis(Vector3.UP,-aim-PI/2)*contact_local
	_pose_swing(0)

func start_round() -> void:
	players.clear(); hole_index=0; player_index=0; skin_pot=1; last_shot=""; help_open=false; record_notice=""
	breakfast_offer=false; pending_shot_records.clear(); breakfast_flash=0.0
	if mode==CLOSEST_TO_PIN: round_length=3
	round_holes=CHALLENGE_HOLES.duplicate() if mode==CLOSEST_TO_PIN else select_round_holes(round_length,nine_side)
	round_position=0; hole_index=round_holes[0]
	if mode==1 and player_count<2: player_count=2
	for i in range(player_count):
		players.append({"golfer":roster[i],"tag":player_tags[i],"scores":[],"strokes":0,"pos":Vector3.ZERO,"done":false,"skins":0,"breakfast_used":false,"challenge_results":[],"challenge_shot":{}})
	start_hole()

func select_round_holes(count: int,side: int) -> Array:
	var holes: Array=[]
	if count==9:
		for i in range(9): holes.append(i+side*9)
	else:
		for i in range(18): holes.append(i)
		if count==3: holes.shuffle(); holes=holes.slice(0,3)
	return holes

func start_hole() -> void:
	breakfast_offer=false; pending_shot_records.clear()
	course.build(hole_index)
	wind=Vector2(sin(hole_index*2.6+0.7),cos(hole_index*1.7))*float(3+hole_index%7)
	for p in players:
		p.strokes=0; p.pos=course.tee; p.done=false; p.challenge_shot={}
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
		"FIRST CUT": return 0.92
		"SECOND CUT": return 0.8
		"BUNKER": return 0.68 if club>=9 else 0.42
	return 1.0

func club_range() -> float:
	if club==13: return clampf(distance_to_pin()*1.7,6.0,35.0)
	return Data.CLUBS[club][2]

func roll_resistance(lie: String) -> float:
	match lie:
		"GREEN": return 1.3
		"FIRST CUT": return 3.5
		"SECOND CUT": return 5.0
		"BUNKER": return 9.0
	return 2.8

func putt_launch_speed(distance: float,direction: Vector3) -> float:
	# Power describes intended roll distance, not a starting-lie-only impulse.
	# Integrate the same resistance used by rolling physics along the aimed path.
	var steps: int=maxi(1,ceili(distance/0.20))
	var ds: float=distance/steps
	var energy: float=0.0
	var required: float=0.0
	var previous_height: float=course.height_at(ball_pos.x,ball_pos.z)
	for i in range(steps):
		var midpoint: Vector3=ball_pos+direction*((i+0.5)*ds)
		var endpoint: Vector3=ball_pos+direction*((i+1)*ds)
		var height: float=course.height_at(endpoint.x,endpoint.z)
		energy+=roll_resistance(course.lie_at(midpoint))*ds+9.81*0.7*(height-previous_height)
		required=maxf(required,energy)
		previous_height=height
	return sqrt(2.0*maxf(0.01,required))

func contact_difficulty() -> float:
	match course.lie_at(ball_pos):
		"FIRST CUT": return 1.25
		"SECOND CUT": return 1.60
		"BUNKER": return 1.90
	return 1.0

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

func shoot(power: float, error: float=0.0, path: float=0.0) -> void:
	if state!="aim": return
	breakfast_offer=mode!=CLOSEST_TO_PIN and round_position==0 and players[player_index].strokes==0 and not players[player_index].breakfast_used and ball_pos.distance_to(course.tee)<0.5
	pending_shot_records.clear()
	record_notice=""
	var requested_power: float=power
	var excess: float=clampf(power-1.0,0,0.6)
	power=minf(power,1.0)*(1.0-excess*0.65)
	error=clampf(error+excess*(0.6+0.4*sin((swing_clock-player_timing_offset())*9.0)),-1,1)
	tree_hits.clear()
	players[player_index].strokes+=1
	shot_origin=ball_pos; last_safe=ball_pos; trail.clear(); trail.append(shot_origin); bounced=false; shot_time=0; shot_distance=0
	shot_quality=clampf(1.0-absf(error)*2,0,1)
	var shot_aim: float=aim+error*0.14+path*0.045
	curve_rate=(error-path)*0.065 if club!=13 else 0.0
	shot_shape=shape_name(error,path)
	var dir:=Vector3(sin(shot_aim),0,-cos(shot_aim))
	var distance: float=club_range()*YARD*clampf(power,0.015,1.08)
	if club==13:
		velocity=dir*putt_launch_speed(distance,dir)
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
	last_shot="%d%% POWER  ·  %s" % [int(power*100),shot_shape]
	if excess>0: last_shot="OVERSWING %d%% · %d%% CONTACT · %s"%[roundi(requested_power*100),roundi(power*100),shot_shape]

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
			var horizontal:=Vector3(velocity.x,0,velocity.z).rotated(Vector3.UP,-curve_rate*dt)
			velocity.x=horizontal.x; velocity.z=horizontal.z
			velocity.y-=flight_gravity*dt
			velocity.x+=wind.x*0.045*dt
			velocity.z+=wind.y*0.045*dt
			ball_pos+=velocity*dt
			ground=course.height_at(ball_pos.x,ball_pos.z)+0.22
			_resolve_trees(old)
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
			var friction: float=roll_resistance(lie)
			var gradient:=Vector3((course.height_at(ball_pos.x+0.3,ball_pos.z)-course.height_at(ball_pos.x-0.3,ball_pos.z))/0.6,0,(course.height_at(ball_pos.x,ball_pos.z+0.3)-course.height_at(ball_pos.x,ball_pos.z-0.3))/0.6)
			velocity-=gradient*9.81*dt*0.7
			velocity=velocity.move_toward(Vector3.ZERO,friction*dt)
			ball_pos+=velocity*dt
			ball_pos.y=course.height_at(ball_pos.x,ball_pos.z)+0.22
			_resolve_trees(old)
			var a:=Vector2(old.x,old.z); var b:=Vector2(ball_pos.x,ball_pos.z); var cup:=Vector2(course.pin.x,course.pin.z)
			var closest: Vector2=Geometry2D.get_closest_point_to_segment(cup,a,b)
			if closest.distance_to(cup)<0.65 and velocity.length()<5.0: _sink(); break
			if velocity.length()<0.13: _finish_shot(); break
		shot_distance=Vector2(ball_pos.x-shot_origin.x,ball_pos.z-shot_origin.z).length()/YARD
		if shot_time>30: _finish_shot(); break
	ball.position=ball_pos

func _resolve_trees(old: Vector3) -> void:
	for i in range(course.trees.size()):
		var tree: Vector3=course.trees[i]
		var base: float=course.height_at(tree.x,tree.z)
		var height: float=(tree.y-base)*2.0
		var center:=Vector2(tree.x,tree.z)
		var a:=Vector2(old.x,old.z); var b:=Vector2(ball_pos.x,ball_pos.z)
		if ball_pos.y>base+height or ball_pos.y<base: continue
		if ball_pos.y>base+height*0.48:
			if b.distance_to(center)<3.5 and not tree_hits.has(i):
				velocity*=0.72; tree_hits[i]=true
			continue
		# Swept trunk collision, including an escape path from an overlapping lie.
		var radius: float=0.52
		var nearest: Vector2=Geometry2D.get_closest_point_to_segment(center,a,b)
		if nearest.distance_to(center)>=radius: continue
		var direction: Vector2=b-a
		var contact: Vector2=a
		if a.distance_to(center)>=radius and direction.length_squared()>0.000001:
			var offset: Vector2=a-center
			var qa: float=direction.length_squared(); var qb: float=2*offset.dot(direction)
			var qc: float=offset.length_squared()-radius*radius
			var t: float=(-qb-sqrt(maxf(0,qb*qb-4*qa*qc)))/(2*qa)
			contact=a+direction*clampf(t,0,1)
		var normal: Vector2=(contact-center).normalized()
		if normal.length_squared()<0.1: normal=direction.normalized() if direction.length_squared()>0 else Vector2.RIGHT
		var horizontal:=Vector2(velocity.x,velocity.z)
		if horizontal.dot(normal)<0: horizontal=horizontal.bounce(normal)*0.45
		velocity.x=horizontal.x; velocity.z=horizontal.y
		if b.distance_to(center)<radius or horizontal.dot(normal)>=0:
			var separated: Vector2=center+normal*(radius+0.025)
			# Keep already-outward travel instead of dragging it back into the trunk.
			if a.distance_to(center)<radius and (b-center).dot(normal)>radius: separated=b
			ball_pos.x=separated.x; ball_pos.z=separated.y

func _penalty(reason: String) -> void:
	if mode==CLOSEST_TO_PIN:
		_finish_challenge_shot(false,reason)
		return
	players[player_index].strokes+=1
	ball_pos=last_safe; ball.position=ball_pos
	_finish_shot(reason+" · +1 PENALTY", shot_comment("PENALTY")+" · Replay from your previous lie.")

func _sink() -> void:
	ball_pos=course.pin; ball.visible=false; velocity=Vector3.ZERO
	if mode==CLOSEST_TO_PIN:
		_finish_challenge_shot(true)
		_tone(880,0.35,0.15)
		_begin_replay("BULLSEYE · 100 POINTS")
		return
	players[player_index].done=true
	result_title=Data.score_name(players[player_index].strokes,Data.HOLES[hole_index][1])
	result_detail="%d strokes · %s" % [players[player_index].strokes,shot_comment("HOLED")]
	state="result"; result_time=0; trail.append(ball_pos)
	_tone(880,0.35,0.15)
	var par: int=Data.HOLES[hole_index][1]
	var origin_yards: float=Vector2(shot_origin.x-course.pin.x,shot_origin.z-course.pin.z).length()/YARD
	var reason: String=""
	if players[player_index].strokes==1:
		_count_hole_in_one(players[player_index].tag)
		reason="HOLE IN ONE"
	elif players[player_index].strokes<=par-2: reason="EAGLE FROM %d YARDS"%roundi(origin_yards)
	elif origin_yards>=28: reason="HOLED FROM %d YARDS"%roundi(origin_yards)
	elif club==13 and origin_yards>=9: reason="DRAINED A %d-FOOT PUTT"%roundi(origin_yards*3.0)
	if reason!="": _begin_replay(reason)

func _finish_shot(title: String="", detail: String="") -> void:
	if mode==CLOSEST_TO_PIN:
		_finish_challenge_shot()
		return
	velocity=Vector3.ZERO
	players[player_index].pos=ball_pos
	if players[player_index].strokes>=Data.HOLES[hole_index][1]+5:
		players[player_index].done=true
		title="PICKUP · BREAKFAST IS WAITING"
		detail="Maximum score: par + 5. On to the next hole."
	result_title=title if title!="" else shot_comment()
	result_detail=detail if detail!="" else "%d yd traveled · %s · %s to the cup" % [int(shot_distance),course.lie_at(ball_pos).capitalize(),distance_text()]
	state="result"; result_time=0
	var great: String=""
	if title=="" and club==0 and players[player_index].strokes==1 and course.lie_at(ball_pos) in ["FAIRWAY","FIRST CUT"]:
		if _record("longest_drive",shot_distance,false,players[player_index].tag,"%d yd drive"%roundi(shot_distance)):
			great="NEW LONGEST DRIVE · %d YARDS"%roundi(shot_distance)
		elif shot_distance>=285: great="ABSOLUTELY CRUSHED · %d YARDS"%roundi(shot_distance)
	var origin_yards: float=Vector2(shot_origin.x-course.pin.x,shot_origin.z-course.pin.z).length()/YARD
	if title=="" and great=="" and origin_yards>=80 and distance_to_pin()<=3.0: great="DART TO %.1f FEET"%(distance_to_pin()*3.0)
	if great!="": _begin_replay(great)

func _begin_replay(reason: String) -> void:
	if trail.size()<5 or (qa_mode and not "--qa-replay" in OS.get_cmdline_user_args()): return
	replay_path=trail.duplicate()
	replay_path.append(ball_pos)
	replay_end_position=ball_pos
	replay_time=0.0
	replay_duration=clampf(replay_path.size()*0.022,2.8,5.5)
	replay_title=reason
	replay_return_state="result"
	ball.visible=true
	state="replay"
	trail=replay_path.duplicate()
	_draw_trail()

func _check_round_records() -> void:
	if mode==CLOSEST_TO_PIN: return
	for i in range(players.size()):
		if players[i].breakfast_used: continue
		var scores: Array=players[i].scores
		var tag: String=players[i].tag
		if scores.size()==9 and ((round_length==9 and nine_side==0) or round_length==18):
			var total: int=0
			for score in scores: total+=score
			_record("front_nine",total,true,tag,"front nine · %d"%total)
		if scores.size()==9 and round_length==9 and nine_side==1:
			var total: int=0
			for score in scores: total+=score
			_record("back_nine",total,true,tag,"back nine · %d"%total)
		if scores.size()==18 and round_length==18:
			var front: int=0; var back: int=0
			for h in range(9): front+=scores[h]
			for h in range(9,18): back+=scores[h]
			_record("front_nine",front,true,tag,"front nine · %d"%front)
			_record("back_nine",back,true,tag,"back nine · %d"%back)
			_record("course_total",front+back,true,tag,"course total · %d"%(front+back))

func shape_name(face: float,path: float) -> String:
	var difference: float=face-path
	if club==13: return "PUSH" if face>0.25 else "PULL" if face< -0.25 else "ON LINE"
	if absf(difference)<0.12: return "PUSH" if face>0.3 else "PULL" if face< -0.3 else "STRAIGHT"
	if difference>0: return "SLICE" if difference>0.6 else "FADE"
	return "HOOK" if difference< -0.6 else "DRAW"

func face_meter() -> float:
	return sin(swing_clock*5.6*contact_difficulty())*0.85

func shot_comment(override_category: String="") -> String:
	var category: String=override_category if override_category!="" else course.lie_at(ball_pos)
	if override_category=="":
		if club==13: category="PUTT_NEAR" if distance_to_pin()<2 else "PUTT_LONG"
		elif category=="FAIRWAY" and club<=2: category="DRIVE"
	var lines: Dictionary={
		"HOLED":["BOTTOMS UP!","IN THE CUP. PASS THE COFFEE.","THAT'S HOW YOU FINISH.","CHECK, PLEASE!"],
		"PENALTY":["FRESH BALL, FRESH START","BREAKFAST BALL REQUIRED","TAKE A BREATH. RELOAD.","ONE TO FORGET"],
		"PUTT_NEAR":["JUST A LITTLE TAP LEFT","THE CUP IS CALLING","ONE MORE SIP","KNOCKING ON THE DOOR"],
		"PUTT_LONG":["A LITTLE WORK LEFT","READ IT. ROLL IT.","THE GREEN HAD OTHER PLANS","SAVE SOME TOUCH FOR THE NEXT ONE"],
		"GREEN":["PUTTER TIME","TABLE FOR ONE, ON THE GREEN","THAT APPROACH WILL DO","ORDER UP: A BIRDIE CHANCE"],
		"DRIVE":["CENTER CUT","THAT'S A BREAKFAST BALL","FAIRWAY DELIVERY","COFFEE AND A CLEAN DRIVE"],
		"FAIRWAY":["A GOOD LIE, NO EXCUSES","NICELY POSITIONED","PLENTY TO WORK WITH","KEEP IT COOKING"],
		"FIRST CUT":["JUST OFF THE SHORT STUFF","A FRIENDLY COLLAR","STILL PLENTY TO WORK WITH","A LITTLE FRINGE BENEFIT"],
		"SECOND CUT":["A LITTLE EXTRA FIBER","SCRAMBLE SPECIAL","FOUND THE LONG GRASS","TIME TO DIG IN"],
		"BUNKER":["BEACH BREAK","EXTRA GRIT WITH BREAKFAST","SAND WEDGE SPECIAL","TIME FOR A SPLASH OUT"]}
	var choices: Array=lines.get(category,["THAT'LL PLAY","ONWARD TO THE CUP","NEXT SHOT, FRESH START"])
	var count: int=phrase_counts.get(category,0)
	phrase_counts[category]=count+1
	return choices[count%choices.size()]

func distance_text() -> String:
	var d: float=distance_to_pin()
	return "%.1f ft" % (d*3.0) if d<30 else "%d yd" % roundi(d)

func can_take_breakfast_ball() -> bool:
	return state=="result" and breakfast_offer and mode!=CLOSEST_TO_PIN and not players[player_index].breakfast_used

func take_breakfast_ball() -> void:
	if not can_take_breakfast_ball() or help_open: return
	var p: Dictionary=players[player_index]
	p.breakfast_used=true; p.strokes=0; p.done=false; p.pos=course.tee
	breakfast_offer=false; pending_shot_records.clear(); record_notice=""
	velocity=Vector3.ZERO; replay_path.clear(); result_title=""; result_detail=""
	last_shot="FRESH EGG. FRESH START."
	_prepare_turn()
	breakfast_flash=2.8
	# A short, noisy crack with a bright tail; generated locally like the swing audio.
	if sound_enabled:
		var stream:=AudioStreamWAV.new()
		stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050
		var bytes:=PackedByteArray(); bytes.resize(6615*2)
		var rng:=RandomNumberGenerator.new(); rng.seed=843
		for i in range(6615):
			var t: float=float(i)/22050.0
			var sample: float=rng.randf_range(-1,1)*exp(-t*65)*0.3+sin(t*TAU*1046)*exp(-t*18)*0.1
			bytes.encode_s16(i*2,int(sample*32767))
		stream.data=bytes; audio.stream=stream; audio.play()

func _commit_shot_records() -> void:
	breakfast_offer=false
	for record in pending_shot_records:
		if record[0]=="ace": _count_hole_in_one(record[1])
		else: _record(record[0],record[1],record[2],record[3],record[4])
	pending_shot_records.clear()

func _finish_challenge_shot(holed: bool=false,miss_reason: String="") -> void:
	velocity=Vector3.ZERO
	var feet: float=snappedf(distance_to_pin()*3.0,0.1)
	var valid: bool=miss_reason=="" and (holed or course.lie_at(ball_pos)=="GREEN")
	var points: int=100 if holed else clampi(100-ceili(feet),0,99) if valid else 0
	var p: Dictionary=players[player_index]
	p.pos=ball_pos; p.done=true
	p.challenge_shot={"feet":feet,"points":points,"valid":valid,"holed":holed}
	result_title="BULLSEYE! · 100 POINTS" if holed else "%d POINTS · %.1f FT"%[points,feet] if valid else "MISSED GREEN · 0 POINTS"
	result_detail="One shot served. Next golfer, same pin." if valid else (miss_reason.capitalize()+" · " if miss_reason!="" else "")+"Finish on the green to score. Next tee, fresh start."
	state="result"; result_time=0; trail.append(ball_pos)
	if valid and not holed and feet<=10: _begin_replay("PIN SEEKER · %.1f FEET"%feet)

func advance_turn() -> void:
	if state!="result": return
	_commit_shot_records()
	var all_done: bool=true
	for p in players:
		if not p.done: all_done=false
	if all_done:
		var scores: Array=[]
		for p in players:
			var score: int=p.challenge_shot.points if mode==CLOSEST_TO_PIN else p.strokes
			p.scores.append(score); scores.append(score)
			if mode==CLOSEST_TO_PIN: p.challenge_results.append(p.challenge_shot.duplicate())
		_check_round_records()
		var winner: int=Data.skin_winner(scores)
		hole_message="Hole complete. Fresh tee, fresh start."
		if mode==CLOSEST_TO_PIN: hole_message="Shots served. Highest total wins · 300 points possible."
		if mode==1:
			if winner>=0:
				players[winner].skins+=skin_pot
				hole_message="%s wins %d %s!" % [Data.GOLFERS[players[winner].golfer][0],skin_pot,"skin" if skin_pot==1 else "skins"]
				skin_pot=1
			else:
				skin_pot+=1
				hole_message="Tied hole. %d skins carry to the next." % skin_pot
				if round_position==round_length-1: hole_message="Tied final hole. %d unclaimed skins expire; no playoff." % (skin_pot-1)
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
	if round_position+1>=round_length: state="finished"; return
	round_position+=1; hole_index=round_holes[round_position]; start_hole()

func total_score(i: int) -> int:
	var s: int=0
	for x in players[i].scores: s+=x
	return s

func relative_score(i: int) -> String:
	if mode==CLOSEST_TO_PIN: return "%d PTS"%total_score(i)
	var par: int=0
	for h in range(players[i].scores.size()): par+=Data.HOLES[round_holes[h]][1]
	var d: int=total_score(i)-par
	return "E" if d==0 else "%+d" % d

func winners_text() -> String:
	if mode==CLOSEST_TO_PIN:
		var high: int=-1
		var leaders: Array=[]
		for i in range(players.size()):
			var points: int=total_score(i)
			if points>high: high=points; leaders=[players[i].tag]
			elif points==high: leaders.append(players[i].tag)
		if players.size()==1: return "%s · %d / 300 points. Another serving?"%[leaders[0],high]
		return " & ".join(leaders)+(" share the win" if leaders.size()>1 else " wins")+" · %d points!"%high
	var best: int=-999 if mode==1 else 999
	var names: Array=[]
	for i in range(players.size()):
		var score: int=players[i].skins if mode==1 else total_score(i)
		if (mode==1 and score>best) or (mode==0 and score<best): best=score; names=[Data.GOLFERS[players[i].golfer][0]]
		elif score==best: names.append(Data.GOLFERS[players[i].golfer][0])
	return (" & ".join(names))+ (" share the honors." if names.size()>1 else " takes the clubhouse!")

func _process(delta: float) -> void:
	total_time+=delta
	if state=="aim" and not help_open: breakfast_flash=maxf(0.0,breakfast_flash-delta)
	if state=="calibration": calibration_clock=fmod(calibration_clock+delta,CALIBRATION_DURATION)
	if state=="replay":
		replay_time+=delta
		var progress: float=clampf(replay_time/replay_duration,0,1)
		# Ease through launch and landing, with the middle of the flight moving fastest.
		var eased: float=smoothstep(0.0,1.0,progress)
		var at: float=eased*maxi(0,replay_path.size()-1)
		var index: int=mini(replay_path.size()-2,int(at))
		if replay_path.size()>1:
			ball_pos=replay_path[index].lerp(replay_path[index+1],at-index)
			ball.position=ball_pos
		if progress>=1.0:
			ball_pos=replay_end_position; ball.position=ball_pos
			ball.visible=not players[player_index].challenge_shot.get("holed",false) if mode==CLOSEST_TO_PIN else not players[player_index].done
			state=replay_return_state; result_time=0
	if (dragging or keyboard_charge) and state=="aim" and not help_open: swing_clock+=delta
	if state=="result": result_time+=delta
	if keyboard_charge and state=="aim" and not help_open: charge=minf(charge+delta*0.55,1.6)
	if dragging and state=="aim" and not help_open and pull>=1.0: full_power_hold+=delta
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
		var qa_delay: float=0.5 if "--qa-swing" in OS.get_cmdline_user_args() else 1.30 if "--qa-followthrough" in OS.get_cmdline_user_args() else 1.4 if "--qa-replay" in OS.get_cmdline_user_args() else 3.0
		if qa_elapsed>qa_delay and qa_step==0:
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
	elif state=="replay":
		var index: int=clampi(int((replay_time/replay_duration)*maxi(1,replay_path.size()-1)),1,replay_path.size()-1)
		var travel: Vector3=(replay_path[index]-replay_path[index-1]).normalized()
		if travel.length_squared()<0.1: travel=aim_direction()
		var side:=Vector3(-travel.z,0,travel.x)
		target=ball_pos+travel*4.0
		pos=ball_pos-travel*15.0+side*sin(replay_time*1.4)*6.0+Vector3.UP*(7.5+maxf(0,ball_pos.y-course.height_at(ball_pos.x,ball_pos.z))*0.16)
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
	if parsec_setup_open:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: parsec_setup_open=false
		return
	if state=="calibration":
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			remote_timing_enabled=false; state="menu"; return
		if event is InputEventKey and not event.pressed and event.keycode==KEY_SPACE:
			record_calibration_sample(); return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			record_calibration_sample(); return
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if state=="name_entry":
			if event.keycode==KEY_ESCAPE: state="menu"
			elif event.keycode==KEY_BACKSPACE: name_entry_value=name_entry_value.left(maxi(0,name_entry_value.length()-1))
			elif event.keycode==KEY_ENTER: _accept_name_entry()
			elif event.unicode>=65 and event.unicode<=90 or event.unicode>=97 and event.unicode<=122:
				if name_entry_value.length()<5: name_entry_value+=char(event.unicode).to_upper()
			return
		if state=="leaderboard":
			if event.keycode in [KEY_ESCAPE,KEY_ENTER]: state="menu"
			return
		if state=="replay" and event.keycode in [KEY_ESCAPE,KEY_ENTER,KEY_SPACE]:
			ball_pos=replay_end_position; ball.position=ball_pos
			ball.visible=not players[player_index].challenge_shot.get("holed",false) if mode==CLOSEST_TO_PIN else not players[player_index].done
			state=replay_return_state; result_time=0; return
		if event.keycode==KEY_H:
			help_open=not help_open; dragging=false; keyboard_charge=false; return
		if help_open and event.keycode!=KEY_ESCAPE: return
		if event.keycode==KEY_B and state=="result": take_breakfast_ball(); return
		if event.keycode==KEY_ESCAPE:
			if help_open: help_open=false
			elif state=="pause": state=previous_state
			elif state in ["aim","flight","result"]: previous_state=state; state="pause"; dragging=false; keyboard_charge=false
			return
		if event.keycode==KEY_ENTER:
			if state=="menu": begin_name_entry()
			elif state=="result": advance_turn()
			elif state=="scorecard": next_hole()
			return
		if state=="aim" and not help_open:
			if event.keycode==KEY_Q: change_club(-1)
			if event.keycode==KEY_E: change_club(1)
			if event.keycode==KEY_V: overview=not overview
			if event.keycode==KEY_S: spin=(spin+2)%3-1
			if event.keycode==KEY_TAB: score_return=state; state="scorecard"
			if event.keycode==KEY_SPACE: keyboard_charge=true; charge=0; swing_clock=0; path_offset=0; full_power_hold=0
			if event.keycode==KEY_A: path_offset=clampf(path_offset-0.15,-1,1)
			if event.keycode==KEY_D: path_offset=clampf(path_offset+0.15,-1,1)
	if event is InputEventKey and not event.pressed and event.keycode==KEY_SPACE and keyboard_charge:
		shoot(maxf(charge,0.04),evaluated_face_meter(),path_offset)
	if help_open or state!="aim": return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: change_club(-1)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: change_club(1)
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and hud.swing_rect.has_point(event.position):
				dragging=true; drag_start=event.position; drag_current=event.position; peak_y=event.position.y; pull=0; swing_clock=0; path_offset=0; full_power_hold=0
			elif event.pressed and event.position.y>106 and event.position.y<560 and event.position.x<1020:
				aiming_drag=true; drag_current=event.position
			elif not event.pressed:
				if dragging:
					var error: float=clampf(evaluated_face_meter()+(event.position.x-drag_start.x)/150.0,-1,1)
					if pull>0.06: shoot(swing_power(),error,path_offset)
					dragging=false
				aiming_drag=false
	if event is InputEventMouseMotion:
		if dragging:
			if event.position.y>=peak_y: path_offset=clampf((event.position.x-drag_start.x)/70.0,-1,1)
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

func _exit_tree() -> void:
	if is_instance_valid(music): music.stop(); music.stream=null
	if is_instance_valid(audio): audio.stop(); audio.stream=null
