extends SceneTree

const Main=preload("res://game/main.gd")
const Online=preload("res://game/online_session.gd")
const Bridge=preload("res://game/web_bridge.gd")
var host: Node3D
var guest: Node3D
var host_messages: Array=[]
var guest_messages: Array=[]
var checks: int=0
var failures: int=0
var revision: int=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+label)

func build_game() -> Node3D:
	var game=Main.new()
	game.sound_enabled=false; game.records_enabled=true
	game.preferences_path=OS.get_cache_dir()+"/breakfast-online-preferences.cfg"
	game.leaderboard_path=OS.get_cache_dir()+"/breakfast-online-records.json"
	root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.qa_mode=true; game.qa_step=1
	return game

func key(game: Node,code: Key,pressed: bool=true) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.pressed=pressed
	game._input(event)

func commit(sender: Node,receiver: Node,messages: Array) -> Dictionary:
	check(not messages.is_empty(),"transition emitted to room bridge")
	if messages.is_empty(): return {}
	var event: Dictionary=messages.pop_front()
	var snapshot: Dictionary=event.snapshot
	check(Online.valid_snapshot(snapshot),"outgoing snapshot satisfies schema")
	revision+=1
	sender.online.receive(wire({"type":"ack","revision":revision,"canAct":sender.online.seat==snapshot.player_index}))
	receiver.online.receive(wire({"type":"apply","seat":1 if sender==host else 0,"revision":revision,"snapshot":snapshot,"canAct":(1 if sender==host else 0)==int(snapshot.player_index)}))
	return event

func simulate(game: Node) -> void:
	for frame in range(2400):
		if game.state!="flight": return
		game._physics_process(1.0/60.0)
	check(false,"shot physically settles")

func wire(value) -> String:
	return JSON.stringify(value,"",false,true)

func same_round() -> bool:
	return same_value(host.online.snapshot(),guest.online.snapshot())

func same_value(a,b) -> bool:
	# JSON can round the last bit of a GDScript double. Scores, indexes, flags
	# and strings must still match exactly; only float scalars get tolerance.
	if typeof(a)!=typeof(b): return false
	if a is float: return absf(a-b)<=1e-9*maxf(1.0,maxf(absf(a),absf(b)))
	if a is Array:
		if a.size()!=b.size(): return false
		for index in range(a.size()):
			if not same_value(a[index],b[index]): return false
		return true
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for field in a:
			if not b.has(field) or not same_value(a[field],b[field]): return false
		return true
	return a==b

func run() -> void:
	host=build_game(); guest=build_game()
	host.online.outbound.connect(func(payload: String): host_messages.append(JSON.parse_string(payload)))
	guest.online.outbound.connect(func(payload: String): guest_messages.append(JSON.parse_string(payload)))
	# Offline behavior remains the same before a room is entered.
	host.player_count=1; host.start_round(); host.shoot(0.3)
	host.pause_play(true)
	var offline_ball: Vector3=host.ball_pos
	host._physics_process(1.0)
	check(host.state=="pause" and host.ball_pos==offline_ball and not host.online.active,"offline flight still pauses on focus loss")
	host.return_to_menu()
	host.online.receive(wire({"type":"start","seat":0,"seats":[{"name":"ALPHA","golfer":7},{"name":"BRAVO","golfer":6}],"config":{"mode":0,"holes":3,"nine":0,"tees":1}}))
	check(host.online.active and host.online.pending and host.players.size()==2 and not host.records_enabled,"room starts with records disabled and acceptance pending")
	check(host.players[0].golfer==7 and host.players[1].golfer==6,"online roster preserves all eight golfers")
	host.shoot(0.4)
	check(host.state=="aim" and host.players[0].strokes==0,"host cannot shoot before start acknowledgment")
	var started: Dictionary=commit(host,guest,host_messages)
	check(started.action=="start" and same_round(),"start snapshot restores identical round and shuffled holes")
	check(host.can_control_turn() and not guest.can_control_turn(),"only current seat controls opening turn")
	var before: Dictionary=guest.online.snapshot()
	guest.shoot(0.8); guest.select_club(13); guest.set_shot_style(2)
	guest.hud._action("spin"); guest.hud._action("selectclub:13")
	guest.hud._action("card"); guest.hud._action("menu"); guest.hud._action("practice")
	guest.start_practice(); guest.begin_name_entry(); guest.return_to_menu()
	key(guest,KEY_SPACE); guest._process(0.7); key(guest,KEY_SPACE,false)
	Input.action_press("ui_left"); guest._process(0.2); Input.action_release("ui_left")
	var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT
	click.position=Vector2(1100,630); click.pressed=true; guest._input(click)
	click.pressed=false; guest._input(click)
	check(guest.online.snapshot()==before and not guest.keyboard_charge and not guest.dragging,"spectator keyboard, mouse, HUD and direct methods cannot change shared state")
	guest.hud._action("help"); guest.hud._action("overview")
	check(guest.help_open and guest.overview and guest.state=="aim","spectator help and flyover stay local")
	guest.hud._action("closehelp"); guest.overview=false
	host.select_club(0); host.spin=1; host.aim+=0.12
	host.shoot(0.47,0.2,-0.1)
	check(host.online.pending and host.state=="flight" and host.players[0].strokes==1,"local swing creates one pending flight")
	var flight_start: Dictionary=host.online.snapshot()
	host._physics_process(0.5)
	check(host.online.snapshot()==flight_start,"flight physics waits for room acceptance")
	var shot: Dictionary=commit(host,guest,host_messages)
	check(shot.action=="shot" and same_round(),"accepted flight roundtrips physics and presentation fields")
	host.pause_play(true); guest.pause_play(true)
	check(host.state=="flight" and guest.state=="flight" and not host.focus_paused,"online focus loss does not pause a committed shot")
	host._physics_process(1.0/60.0); guest._physics_process(1.0/60.0)
	check(host.ball_pos.distance_to(guest.ball_pos)<0.0001 and host.velocity.distance_to(guest.velocity)<0.0001,"spectator begins the same physical shot")
	simulate(host); simulate(guest)
	host.advance_turn()
	check(host.state=="result" and host.player_index==0 and host_messages.is_empty(),"owner cannot continue before deferred settlement is submitted")
	await process_frame
	check(host.state=="result" and guest.state=="result" and host_messages.size()==1 and guest_messages.is_empty(),"only owner publishes one deferred settlement")
	var settled: Dictionary=commit(host,guest,host_messages)
	check(settled.action=="settle" and same_round(),"settlement reconciles exact scores and final lie")
	guest.advance_turn(); guest.take_breakfast_ball(); guest.next_hole()
	check(same_round() and guest_messages.is_empty(),"spectator cannot continue, mulligan or advance hole")
	host.take_breakfast_ball()
	var breakfast: Dictionary=commit(host,guest,host_messages)
	check(breakfast.action=="breakfast" and same_round() and host.players[0].breakfast_used and host.players[0].strokes==0,"breakfast ball synchronizes its one-use reset")
	host.shoot(0.1); commit(host,guest,host_messages); simulate(host)
	await process_frame
	commit(host,guest,host_messages)
	host.advance_turn()
	var advanced: Dictionary=commit(host,guest,host_messages)
	check(advanced.action=="advance" and same_round() and guest.can_control_turn() and not host.can_control_turn(),"advance transfers control to the other computer")
	var obs: Dictionary=Bridge.snapshot(guest)
	check(obs.online_active and obs.online_seat==1 and obs.online_can_act and obs.online_revision==revision,"inspection snapshot exposes room ownership and revision")
	check(obs.player_tags==["ALPHA","BRAVO"] and obs.player_scores==[[],[]],"inspection snapshot exposes detached names and scorecards")
	obs.player_scores[0].append(999)
	check(guest.players[0].scores.is_empty(),"inspection scores cannot mutate the game")
	# A stale response must not roll a reconnected player back to an earlier turn.
	var current: Dictionary=guest.online.snapshot()
	guest.online.receive(wire({"type":"apply","seat":1,"revision":1,"canAct":false,"snapshot":started.snapshot}))
	check(guest.online.snapshot()==current and guest.can_control_turn(),"stale room snapshot cannot roll back revision")
	guest.online.receive(wire({"type":"lock"}))
	guest.shoot(0.4)
	check(guest.online.pending and guest.state=="aim","network lock blocks stale gameplay")
	guest.online.receive(wire({"type":"apply","seat":1,"revision":revision,"canAct":true,"snapshot":current}))
	check(not guest.online.pending and guest.can_control_turn(),"canonical resync clears a rejected optimistic action")
	var malformed: Dictionary=current.duplicate(true); malformed.ball_pos=[1,2]
	check(not Online.valid_snapshot(malformed),"malformed vectors are rejected")
	malformed=current.duplicate(true); malformed.players[0].golfer=8
	check(not Online.valid_snapshot(malformed),"unknown golfer rejected")
	# Shared scores are finalized exactly once by the current actor at hole end.
	for player in guest.players: player.done=true; player.strokes=4
	guest.state="result"; guest.advance_turn()
	commit(guest,host,guest_messages)
	check(same_round() and host.state=="scorecard" and host.players[0].scores==[4],"hole completion synchronizes scorecard")
	host.next_hole()
	check(host.state=="scorecard" and host_messages.is_empty(),"only current golfer can move a completed scorecard")
	guest.next_hole(); commit(guest,host,guest_messages)
	check(same_round() and host.state=="aim" and host.round_position==1 and host.can_control_turn(),"next tee resets hole and transfers control to first golfer")
	host._begin_replay("TEST")
	check(host.state=="aim","online replay cannot mutate canonical ball position")
	host.online.receive(wire({"type":"leave"})); guest.online.receive(wire({"type":"leave"}))
	check(not host.online.active and host.records_enabled and host.state=="menu" and not guest.online.active,"leave restores local records and clubhouse")
	host.start_practice(); host.shoot(0.3)
	check(host.practice_active and host.state=="flight" and host_messages.is_empty(),"offline practice remains playable after leaving")
	host.free(); guest.free()
	print("ONLINE_GAME_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
