extends RefCounted

# The room service authorizes each transition. Ball physics stays in the acting
# browser; spectators replay accepted flight state and reconcile its final lie.
signal outbound(payload: String)

const VERSION: int=1
const Data=preload("res://game/data.gd")
const PHASES: Array=["aim","flight","result","scorecard","finished"]
const SCALARS: Array=[
	"state","player_count","player_index","mode","round_length","nine_side",
	"round_position","hole_index","round_tees","skin_pot","hole_done","hole_message",
	"club","spin","shot_style","aim","breakfast_offer","result_title","result_detail",
	"last_shot","shot_range","shot_distance","shot_carry","shot_roll","shot_landed",
	"shot_face","shot_start_angle","shot_quality","shot_shape","in_air","bounced",
	"shot_time","swing_elapsed","impact_pending","curve_rate","flight_gravity"
]
const VECTORS: Array=["ball_pos","last_safe","shot_origin","velocity"]

var game: Node
var active: bool=false
var seat: int=-1
var revision: int=-1
var can_act: bool=false
var pending: bool=false
var applying: bool=false
var settle_queued: bool=false
var saved_records_enabled: bool=true
var saved_setup: Dictionary={}

func can_control() -> bool:
	return not active or (can_act and not pending and not settle_queued and seat==game.player_index)

func _enter(local_seat: int) -> void:
	if not active:
		saved_records_enabled=game.records_enabled
		saved_setup={"player_tags":game.player_tags.duplicate(),"roster":game.roster.duplicate(),"player_count":game.player_count,"mode":game.mode,"round_length":game.round_length,"nine_side":game.nine_side,"tees":game.tees}
	active=true; seat=local_seat
	game.records_enabled=false; game.practice_active=false; game.practice_settings.clear()
	game.remote_timing_enabled=false; game.focus_paused=false
	game.settings_open=false; game.parsec_setup_open=false

func receive(payload: String) -> void:
	var message=JSON.parse_string(payload)
	if not message is Dictionary: return
	match str(message.get("type","")):
		"start": _start(message)
		"apply":
			var data=message.get("snapshot")
			if not data is Dictionary or not valid_snapshot(data): return
			var incoming_revision: int=int(message.get("revision",0))
			if active and incoming_revision<revision: return
			_enter(clampi(int(message.get("seat",-1)),-1,3))
			revision=incoming_revision
			can_act=bool(message.get("canAct",false)); pending=false
			apply_snapshot(data)
		"ack":
			if not active: return
			var incoming_revision: int=int(message.get("revision",0))
			if incoming_revision<revision: return
			revision=incoming_revision; can_act=bool(message.get("canAct",false)); pending=false
		"lock":
			if active:
				pending=true
				game.cancel_swing_input()
		"leave": leave()

func _start(message: Dictionary) -> void:
	var seats=message.get("seats",[])
	var config=message.get("config",{})
	if not seats is Array or seats.size()<2 or seats.size()>4 or not config is Dictionary: return
	for entry in seats:
		if not entry is Dictionary: return
	_enter(clampi(int(message.get("seat",0)),0,seats.size()-1))
	applying=true
	game.player_count=seats.size()
	game.mode=clampi(int(config.get("mode",0)),0,2)
	game.round_length=int(config.get("holes",3))
	if not game.round_length in [3,9,18]: game.round_length=3
	game.nine_side=clampi(int(config.get("nine",0)),0,1)
	game.tees=clampi(int(config.get("tees",0)),0,1)
	for index in range(seats.size()):
		game.player_tags[index]=str(seats[index].get("name","GOLFER")).strip_edges().to_upper().left(5)
		game.roster[index]=clampi(int(seats[index].get("golfer",index)),0,Data.GOLFERS.size()-1)
	game.help_open=false
	game.start_round()
	applying=false; revision=-1; can_act=true; pending=false
	publish("start")

func leave() -> void:
	if not active: return
	active=false; can_act=false; pending=false; seat=-1; revision=-1; settle_queued=false
	game.records_enabled=saved_records_enabled
	for field in saved_setup: game.set(field,saved_setup[field])
	saved_setup.clear()
	game.return_to_menu()

func publish(action: String) -> void:
	if not active or applying or pending: return
	# Start belongs to the lobby host; all subsequent actions belong to the
	# currently active golfer (advance may already have selected the next one).
	if action!="start" and not can_act: return
	pending=true
	game.cancel_swing_input()
	outbound.emit(JSON.stringify({"action":action,"snapshot":snapshot()},"",false,true))

func queue_settle() -> void:
	if not active or not can_control() or settle_queued: return
	settle_queued=true
	_publish_settle.call_deferred()

func _publish_settle() -> void:
	settle_queued=false
	if active and can_control() and game.state=="result": publish("settle")

func snapshot() -> Dictionary:
	var result: Dictionary={"schema_version":VERSION,"round_holes":game.round_holes.duplicate(),"players":[],"ball_visible":game.ball.visible,"wind":[game.wind.x,game.wind.y],"tree_hits":[]}
	for field in SCALARS: result[field]=game.get(field)
	for field in VECTORS: result[field]=_vector_array(game.get(field))
	for player in game.players:
		var entry: Dictionary=player.duplicate(true)
		entry.pos=_vector_array(player.pos)
		result.players.append(entry)
	for index in game.tree_hits:
		if result.tree_hits.size()>=256: break
		result.tree_hits.append(int(index))
	return result

static func _vector_array(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

static func _finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_vector(value,dimensions: int=3) -> bool:
	if not value is Array or value.size()!=dimensions: return false
	for component in value:
		if not _finite_number(component) or absf(float(component))>100000: return false
	return true

static func valid_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema_version",0))!=VERSION or not data.get("state","") in PHASES: return false
	var count: int=int(data.get("player_count",0))
	var index: int=int(data.get("player_index",-1))
	var players=data.get("players")
	var holes=data.get("round_holes")
	if count<2 or count>4 or index<0 or index>=count: return false
	if not players is Array or players.size()!=count: return false
	if not holes is Array or not holes.size() in [3,9,18]: return false
	for hole in holes:
		if not _finite_number(hole) or int(hole)<0 or int(hole)>17: return false
	var position: int=int(data.get("round_position",-1))
	if position<0 or position>=holes.size() or int(data.get("hole_index",-1))!=int(holes[position]): return false
	if int(data.get("round_length",0))!=holes.size(): return false
	for field in VECTORS:
		if not _valid_vector(data.get(field)): return false
	if not _valid_vector(data.get("wind"),2): return false
	if int(data.get("club",-1))<0 or int(data.get("club",-1))>13: return false
	if int(data.get("mode",-1))<0 or int(data.get("mode",-1))>2: return false
	if int(data.get("round_tees",-1))<0 or int(data.get("round_tees",-1))>1: return false
	for player in players:
		if not player is Dictionary or not _valid_vector(player.get("pos")): return false
		if not player.get("scores") is Array or player.scores.size()>18: return false
		if int(player.get("golfer",-1))<0 or int(player.get("golfer",-1))>=Data.GOLFERS.size(): return false
		if not player.get("tag") is String or player.tag.length()>5: return false
		if not player.get("challenge_results") is Array or player.challenge_results.size()>3: return false
		if not player.get("challenge_shot") is Dictionary: return false
		for score in player.scores:
			if not _finite_number(score): return false
	return true

func apply_snapshot(data: Dictionary) -> void:
	if not valid_snapshot(data): return
	applying=true
	var rebuild: bool=game.hole_index!=int(data.hole_index) or game.round_tees!=int(data.round_tees) or game.players.is_empty() or game.state=="menu"
	for field in SCALARS:
		if not data.has(field): continue
		var current=game.get(field)
		var value=data[field]
		if current is int and _finite_number(value): game.set(field,int(value))
		elif current is float and _finite_number(value): game.set(field,float(value))
		elif current is bool and value is bool: game.set(field,value)
		elif current is String and value is String: game.set(field,value.left(512))
	game.round_holes=[]
	for value in data.round_holes: game.round_holes.append(int(value))
	game.players=[]
	for entry in data.players:
		var player: Dictionary=entry.duplicate(true)
		player.pos=Vector3(float(entry.pos[0]),float(entry.pos[1]),float(entry.pos[2]))
		for field in ["golfer","strokes","skins"]: player[field]=int(player.get(field,0))
		for index in range(player.scores.size()): player.scores[index]=int(player.scores[index])
		for result in player.challenge_results:
			if result is Dictionary and result.has("points"): result.points=int(result.points)
		if player.challenge_shot.has("points"): player.challenge_shot.points=int(player.challenge_shot.points)
		player.done=bool(player.get("done",false)); player.breakfast_used=bool(player.get("breakfast_used",false))
		game.players.append(player)
	if rebuild: game.course.build(game.hole_index,game.round_tees)
	for field in VECTORS:
		var value: Array=data[field]
		game.set(field,Vector3(float(value[0]),float(value[1]),float(value[2])))
	game.wind=Vector2(float(data.wind[0]),float(data.wind[1]))
	game.tree_hits.clear()
	var hits=data.get("tree_hits",[])
	if hits is Array:
		for index in hits.slice(0,256):
			if _finite_number(index) and int(index)>=0 and int(index)<game.course.trees.size(): game.tree_hits[int(index)]=true
	game.ball.position=game.ball_pos; game.ball.visible=bool(data.get("ball_visible",true))
	game.cancel_swing_input(); game.focus_paused=false; game.overview=false
	game.pending_shot_records.clear(); game.record_notice=""; game.replay_path.clear()
	game.trail.clear(); game.trail_tick=0.0; game.result_time=0.0
	if game.state=="flight": game.trail.append(game.shot_origin)
	game._draw_trail(); game._build_golfer(); game._align_golfer(); game._update_marker(); game._update_camera(1.0,true)
	game.hud.queue_redraw()
	applying=false
