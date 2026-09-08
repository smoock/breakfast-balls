extends SceneTree

const Main=preload("res://game/main.gd")
var game: Node3D
var checks: int=0
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+label)

func simulate() -> void:
	for frame in range(2400):
		if game.state!="flight": return
		game._physics_process(1.0/60.0)
	check(false,"shot settles within 40 simulated seconds")

func press(key: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=key; event.pressed=true
	game._input(event)

func opening_round(count: int=2) -> void:
	game.mode=0; game.player_count=count; game.round_length=9; game.nine_side=0
	game.start_round(); game.wind=Vector2.ZERO

func run() -> void:
	game=Main.new(); game.sound_enabled=false; root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.sound_enabled=false; game.records_enabled=false; game.qa_mode=true
	opening_round()
	game.shoot(0.4); simulate()
	check(game.can_take_breakfast_ball(),"first settled tee shot offers Breakfast Ball")
	var partner: Dictionary=game.players[1].duplicate(true)
	game.help_open=true; press(KEY_B)
	check(game.state=="result" and not game.players[0].breakfast_used,"help prevents hidden mulligan input")
	game.help_open=false; press(KEY_ESCAPE)
	check(game.state=="pause","opening result can pause")
	press(KEY_B); check(not game.players[0].breakfast_used,"pause prevents mulligan")
	press(KEY_ESCAPE); press(KEY_B)
	check(game.state=="aim" and game.player_index==0,"B returns same player to aim")
	check(game.players[0].strokes==0 and game.ball_pos==game.course.tee,"Breakfast Ball restores tee and stroke count")
	check(game.players[0].breakfast_used and not game.players[0].done,"Breakfast Ball marks used and clears completion")
	check(game.players[1]==partner,"Breakfast Ball preserves another golfer")
	check(game.trail.is_empty() and game.velocity==Vector3.ZERO,"retry clears discarded flight state")
	game.shoot(0.4); simulate()
	check(not game.can_take_breakfast_ball(),"retry cannot earn another Breakfast Ball")
	game.hud._action("continue")
	check(game.player_index==1 and game.state=="aim","retry hands off to unplayed golfer")
	game.shoot(0.4); simulate()
	check(game.can_take_breakfast_ball(),"each golfer gets independent opening offer")
	game.hud._action("continue")
	check(not game.breakfast_offer,"keeping shot closes offer")
	# An actual hazard collision counts a penalty, then both strokes are removed.
	opening_round(1)
	game.course.ponds=[Vector4(0,0,25,25)]
	game.club=13; game.shoot(0.05); simulate()
	check(game.players[0].strokes==2,"water shot includes penalty")
	check(game.can_take_breakfast_ball(),"penalized opening shot still offers retry")
	game.take_breakfast_ball()
	check(game.players[0].strokes==0,"Breakfast Ball also removes water penalty")
	game.round_position=1; game.hole_index=1; game.start_hole()
	game.shoot(0.2); simulate()
	check(not game.can_take_breakfast_ball(),"later tee shots cannot use Breakfast Ball")
	# Records from discarded opening shots never reach disk or the record book.
	opening_round(1)
	game.leaderboard=game._default_leaderboard()
	game.leaderboard_path="/private/tmp/breakfast-feature-test-records.json"
	game.records_enabled=true
	game.shoot(0.3); simulate()
	game._record("longest_drive",310,false,"TOMMY","310 yd drive")
	check(game.leaderboard.longest_drive.value==0,"opening record waits for keep decision")
	game.take_breakfast_ball()
	check(game.pending_shot_records.is_empty() and game.leaderboard.longest_drive.value==0,"discarded record is cleared")
	check(not game._record("longest_drive",320,false,"TOMMY","320 yd drive"),"retry is ineligible for drive record")
	game.players[0].scores=[3,3,3,3,3,3,3,3,3]
	game._check_round_records()
	check(game.leaderboard.front_nine.value==999,"assisted round excluded from course record")
	opening_round(1)
	game.shoot(0.3); simulate()
	game._record("longest_drive",310,false,"TOMMY","310 yd drive")
	game.advance_turn()
	check(game.leaderboard.longest_drive.value==310,"kept opening record commits")
	# Replayed hole-out: retry must undo the done flag and discard the pending ace.
	opening_round(1)
	game.shoot(0.3); simulate(); game._sink()
	check(game.leaderboard.hole_in_ones.value==0,"opening ace waits for decision")
	game.qa_mode=false
	game.trail=[game.course.tee,game.course.tee+Vector3(0,10,-20),game.course.tee+Vector3(0,20,-40),game.course.pin+Vector3(0,2,2),game.course.pin]
	game._begin_replay("HOLE IN ONE")
	check(game.state=="replay","opening hole-out uses existing replay")
	press(KEY_ENTER)
	check(game.can_take_breakfast_ball(),"skipping replay retains opening decision")
	game.take_breakfast_ball()
	check(not game.players[0].done and game.ball.visible,"retry from hole-out restores playable ball")
	check(game.leaderboard.hole_in_ones.value==0,"discarded ace never recorded")
	game.qa_mode=true; game.records_enabled=false
	# Challenge entry, one-shot rule, misses, and a complete physical 4-player journey.
	game.hud._action("mode:2"); game.hud._action("players:1")
	check(game.mode==2,"solo selection preserves challenge mode")
	game.player_count=4; game.round_length=18; game.start_round()
	check(game.round_length==3 and game.round_holes==[5,11,15],"challenge locks three par-3 holes")
	for hole in range(3):
		var shared_wind: Vector2=game.wind
		for golfer in range(4):
			check(game.player_index==golfer and game.state=="aim","each challenge golfer gets a tee shot")
			check(game.wind==shared_wind,"all golfers share wind on the same hole")
			game.shoot(0.85 if golfer==0 else 0.95 if golfer==1 else 1.0 if golfer==2 else 0.05)
			simulate()
			check(game.players[golfer].done and game.state=="result","one shot ends challenge turn")
			check(not game.can_take_breakfast_ball(),"challenge offers no mulligan")
			var shot: Dictionary=game.players[golfer].challenge_shot
			check(shot.points>=0 and shot.points<=100,"challenge points bounded")
			print("CHALLENGE_SHOT hole=%d player=%d feet=%.1f valid=%s points=%d"%[game.hole_index+1,golfer+1,shot.feet,shot.valid,shot.points])
			game.advance_turn()
		check(game.state=="scorecard" and game.hole_done,"all attempts produce scorecard")
		for p in game.players: check(p.scores.size()==hole+1 and p.challenge_results.size()==hole+1,"challenge score stored exactly once")
		game.advance_turn()
		check(game.players[0].scores.size()==hole+1,"extra continue cannot duplicate scores")
		game.next_hole()
	check(game.state=="finished","full challenge reaches final results")
	game.hud._action("retrychallenge")
	check(game.state=="aim" and game.players[0].scores.is_empty(),"Another Serving resets round")
	press(KEY_TAB)
	check(game.state=="scorecard" and not game.hole_done,"challenge card opens before shooting")
	press(KEY_ENTER)
	check(game.state=="aim" and game.round_position==0,"unfinished challenge card returns to same shot")
	# Known lies verify scoring independently of tee-shot accuracy.
	game.ball_pos=game.course.pin+Vector3(0,0,3.048)
	game._finish_challenge_shot()
	check(game.players[0].challenge_shot.valid and game.players[0].challenge_shot.points==90,"ten-foot green finish scores ninety")
	game.qa_mode=false
	game.trail=[game.course.tee,game.course.tee+Vector3(0,10,-20),game.course.tee+Vector3(0,20,-40),game.ball_pos+Vector3(0,2,2),game.ball_pos]
	game._begin_replay("PIN SEEKER")
	game._process(game.replay_duration)
	check(game.state=="result" and game.ball.visible,"natural challenge replay return preserves unholed ball")
	game._begin_replay("PIN SEEKER"); press(KEY_ENTER)
	check(game.state=="result" and game.ball.visible,"skipped challenge replay preserves unholed ball")
	game.qa_mode=true
	game.ball_pos=game.course.pin; game._sink()
	check(game.players[0].challenge_shot.points==100 and game.players[0].challenge_shot.holed,"challenge hole-out scores one hundred")
	game.ball_pos=game.course.tee; game._finish_challenge_shot()
	check(game.players[0].challenge_shot.points==0 and not game.players[0].challenge_shot.valid,"missed green scores zero")
	game._penalty("WATER")
	check(game.players[0].challenge_shot.points==0 and game.players[0].done,"water ends challenge with zero")
	game.records_enabled=true
	var book: Dictionary=game.leaderboard.duplicate(true)
	game._count_hole_in_one("TOMMY"); game._record("longest_drive",999,false,"TOMMY","test"); game._check_round_records()
	check(game.leaderboard==book,"challenge cannot alter stroke-play records")
	game.players[0].scores=[10,20,30]; game.players[1].scores=[30,20,10]
	game.players[2].scores=[0,0,0]; game.players[3].scores=[0,0,0]
	check("share the win" in game.winners_text(),"tied challenge leaders share win")
	game.players[1].scores=[100,100,100]
	check(game.players[1].tag+" wins" in game.winners_text(),"highest challenge total wins")
	game.mode=0; game.player_count=1; game.start_round()
	check(game.players[0].scores.is_empty() and not game.players[0].breakfast_used,"new normal round resets feature state")
	print("BREAKFAST_CHALLENGE_TESTS: %d checks, %d failures"%[checks,failures])
	await process_frame
	game.free()
	quit(1 if failures else 0)
