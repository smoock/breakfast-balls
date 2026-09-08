extends SceneTree

const Data=preload("res://game/data.gd")
const Main=preload("res://game/main.gd")
var failures: int=0
var checks: int=0
var game: Node3D

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures+=1; printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func start_test_round() -> void:
	var count: int=game.round_length
	game.round_length=18; game.start_round()
	game.round_length=count; game.round_holes=game.round_holes.slice(0,count)

func simulate() -> void:
	for frame in range(1600):
		if game.state!="flight": return
		game._physics_process(1.0/60.0)
	check(false,"shot settled within bounded physics steps")

func run() -> void:
	check(Data.CLUBS.size()==14,"14 clubs")
	check(Data.HOLES.size()==18,"18 holes")
	var par: int=0
	for h in Data.HOLES: par+=h[1]
	check(par==72,"course par 72")
	check(Data.skin_winner([4,5,6,7])==0,"unique low wins skin")
	check(Data.skin_winner([4,4,5])==-1,"low tie carries skin")
	check(Data.skin_winner([4,4,3])==2,"later unique lower score beats earlier tie")
	game=Main.new(); root.add_child(game); game.sound_enabled=false; game.records_enabled=false
	# Remote timing keeps the original meter but evaluates the state the guest saw.
	game.remote_timing_enabled=true; game.player_count=2; game.round_length=3
	game.begin_calibration()
	for sample_clock in [0.90,0.88,0.89]:
		game.calibration_clock=sample_clock; game.record_calibration_sample()
	check(game.state=="aim","three calibration passes start the round")
	check(is_equal_approx(game.timing_offsets[1],0.09),"median guest timing offset rejects sample order")
	game.player_index=1
	for delay in [0.0,0.08,0.15,0.25]:
		game.timing_offsets[1]=delay; game.swing_clock=0.42+delay
		var expected: float=sin(0.42*5.6*game.contact_difficulty())*0.85
		check(is_equal_approx(game.evaluated_face_meter(),expected),"timing compensation matches local result at %d ms"%roundi(delay*1000))
	game.player_index=0; game.timing_offsets[0]=0.25; game.swing_clock=0.42
	check(is_equal_approx(game.evaluated_face_meter(),game.face_meter()),"host timing is never offset")
	game.remote_timing_enabled=false
	game.parsec_setup_open=true
	var parsec_escape:=InputEventKey.new(); parsec_escape.keycode=KEY_ESCAPE; parsec_escape.pressed=true
	game._input(parsec_escape)
	check(not game.parsec_setup_open,"Escape closes the Parsec setup card")
	game.player_count=4; game.round_length=3; game.mode=0; start_test_round()
	check(game.players.size()==4,"four local golfers")
	game.wind=Vector2.ZERO
	game.shoot(1.0)
	simulate()
	check(game.state=="result","driver settles to result")
	check(game.players[0].strokes==1,"one swing counts one stroke")
	check(game.shot_distance>180 and game.shot_distance<360,"drive travels sensible tour-scale distance")
	print("DRIVE_TOTAL_YARDS ",game.shot_distance)
	game.advance_turn()
	check(game.player_index==1,"next unplayed golfer tees off")
	check(game.players[0].pos!=game.players[1].pos,"independent player ball positions")
	# A real putt traverses the green and drops at the cup; no direct _sink call.
	game.player_count=1; game.mode=0; start_test_round()
	game.ball_pos=game.course.pin+Vector3(0,0,2.0)
	game.ball_pos.y=game.course.height_at(game.ball_pos.x,game.ball_pos.z)+0.22
	game.players[0].pos=game.ball_pos; game._prepare_turn()
	game.wind=Vector2.ZERO; game.club=13
	game.shoot(2.0/(game.club_range()*game.YARD))
	simulate()
	check(game.players[0].done,"two-metre putt enters cup")
	check(game.players[0].strokes==1,"putt stroke counted")
	game.advance_turn()
	check(game.state=="scorecard","holed round advances to scorecard")
	check(game.players[0].scores.size()==1,"score recorded once")
	game.next_hole()
	check(game.hole_index==1 and game.state=="aim","next hole playable")
	# Water: simulate an actual ball entering the penalty region.
	game.course.ponds=[Vector4(0,-2,15,15)]
	game.ball_pos=Vector3(0,game.course.height_at(0,-2)+0.22,-2)
	game.last_safe=game.course.tee; game.players[0].strokes=1
	game.velocity=Vector3(0,0,-1); game.in_air=false; game.state="flight"
	game._physics_process(1.0/60.0)
	check(game.players[0].strokes==2,"water applies exactly one penalty")
	check(game.ball_pos==game.course.tee,"water returns to previous safe lie")
	# Skins carryover through the actual scorecard transition.
	game.player_count=2; game.mode=1; start_test_round()
	for p in game.players: p.strokes=4; p.done=true
	game.state="result"; game.advance_turn()
	check(game.skin_pot==2,"tied first hole carries one skin")
	game.next_hole()
	game.players[0].strokes=4; game.players[1].strokes=5
	for p in game.players: p.done=true
	game.state="result"; game.advance_turn()
	check(game.players[0].skins==2 and game.skin_pot==1,"unique winner collects two-skin pot")
	# Full 18-hole, four-player scoring progression, including final results.
	game.player_count=4; game.mode=0; game.round_length=18; start_test_round()
	for h in range(18):
		check(game.hole_index==h,"correct hole index")
		check(game.course.lie_at(game.course.pin)=="GREEN","pin on playable green")
		for i in range(4): game.players[i].strokes=Data.HOLES[h][1]+i; game.players[i].done=true
		game.state="result"; game.advance_turn(); game.next_hole()
	check(game.state=="finished","full round finishes")
	check(game.total_score(0)==72 and game.total_score(3)==126,"18-hole totals")
	check(game.winners_text().begins_with("Tommy"),"stroke winner determined")
	# Exercise the actual event path: pull down, push forward, release.
	game.player_count=1; game.mode=0; start_test_round()
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=Vector2(1090,620)
	game._input(press)
	check(game.dragging,"swing pad starts drag")
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(1090,712)
	game._input(motion)
	check(is_equal_approx(game.pull,1.0),"full backswing sets full power")
	motion.position=Vector2(1090,621); game._input(motion)
	check(is_equal_approx(game.pull,1.0),"forward swing retains peak power")
	press.pressed=false; press.position=motion.position; game._input(press)
	check(game.state=="flight" and game.players[0].strokes==1,"mouse release launches one shot")
	simulate()
	check(game.state=="result","gesture shot settles")
	start_test_round()
	var key:=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true; game._input(key)
	game._process(0.9)
	check(game.keyboard_charge and game.charge>0.4,"keyboard power charges")
	key.pressed=false; game._input(key)
	check(game.state=="flight","keyboard release launches")
	key.keycode=KEY_ESCAPE; key.pressed=true; game._input(key)
	var paused_pos: Vector3=game.ball_pos; game._physics_process(0.1)
	check(game.ball_pos==paused_pos and game.state=="pause","pause freezes flight")
	game._input(key); check(game.state=="flight","resume restores flight")
	start_test_round(); game.wind=Vector2.ZERO
	for heading in [0.0,0.7,-1.2,2.6]:
		game.aim=heading; game._update_marker()
		check(game.swing_parts[7].global_position.distance_to(game.ball_pos)<0.001,"clubhead addresses ball at rotated aim")
		var stance_axis: Vector3=game.golfer.global_basis.x.normalized()
		check(absf(stance_axis.dot(game.aim_direction()))>0.999,"stance parallel to target line")
	game.aim=0; game._update_marker()
	var address: Vector3=game.ball_pos
	game.shoot(1.0)
	game._physics_process(0.4)
	check(game.ball_pos==address and game.impact_pending,"ball waits for club impact")
	check(game.swing_parts[7].global_position.distance_to(address)>1.0,"club visibly moves during backswing")
	for i in range(28): game._physics_process(1.0/60)
	check(not game.impact_pending and game.ball_pos!=address,"impact releases ball")
	for i in range(900):
		if game.bounced or not game.in_air or game.state!="flight": break
		game._physics_process(1.0/60)
	print("DRIVER_FIRST_LANDING_SECONDS ",game.shot_time)
	check(game.shot_time>5.0 and game.shot_time<7.0,"driver stays airborne about six real-time seconds")
	check(game.shot_distance>240 and game.shot_distance<310,"slower flight retains intended carry scale")
	simulate()
	check(game.state=="result","slower shot settles")
	start_test_round(); game.club=0
	check(game.shape_name(0,0.4)=="DRAW","inside-out path with square face draws")
	check(game.shape_name(0,-0.4)=="FADE","outside-in path with square face fades")
	check(game.shape_name(0.9,0)=="SLICE","open face produces slice")
	check(game.shape_name(-0.9,0)=="HOOK","closed face produces hook")
	check(game.shape_name(-0.5,-0.5)=="PULL","matched left face/path pulls")
	var curve_x: Array=[]
	for path in [0.4,-0.4]:
		start_test_round(); game.aim=0; game.wind=Vector2.ZERO; game._update_marker()
		game.shoot(1.0,0.0,path)
		for i in range(180): game._physics_process(1.0/60)
		curve_x.append(game.velocity.x)
	check(curve_x[0]<0 and curve_x[1]>0,"draw and fade curve physically in opposite directions")
	start_test_round()
	for angle in [0.0,-0.7,-2.25,1.0,2.45]:
		game._pose_swing(angle)
		check(absf(game.swing_parts[6].mesh.height-1.16)<0.001,"club length constant throughout swing")
	game.swing_clock=0.1; var face_a: float=game.face_meter()
	game.swing_clock=0.5; check(absf(face_a-game.face_meter())>0.1,"release timing changes clubface")
	game.club=13
	var phrases: Array=[]
	for i in range(4): phrases.append(game.shot_comment())
	check(phrases[0]!=phrases[1] and phrases[1]!=phrases[2] and phrases[2]!=phrases[3],"putt commentary does not repeat consecutively")
	check(not "ON THE DANCE FLOOR" in phrases,"putts do not reuse approach message")
	check(game.shot_comment("HOLED")!=game.shot_comment("HOLED"),"holed commentary varies")
	start_test_round(); game.keyboard_charge=true; game.charge=1.0
	game._process(0.8)
	check(game.swing_power()>1.4,"keyboard cannot park at 100 percent")
	game.keyboard_charge=false; game.dragging=true; game.pull=1; game.full_power_hold=0
	game._process(0.8)
	check(game.swing_power()>1.3,"mouse holding full backswing incurs overswing")
	game.pull=0.99; game.full_power_hold=0; game.swing_clock=3.0
	check(game.swing_power()>1.5,"waiting just below full power cannot bypass overswing")
	game.dragging=false; game.shoot(1.0); var clean_speed: float=game.velocity.length()
	start_test_round(); game.shoot(1.5)
	check(game.velocity.length()<clean_speed*0.9,"overswing loses ball speed even with square input face")
	check(game.last_shot.begins_with("OVERSWING"),"overswing feedback visible")
	start_test_round()
	var base_y: float=game.course.height_at(0,0)
	game.course.trees=[Vector3(0,base_y+10,0)]
	game.ball_pos=Vector3(0.3,base_y+0.22,0); game.velocity=Vector3(8,2,0)
	game._resolve_trees(Vector3(0.2,base_y+0.22,0))
	check(game.ball_pos.x>0.52 and game.velocity.x>0,"overlap separates outward without reversing escaping ball")
	for heading in [0.0,0.7,1.5,2.8,4.2]:
		var escape:=Vector3(sin(heading),0,cos(heading))
		var previous: Vector3=Vector3(0,base_y+0.22,0)+escape*0.2
		game.ball_pos=previous+escape*0.1; game.velocity=escape*8
		game._resolve_trees(previous)
		check(game.velocity.dot(escape)>7.9,"overlapping lie can escape at multiple angles")
	game.ball_pos=Vector3(2,base_y+0.22,0); game.velocity=Vector3(20,0,0)
	game._resolve_trees(Vector3(-2,base_y+0.22,0))
	check(game.ball_pos.x< -0.52 and game.velocity.x<0,"swept collision stops tunneling through trunk")
	game.tree_hits.clear(); game.ball_pos=Vector3(1,base_y+12,0); game.velocity=Vector3(10,0,0)
	game._resolve_trees(game.ball_pos); var leaf_speed: float=game.velocity.length()
	game._resolve_trees(game.ball_pos)
	check(is_equal_approx(game.velocity.length(),leaf_speed),"foliage does not repeatedly crush velocity")
	game.players[0].pos=Vector3(0.55,base_y+0.22,0); game._prepare_turn()
	game.aim=PI/2; game.club=10; game.wind=Vector2.ZERO; game._update_marker(); game.shoot(0.4)
	simulate()
	check(game.shot_distance>10,"actual shot escapes next to tree")
	var z: float=-100
	var center_x: float=game.course.center_x(z)
	var width: float=game.course.fairway_width(z)
	check(game.course.lie_at(game.course.ground_point(center_x,z))=="FAIRWAY","fairway classification")
	check(game.course.lie_at(game.course.ground_point(center_x+width+3,z))=="FIRST CUT","first cut classification")
	check(game.course.lie_at(game.course.ground_point(center_x+width+10,z))=="SECOND CUT","second cut classification")
	var mr:=Rect2(0,0,200,250)
	var origin: Vector2=game.hud._map_point(Vector3.ZERO,mr)
	check(is_equal_approx(origin.distance_to(game.hud._map_point(Vector3(10,0,0),mr)),origin.distance_to(game.hud._map_point(Vector3(0,0,10),mr))),"mini-map uses equal scale on both axes")
	var original_course: Node3D=game.course
	var putting_course=preload("res://tests/putt_test_course.gd").new()
	game.add_child(putting_course); game.course=putting_course
	putting_course.pin=Vector3(0,0,-1000)
	for lie in ["GREEN","TEE","FAIRWAY","FIRST CUT","SECOND CUT","BUNKER"]:
		putting_course.test_lie=lie; putting_course.transition=false
		for power in [0.25,0.5]:
			game.ball_pos=Vector3(0,0.22,0); game.state="aim"; game.club=13; game.aim=0
			game.players[0].strokes=0; game.players[0].done=false
			var expected: float=game.club_range()*game.YARD*power
			game.shoot(power); simulate()
			check(absf(-game.ball_pos.z-expected)<0.20,"putt power maps to roll distance on "+lie)
	for lie in ["FAIRWAY","FIRST CUT","SECOND CUT"]:
		for slope in [-0.025,0.0,0.025]:
			putting_course.test_lie=lie; putting_course.transition=true; putting_course.slope=slope
			game.ball_pos=Vector3(0,0.22,0); game.state="aim"; game.club=13; game.aim=0
			game.players[0].strokes=0; game.players[0].done=false
			game.shoot(12.0/(game.club_range()*game.YARD)); simulate()
			check(absf(-game.ball_pos.z-12.0)<0.25,"mixed-surface putt respects distance and slope from "+lie)
	putting_course.transition=false
	for lie in ["TEE","FAIRWAY","GREEN","FIRST CUT","SECOND CUT","BUNKER"]:
		putting_course.test_lie=lie; game.swing_clock=0.1
		var multiplier: float={"TEE":1.0,"FAIRWAY":1.0,"GREEN":1.0,"FIRST CUT":1.25,"SECOND CUT":1.6,"BUNKER":1.9}[lie]
		check(is_equal_approx(game.contact_difficulty(),multiplier),"contact difficulty for "+lie)
		check(is_equal_approx(game.face_meter(),sin(0.1*5.6*multiplier)*0.85),"meter actually runs at lie speed for "+lie)
	game.course=original_course; putting_course.queue_free()
	var seen: Dictionary={}
	for i in range(20):
		var holes: Array=game.select_round_holes(3,0)
		check(holes.size()==3 and holes[0]!=holes[1] and holes[1]!=holes[2] and holes[0]!=holes[2],"random three contains three unique holes")
		seen[str(holes)]=true
	check(seen.size()>1,"three-hole selection varies")
	check(game.select_round_holes(9,0)==[0,1,2,3,4,5,6,7,8],"front nine routing")
	check(game.select_round_holes(9,1)==[9,10,11,12,13,14,15,16,17],"back nine routing")
	game.player_count=1; game.mode=0; game.round_length=9; game.nine_side=1; game.start_round()
	for i in range(9):
		check(game.hole_index==9+i,"back-nine plays correct actual hole")
		game.players[0].strokes=Data.HOLES[game.hole_index][1]; game.players[0].done=true
		game.state="result"; game.advance_turn(); game.next_hole()
	check(game.state=="finished" and game.relative_score(0)=="E","back-nine scoring and completion")
	game.course.build(13); check(game.course.bunkers.is_empty(),"fourteenth has no bunkers")
	game.course.build(0); check(game.course.center_x(-game.course.length_m)>0,"first hole doglegs right")
	game.course.build(12); check(game.course.ponds.size()>10,"thirteenth has winding creek")
	for i in range(8): check(ResourceLoader.exists("res://game/assets/portraits/golfer-%d.png"%i),"portrait asset exists")
	game.player_count=2; game.mode=1; game.round_length=3; game.start_round()
	var chosen: Array=game.round_holes.duplicate()
	for i in range(3):
		check(game.hole_index==chosen[i],"random round follows saved selection")
		for p in game.players: p.strokes=Data.HOLES[game.hole_index][1]; p.done=true
		game.state="result"; game.advance_turn()
		if i==2: check("expire" in game.hole_message,"random round final skins expire correctly")
		game.next_hole()
	check(game.state=="finished","random three-hole round finishes")
	for i in range(8):
		game.players[0].golfer=i; game.player_index=0; game._build_golfer(); game._align_golfer()
		game._pose_swing(-2.25)
		check(game.golfer.get_node("SwingTorso").rotation.y<0,"backswing coils away from target")
		game._pose_swing(2.25)
		check(game.golfer.get_node("SwingTorso").rotation.y>0,"follow-through turns toward target")
		game._pose_swing(0)
		check(game.swing_parts[7].global_position.distance_to(game.ball_pos)<0.001,"detailed character preserves impact alignment")
	game.course.build(0)
	var bunker: Vector4=game.course.bunkers[0]
	check(game.course.base_height_at(bunker.x,bunker.y)-game.course.height_at(bunker.x,bunker.y)>1.0,"bunker has physical terrain depth")
	# Local record ordering and five-character tag handoff use a disposable file.
	game.leaderboard=game._default_leaderboard()
	game.leaderboard_path="/private/tmp/breakfast-balls-test-leaderboard.json"
	game.records_enabled=true
	check(game._record("longest_drive",275,false,"BACON","275 yd drive"),"first valid drive sets local record")
	check(not game._record("longest_drive",270,false,"SLICE","270 yd drive"),"shorter drive does not replace record")
	check(game._record("front_nine",34,true,"BIRDY","front nine · 34"),"first nine-hole score sets record")
	check(not game._record("front_nine",36,true,"TOMMY","front nine · 36"),"higher nine-hole score does not replace record")
	game._count_hole_in_one("BIRDY"); game._count_hole_in_one("BIRDY")
	check(game.leaderboard.hole_in_ones.value==2 and game.leaderboard.hole_in_ones.by_name.BIRDY==2,"hole-in-one counter persists total and player tally")
	game.player_count=1; game.name_entry_index=0; game.name_entry_value="EGGSY"; game._accept_name_entry()
	check(game.players[0].tag=="EGGSY" and game.state=="aim","confirmed five-letter tag starts the round")
	game.records_enabled=false
	print("GOLF_TESTS: %d checks, %d failures"%[checks,failures])
	game.free()
	quit(1 if failures else 0)
