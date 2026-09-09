extends SceneTree

const Main=preload("res://game/main.gd")
const Data=preload("res://game/data.gd")
var game: Node3D
var checks: int=0
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+label)

func key(code: Key,pressed: bool=true) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.pressed=pressed
	game._input(event)

func mouse(pos: Vector2,pressed: bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT
	event.position=pos; event.pressed=pressed; game._input(event)

func simulate() -> void:
	for frame in range(2400):
		if game.state!="flight": return
		game._physics_process(1.0/60.0)
	check(false,"shot settles")

func run() -> void:
	game=Main.new(); game.sound_enabled=false; root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.qa_mode=true; game.qa_step=1
	game.records_enabled=false
	game.preferences_path="/private/tmp/breakfast-feedback-preferences.cfg"
	game.leaderboard_path="/private/tmp/breakfast-feedback-records.json"
	game.leaderboard=game._default_leaderboard()
	game.hud._action("input:1"); game.input_style=0; game._load_preferences()
	check(game.input_style==1,"mouse guidance persists")
	game.hud._action("input:0"); game.input_style=1; game._load_preferences()
	check(game.input_style==0,"keyboard guidance persists")
	game.player_count=3; game.mode=1; game.round_length=18; game.tees=1; game.remote_timing_enabled=true
	game.hud._action("practice")
	check(game.practice_active and game.player_count==1 and game.state=="aim","practice starts without name entry")
	check(game.course.lie_at(game.ball_pos)=="GREEN" and game.club==13,"putt station on green")
	check(game.distance_text()=="24.0 ft" and "ft" in game.range_text() and "ft" in game.power_distance_text(0.5),"putt UI consistently uses feet")
	for station in range(3):
		game.hud._action("station:%d"%station)
		check(("ft" if station==0 else "yd") in game.distance_text(),"cup units match selected shot scale")
		check(game.club==[13,9,10][station] and game.style_index()==[0,2,1][station],"station chooses intended club and shot")
		check(game.course.lie_at(game.ball_pos)==("GREEN" if station==0 else "FAIRWAY"),"station has expected lie")
		check(is_equal_approx(game.distance_to_pin(),[8.0,22.0,55.0][station]),"station exact distance")
		var origin: Vector3=game.ball_pos
		var scale_before: float=game.club_range()
		key(KEY_SPACE); game._process(PI/5.6); key(KEY_SPACE,false)
		check(game.state=="flight" and absf(game.shot_face)<0.001,"keyboard releases square through input")
		simulate(); var finish: Vector3=game.ball_pos
		if station==0: check(is_equal_approx(game.club_range(),scale_before),"putter scale frozen through result")
		var measurements: Array=[game.shot_carry,game.shot_roll]
		check(game.state=="result" and not game.can_take_breakfast_ball(),"practice result offers retry without mulligan")
		check(game.wind==Vector2.ZERO and game.players[0].scores.is_empty(),"practice fixed wind and no scoring")
		game.hud._action("continue")
		check(game.ball_pos==origin and game.players[0].strokes==0,"Enter flow restores exact origin")
		key(KEY_SPACE); game._process(PI/5.6); key(KEY_SPACE,false); simulate()
		check(game.ball_pos.distance_to(finish)<0.0001 and is_equal_approx(game.shot_roll,measurements[1]),"practice repeats identical physical shot")
		key(KEY_R)
		check(game.state=="aim" and game.ball.visible,"R restores playable ball")
	game.hud._action("station:1")
	key(KEY_SPACE); game._process(0.4)
	var old_club: int=game.club; var old_style: int=game.shot_style; var old_spin: int=game.spin
	game.hud._action("selectclub:0"); game.hud._action("shotstyle:0"); key(KEY_S)
	check(game.club==old_club and game.shot_style==old_style and game.spin==old_spin,"charging locks club, shot type and spin")
	key(KEY_H); key(KEY_SPACE,false)
	check(game.help_open and game.state=="aim" and not game.keyboard_charge,"help cancels swing without shooting")
	key(KEY_R); check(game.help_open,"hidden practice shortcuts do not dismiss help")
	key(KEY_H)
	game.hud._action("shotstyle:1"); key(KEY_X)
	check(game.style_index()==2,"X cycles wedge shot style")
	game.hud._action("selectclub:0")
	check(game.style_index()==0,"driver cannot retain chip range")
	game.hud._action("station:1")
	# Actual click-drag-return-release sequence, not a direct shoot call.
	mouse(Vector2(1050,612),true)
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(1050,669); game._input(motion)
	game._process(PI/5.6)
	motion.position=Vector2(1050,612); game._input(motion)
	mouse(Vector2(1050,612),false)
	check(game.state=="flight" and absf(game.shot_face)<0.001,"mouse/trackpad gesture launches square")
	key(KEY_R); check(game.state=="aim" and game.velocity==Vector3.ZERO,"R can abort flight instantly")
	game.shoot(0.5); simulate(); game._sink(); game.advance_turn()
	check(game.state=="aim" and game.ball.visible and not game.players[0].done,"holed practice shot resets")
	game.records_enabled=true
	var book: Dictionary=game.leaderboard.duplicate(true)
	game._record("longest_drive",999,false,"TESTY","practice"); game._count_hole_in_one("TESTY"); game._check_round_records()
	check(game.leaderboard==book,"practice cannot affect any records")
	key(KEY_ESCAPE); game.hud._action("menu")
	check(not game.practice_active and game.player_count==3 and game.mode==1 and game.round_length==18 and game.remote_timing_enabled,"practice restores round setup on exit")
	# Preserve the championship book while separating all club-tee records.
	game.breakfast_offer=false; game.round_tees=0
	game._record("front_nine",38,true,"CHAMP","championship")
	game.round_tees=1; game._record("front_nine",30,true,"CLUBS","club tees"); game._count_hole_in_one("CLUBS")
	check(game.leaderboard.front_nine.value==38 and game.record_book().front_nine.value==30,"tee score records separated")
	check(game.leaderboard.hole_in_ones.value==0 and game.record_book().hole_in_ones.value==1,"tee ace records separated")
	game._load_leaderboard()
	check(game.record_book(0).front_nine.value==38 and game.record_book(1).front_nine.value==30,"both record books survive reload")
	game.records_enabled=false; game.remote_timing_enabled=false; game.mode=0; game.player_count=1; game.round_length=18
	game.start_round()
	check(game.round_tees==1,"round captures selected tees")
	for hole in [2,4,6,13]:
		game.hole_index=hole; game.start_hole()
		check(game.course.tee.z<0 and game.course.lie_at(game.course.tee)=="TEE","club tee has safe tee lie")
		check(absf(game.course.tee.y-game.course.height_at(game.course.tee.x,game.course.tee.z)-0.15)<0.001,"tee sits on terrain")
		check(game.course.terrain_mesh.material_override.get_shader_parameter("tee_area")==Vector4(game.course.tee.x,game.course.tee.z,8,5),"tee visuals and lie share geometry")
		check(is_equal_approx(-game.course.tee.z/game.YARD,Data.CLUB_TEE_ADVANCE[hole]),"tee advance matches yardage data")
	game.hole_index=2; game.start_hole(); game.wind=Vector2.ZERO
	game.shoot(0.4); simulate(); game.take_breakfast_ball()
	check(game.ball_pos==game.course.tee and game.players[0].strokes==0,"Breakfast Ball restores alternate tee")
	game.tees=0; game.start_round()
	check(game.course.tee.z==0 and game.round_tees==0,"championship tee retained")
	game.tees=1; game.mode=2; game.start_round()
	check(game.round_tees==0 and game.course.tee.z==0,"challenge remains championship")
	# Isolate trajectories on a flat fairway; compare chip/pitch at equal carry.
	game.mode=0; game.players[0].breakfast_used=false
	var real_course: Node3D=game.course
	var flat=preload("res://tests/putt_test_course.gd").new(); game.add_child(flat); game.course=flat
	flat.test_lie="FAIRWAY"; flat.pin=Vector3(0,0,-1000)
	game.wind=Vector2.ZERO; game.club=12; game.spin=0; game.aim=0
	var metrics: Array=[]
	for style in [0,1,2]:
		game.shot_style=style; game.state="aim"; game.ball_pos=Vector3(0,0.22,0)
		game.players[0].strokes=0; game.players[0].done=false
		game.shoot(12.0/game.club_range())
		var peak: float=0
		for frame in range(2400):
			if game.state!="flight": break
			game._physics_process(1.0/60.0); peak=maxf(peak,game.ball_pos.y)
		check(game.state=="result" and absf(game.shot_carry-12.0)<0.12,"each shot profile delivers calibrated carry")
		metrics.append([peak,game.shot_roll])
		print("PROFILE %s peak=%.2fm carry=%.2fyd roll=%.2fyd"%[Data.SHOT_STYLES[style].name,peak,game.shot_carry,game.shot_roll])
	check(metrics[1][0]>metrics[2][0] and metrics[2][1]>metrics[1][1],"pitch higher and softer than chip at equal carry")
	for power in [0.25,0.5,0.75]:
		game.shot_style=2; game.state="aim"; game.ball_pos=Vector3(0,0.22,0); game.players[0].strokes=0
		var expected: float=game.club_range()*power
		game.shoot(power); simulate()
		check(absf(game.shot_carry-expected)<0.12,"chip range works at multiple powers")
	game.course=real_course; flat.free()
	print("FEEDBACK_TESTS: %d checks, %d failures"%[checks,failures])
	game.free(); quit(1 if failures else 0)
