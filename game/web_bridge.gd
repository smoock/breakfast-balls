extends Node

# Observability remains detached and read-only. The separate room bridge accepts
# only the typed messages handled by OnlineSession; it exports no game object.
const PUBLISH_INTERVAL: float=0.25
var game: Node
var elapsed: float=0.0
var browser_window: JavaScriptObject
var browser_document: JavaScriptObject
var browser_canvas: JavaScriptObject
var blur_callback: JavaScriptObject
var visibility_callback: JavaScriptObject
var online_callback: JavaScriptObject
var online_browser: JavaScriptObject

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	browser_window=JavaScriptBridge.get_interface("window")
	browser_document=JavaScriptBridge.get_interface("document")
	browser_canvas=browser_document.getElementById("canvas")
	# Hold callback references for the node's lifetime. Browser focus changes are
	# not consistently forwarded as Godot application notifications.
	blur_callback=JavaScriptBridge.create_callback(_on_blur)
	visibility_callback=JavaScriptBridge.create_callback(_on_visibility_change)
	# Capture focus changes before regular page handlers can synthesize releases.
	browser_window.addEventListener("blur",blur_callback,true)
	browser_document.addEventListener("visibilitychange",visibility_callback,true)
	if browser_canvas!=null: browser_canvas.addEventListener("blur",blur_callback,true)
	online_browser=JavaScriptBridge.get_interface("BreakfastOnline")
	if online_browser!=null:
		online_callback=JavaScriptBridge.create_callback(_on_online_message)
		game.online.outbound.connect(_send_online_message)
		online_browser.ready(online_callback)
	_publish()

func _on_online_message(arguments: Array) -> void:
	if arguments.size()!=1 or not arguments[0] is String: return
	game.online.receive(arguments[0])
	_publish()

func _send_online_message(payload: String) -> void:
	if online_browser!=null: online_browser.emit(payload)

func _on_blur(_arguments: Array) -> void:
	game.pause_play(true)
	_publish()

func _on_visibility_change(_arguments: Array) -> void:
	if browser_document.hidden:
		game.pause_play(true)
		_publish()

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed<PUBLISH_INTERVAL: return
	elapsed=fmod(elapsed,PUBLISH_INTERVAL)
	_publish()

static func snapshot(source: Node) -> Dictionary:
	var strokes: Array=[]
	var done: Array=[]
	var scores: Array=[]
	var tags: Array=[]
	for player in source.players:
		strokes.append(int(player.strokes))
		done.append(bool(player.done))
		scores.append(player.scores.duplicate())
		tags.append(str(player.tag))
	return {
		"schema_version":1,
		"state":source.state,"previous_state":source.previous_state,
		"ball":{"x":source.ball_pos.x,"y":source.ball_pos.y,"z":source.ball_pos.z},
		"practice_active":source.practice_active,"practice_station":source.practice_station,
		"player_count":source.player_count,"player_index":source.player_index,
		"strokes":strokes[source.player_index] if source.player_index<strokes.size() else 0,
		"player_strokes":strokes,"player_done":done,
		"player_scores":scores,"player_tags":tags,
		"online_active":source.online.active,"online_seat":source.online.seat,
		"online_can_act":source.online.can_control(),"online_pending":source.online.pending,
		"online_revision":source.online.revision,
		"hole_index":source.hole_index,"hole_number":source.hole_index+1,
		"round_position":source.round_position,"round_length":source.round_length,
		"mode":source.mode,"club":source.club,"charge":source.charge,
		"swing_power":source.swing_power(),"keyboard_charge":source.keyboard_charge,
		"dragging":source.dragging,"aiming_drag":source.aiming_drag,
		"input_style":source.input_style,"settings_open":source.settings_open,
		"help_open":source.help_open,"focus_paused":source.focus_paused,
		"breakfast_offer":source.breakfast_offer,"sound_enabled":source.sound_enabled,
		"performance":{
			"fps":Engine.get_frames_per_second(),
			"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		}
	}

func _publish() -> void:
	if not OS.has_feature("web"): return
	var payload: String=JSON.stringify(snapshot(game))
	JavaScriptBridge.eval("""(() => {
		const freeze = value => {
			if (value && typeof value === 'object') {
				Object.values(value).forEach(freeze);
				Object.freeze(value);
			}
			return value;
		};
		const snapshot = freeze(%s);
		Object.defineProperty(window, '__breakfastBallsState', {
			get: () => snapshot, configurable: true, enumerable: true
		});
	})();"""%payload,true)

func _exit_tree() -> void:
	if browser_window!=null: browser_window.removeEventListener("blur",blur_callback,true)
	if browser_document!=null: browser_document.removeEventListener("visibilitychange",visibility_callback,true)
	if browser_canvas!=null: browser_canvas.removeEventListener("blur",blur_callback,true)
