extends Control

const Data=preload("res://game/data.gd")
const INK=Color("173d33")
const CREAM=Color("f5efd9")
const GOLD=Color("eec66c")
const MUTED=Color("a8bdb0")
var game: Node
var font: Font=ThemeDB.fallback_font
var bold:=SystemFont.new()
var serif:=SystemFont.new()
var buttons: Array=[]
var swing_rect:=Rect2(958,594,286,160)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	bold.font_names=PackedStringArray(["Avenir Next","Noto Sans"]); bold.font_weight=700
	serif.font_names=PackedStringArray(["Georgia","Noto Serif"]); serif.font_weight=700

func panel(r: Rect2,c: Color,radius: int=14,border: Color=Color.TRANSPARENT) -> void:
	var s:=StyleBoxFlat.new(); s.bg_color=c
	s.set_corner_radius_all(radius)
	if border.a>0: s.set_border_width_all(1); s.border_color=border
	draw_style_box(s,r)

func text(at: Vector2,s: String,size: int=16,c: Color=CREAM,f: Font=null) -> void:
	draw_string(font if f==null else f,at,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)

func center(r: Rect2,s: String,size: int=16,c: Color=CREAM,f: Font=null) -> void:
	var ff: Font=font if f==null else f
	var width: float=ff.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text(Vector2(r.get_center().x-width/2,r.get_center().y+size*0.34),s,size,c,ff)

func button(r: Rect2,s: String,action: String,selected: bool=false,primary: bool=false) -> void:
	var hover: bool=r.has_point(get_global_mouse_position())
	var col: Color=GOLD if primary or selected else Color("285046")
	if hover: col=col.lightened(0.09)
	panel(r,col,9,Color("557366") if not primary else Color.TRANSPARENT)
	center(r,s,16,INK if primary or selected else CREAM,bold)
	buttons.append([r,action])

func _draw() -> void:
	if game==null: return
	buttons.clear()
	if game.state in ["menu","name_entry","leaderboard","calibration"]: _menu()
	else: _game_hud()
	if game.state=="name_entry": _name_entry()
	if game.state=="calibration": _calibration()
	if game.state=="leaderboard": _leaderboard()
	if game.state=="replay": _replay_overlay()
	if game.state=="result": _result()
	if game.state in ["scorecard","finished"]: _scorecard()
	if game.state=="pause": _pause()
	if game.settings_open: _settings()
	if game.help_open: _help()
	if game.parsec_setup_open: _parsec_setup()

func _menu() -> void:
	# A clubhouse scorecard laid over a moving course vista.
	draw_rect(Rect2(0,0,472,800),INK)
	draw_rect(Rect2(472,0,4,800),GOLD)
	text(Vector2(38,43),"THE EARLY BIRD GOLF CLUB",13,GOLD,bold)
	text(Vector2(32,116),"Breakfast",58,CREAM,serif)
	text(Vector2(32,179),"Balls.",72,CREAM,serif)
	draw_line(Vector2(38,204),Vector2(434,204),Color("527160"),1)
	text(Vector2(38,237),"Good swings. Bad puns. Great mornings.",17,CREAM)
	text(Vector2(38,273),"YOUR FOURSOME",12,GOLD,bold)
	for i in range(4): button(Rect2(38+i*100,287,91,38),str(i+1)+(" player" if i==0 else " players"),"players:%d"%(i+1),game.player_count==i+1)
	text(Vector2(38,357),"THE GAME",12,GOLD,bold)
	button(Rect2(38,371,126,41),"Stroke Play","mode:0",game.mode==0)
	button(Rect2(173,371,126,41),"Skins","mode:1",game.mode==1)
	button(Rect2(308,371,129,41),"Pin Challenge","mode:2",game.mode==2)
	text(Vector2(38,435),"Closest to pin · One shot. Make it count." if game.mode==2 else "Lowest total wins." if game.mode==0 else "Win the hole. Ties carry the skin.",14,MUTED)
	text(Vector2(38,470),"MAKE A MORNING OF IT",12,GOLD,bold)
	if game.mode==2:
		panel(Rect2(38,484,399,44),Color("285046"),9)
		center(Rect2(38,484,399,44),"3 PAR-3s  ·  HOLES 6 / 12 / 16",16,GOLD,bold)
		text(Vector2(38,554),"1–4 players · Highest total wins · 300 max",13,MUTED)
	else:
		for i in range(3):
			var holes: int=[3,9,18][i]
			button(Rect2(38+i*135,484,126,40),str(holes)+" holes","holes:%d"%holes,game.round_length==holes)
	if game.mode!=2 and game.round_length==9:
		button(Rect2(38,535,194,28),"FRONT 9 · 1–9","nine:0",game.nine_side==0)
		button(Rect2(243,535,194,28),"BACK 9 · 10–18","nine:1",game.nine_side==1)
	elif game.mode!=2: text(Vector2(38,554),"3 random holes · A fresh trio every round" if game.round_length==3 else "The full course · All 18 holes",13,MUTED)
	button(Rect2(38,574,399,60),"LET'S PLAY GOLF    →","play",false,true)
	button(Rect2(38,649,126,40),"How to swing","help")
	button(Rect2(174,649,126,40),"Leaderboard","leaderboard")
	button(Rect2(310,649,127,40),"Settings","settings")
	button(Rect2(38,704,399,44),"Short-game practice","practice")
	panel(Rect2(502,25,745,56),Color(0.06,0.19,0.15,0.84),12)
	text(Vector2(522,48),"MAGNOLIA PINES",17,CREAM,bold)
	text(Vector2(522,68),"18 original holes · Augusta-inspired southern golf",12,Color("d4e0bf"))
	center(Rect2(1125,29,103,44),"PAR 72",16,GOLD,bold)
	panel(Rect2(504,111,740,479),Color(0.065,0.19,0.15,0.94),16)
	text(Vector2(526,143),"PICK YOUR ALTER EGO",13,GOLD,bold)
	for i in range(game.player_count):
		button(Rect2(526+i*170,158,160,33),"P%d  %s"%[i+1,Data.GOLFERS[game.roster[i]][0].split(" ")[0]],"slot:%d"%i,game.active_slot==i)
	for i in range(8):
		var x: float=526+(i%4)*175
		var y: float=205+int(i/4)*182
		var r:=Rect2(x,y,162,174)
		var selected: bool=game.roster[game.active_slot]==i
		panel(r,Color("37624f") if selected else Color("21473b"),10,GOLD if selected else Color("436350"))
		_avatar(Vector2(x+81,y+61),Color(Data.GOLFERS[i][2]),1.65,i)
		if selected: text(Vector2(x+120,y+25),"P%d"%(game.active_slot+1),13,GOLD,bold)
		var name: Array=Data.GOLFERS[i][0].split(" ")
		text(Vector2(x+12,y+139),name[0],15,CREAM,bold)
		text(Vector2(x+12,y+160),name[1],15,CREAM,bold)
		buttons.append([r,"golfer:%d"%i])

	panel(Rect2(504,614,740,159),Color(0.065,0.19,0.15,0.92),16)
	text(Vector2(526,645),"DINER SPECIAL · CLOSEST TO PIN" if game.mode==2 else "FIRST TEE SPECIAL · THE BREAKFAST BALL",13,GOLD,bold)
	text(Vector2(526,679),"Three pins. Three swings. Bragging rights." if game.mode==2 else "Bad opening shot? Order a fresh start.",23,CREAM,serif)
	text(Vector2(526,708),"Hole out for 100 points; otherwise lose 1 per foot, rounded up." if game.mode==2 else "Each golfer may replay their opening tee shot once. Press B at the result.",14,MUTED)
	text(Vector2(526,734),"Missed green: 0. Same wind for everyone. No Breakfast Balls." if game.mode==2 else "Using it clears the shot + penalty and makes your round ineligible for records.",14,MUTED)

func _settings() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.78))
	panel(Rect2(270,76,740,650),CREAM,18)
	text(Vector2(306,115),"CLUBHOUSE SETTINGS",12,Color("647454"),bold)
	text(Vector2(306,165),"Make it your game.",34,INK,serif)
	text(Vector2(306,205),"SWING INPUT",12,INK,bold)
	button(Rect2(306,219,250,40),"Keyboard","input:0",game.input_style==0)
	button(Rect2(568,219,406,40),"Mouse & Trackpad","input:1",game.input_style==1)
	text(Vector2(306,298),"TEES",12,INK,bold)
	if game.mode==2:
		text(Vector2(306,336),"Pin Challenge always uses championship tees.",16,INK)
	else:
		button(Rect2(306,310,328,40),"Championship","tees:0",game.tees==0)
		button(Rect2(646,310,328,40),"Club tees","tees:1",game.tees==1)
	text(Vector2(306,375),"Club tees shorten holes 3, 5, 7 & 14. Each setup has its own record book.",13,Color("647454"))
	draw_line(Vector2(306,397),Vector2(974,397),Color("d4d0ba"),1)
	text(Vector2(306,430),"SOUND",12,INK,bold)
	button(Rect2(720,407,254,40),"Sound: "+("on" if game.sound_enabled else "off"),"sound",game.sound_enabled)
	text(Vector2(306,483),"PLAY WITH FRIENDS",12,INK,bold)
	button(Rect2(306,497,328,42),"Parsec remote play","parsec")
	button(Rect2(646,497,328,42),"Guest timing: "+("on" if game.remote_timing_enabled else "off"),"remote",game.remote_timing_enabled)
	text(Vector2(306,566),"Parsec shares your game with guests. Enable timing to calibrate their swings.",13,Color("647454"))
	text(Vector2(306,589),"Choose the player count on the home screen. Player 1 hosts.",13,Color("647454"))
	text(Vector2(306,675),"ESC  Back to clubhouse",12,Color("647454"))
	button(Rect2(714,647,260,44),"DONE","closesettings",false,true)

func _name_entry() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.72))
	panel(Rect2(344,185,592,430),CREAM,18)
	center(Rect2(374,220,532,32),"SIGN THE SCORECARD",12,Color("647454"),bold)
	center(Rect2(374,258,532,54),"Five letters. Make them count.",29,INK,serif)
	center(Rect2(374,317,532,26),"PLAYER %d OF %d"%[game.name_entry_index+1,game.player_count],12,Color("647454"),bold)
	var start_x: float=451
	for i in range(5):
		var r:=Rect2(start_x+i*77,367,62,68)
		panel(r,INK,8,GOLD if i==game.name_entry_value.length() else Color("456354"))
		var letter: String=game.name_entry_value.substr(i,1) if i<game.name_entry_value.length() else ""
		center(r,letter,31,CREAM,bold)
	center(Rect2(390,457,500,25),"Letters only · Backspace edits · Enter confirms",13,Color("647454"))
	button(Rect2(493,511,294,46),"CONTINUE    ↵","confirmname",false,game.name_entry_value.length()==5)
	text(Vector2(372,585),"ESC  Return to clubhouse",12,Color("647454"))

func _calibration() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.78))
	panel(Rect2(300,145,680,510),CREAM,18)
	center(Rect2(335,181,610,30),"REMOTE TIMING CHECK",12,Color("647454"),bold)
	center(Rect2(335,222,610,48),"Hand the controls to %s."%game.player_tags[game.calibration_player],30,INK,serif)
	center(Rect2(350,283,580,24),"Click or release SPACE when the needle reaches the center.",14,Color("647454"))
	center(Rect2(350,313,580,22),"Three passes estimate the guest's end-to-end delay.",12,Color("647454"))
	var meter:=Rect2(390,390,500,54)
	panel(meter,Color("d9c98f"),9)
	draw_rect(Rect2(631,390,18,54),Color("7c9951"))
	draw_line(Vector2(640,382),Vector2(640,452),INK,2,true)
	var needle_x: float=640.0+game.calibration_meter()*270.0
	draw_line(Vector2(needle_x,380),Vector2(needle_x,454),INK,4,true)
	center(Rect2(390,470,500,30),"PASS %d OF 3"%[game.calibration_samples.size()+1],13,INK,bold)
	for i in range(3):
		draw_circle(Vector2(610+i*30,526),8,GOLD if i<game.calibration_samples.size() else Color("c7c3ae"))
	center(Rect2(390,557,500,24),"Player 1 hosts and needs no correction.",12,Color("647454"))
	text(Vector2(335,622),"ESC  Disable remote timing and return to clubhouse",12,Color("647454"))

func _parsec_setup() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.80))
	panel(Rect2(300,120,680,560),CREAM,18)
	center(Rect2(335,156,610,30),"PARSEC REMOTE PLAY",12,Color("647454"),bold)
	center(Rect2(335,197,610,48),"Invite the foursome—no green fees.",29,INK,serif)
	var steps: Array=[
		["01", "Open Parsec and enable Hosting on this computer."],
		["02", "Choose Share in Parsec and send the link to your guests."],
		["03", "Accept each guest, then grant keyboard and mouse access."],
		["04", "Enable Guest timing in Settings; choose players on the home screen."]
	]
	for i in range(steps.size()):
		var y: float=286+i*67
		draw_circle(Vector2(365,y-5),20,GOLD)
		center(Rect2(345,y-25,40,40),steps[i][0],12,INK,bold)
		text(Vector2(402,y),steps[i][1],14,Color("65735c"))
	button(Rect2(390,570,238,46),"OPEN PARSEC","openparsec",false,true)
	button(Rect2(652,570,238,46),"BACK TO SETTINGS" if game.settings_open else "BACK TO CLUBHOUSE","closeparsec")
	center(Rect2(350,634,580,20),"Guests share the active player's mouse or Space-bar swing.",12,Color("647454"))

func _record_line(y: float,label: String,key: String,suffix: String) -> void:
	var record: Dictionary=game.record_book(game.record_tees)[key]
	var empty: bool=str(record.name)=="-----"
	text(Vector2(394,y),label,14,Color("647454"),bold)
	text(Vector2(606,y),str(record.name),18,INK,bold)
	var value: String="—" if empty else ("%d%s"%[roundi(float(record.value)),suffix])
	text(Vector2(757,y),value,18,INK,serif)

func _leaderboard() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.72))
	panel(Rect2(325,132,630,536),CREAM,18)
	center(Rect2(355,169,570,30),"THE MAGNOLIA PINES RECORD BOOK",12,Color("647454"),bold)
	center(Rect2(355,199,570,32),"Local legends live here.",28,INK,serif)
	button(Rect2(394,239,240,28),"Championship","recordtees:0",game.record_tees==0)
	button(Rect2(646,239,240,28),"Club tees","recordtees:1",game.record_tees==1)
	draw_line(Vector2(378,273),Vector2(902,273),Color("c9c5ad"),1)
	_record_line(304,"HOLES IN ONE","hole_in_ones"," total")
	_record_line(354,"LONGEST DRIVE","longest_drive"," yd")
	_record_line(404,"BEST FRONT NINE","front_nine","")
	_record_line(454,"BEST BACK NINE","back_nine","")
	_record_line(504,"BEST COURSE TOTAL","course_total","")
	draw_line(Vector2(378,536),Vector2(902,536),Color("c9c5ad"),1)
	button(Rect2(493,577,294,44),"BACK TO THE CLUBHOUSE","closeleaderboard",false,true)

func _replay_overlay() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,56),Color(0.015,0.05,0.035,0.92))
	draw_rect(Rect2(0,744,1280,56),Color(0.015,0.05,0.035,0.92))
	panel(Rect2(392,91,496,77),Color(0.04,0.15,0.11,0.94),12,GOLD)
	center(Rect2(408,101,464,22),"BREAKFAST BALLS REPLAY",11,GOLD,bold)
	center(Rect2(408,126,464,29),game.replay_title,18,CREAM,bold)
	var count: int=game.replay_path.size()
	if count>1:
		var at: int=clampi(int((game.replay_time/game.replay_duration)*(count-1)),0,count-1)
		for n in range(1,7):
			var index: int=at-n*maxi(1,count/90)
			if index<0: continue
			var p: Vector3=game.replay_path[index]
			if not game.camera.is_position_behind(p):
				var screen: Vector2=game.camera.unproject_position(p)
				draw_circle(screen,7.0-n*0.65,Color(0.94,0.74,0.25,0.38-float(n)*0.045))
	text(Vector2(44,780),"SLOW MOTION · ENTER TO SKIP",12,CREAM,bold)

var portraits: Dictionary={}

func _avatar(at: Vector2,c: Color,scale_value: float=1.0,identity: int=0) -> void:
	if not portraits.has(identity): portraits[identity]=load("res://game/assets/portraits/golfer-%d.png"%identity)
	if portraits[identity]!=null:
		draw_texture_rect(portraits[identity],Rect2(at-Vector2.ONE*32*scale_value,Vector2.ONE*64*scale_value),false)
		return
	draw_set_transform(at,0,Vector2.ONE*scale_value)
	draw_circle(Vector2.ZERO,29,c.darkened(0.64))
	draw_arc(Vector2.ZERO,29,0,TAU,48,c.lightened(0.3),1.5,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-23,21),Vector2(-16,11),Vector2(16,11),Vector2(23,21),Vector2(17,26),Vector2(-17,26)]),c)
	var skin: Color=[Color("d5a17a"),Color("e5b78e"),Color("bd855f"),Color("cfa77f"),Color("b88160"),Color("e3bd98"),Color("ba8e6e"),Color("d0a380")][identity%8]
	draw_style_box(_portrait_head(skin),Rect2(-12,-17,24,34))
	draw_circle(Vector2(-12,-1),3,skin); draw_circle(Vector2(12,-1),3,skin)
	var hair: Color=Color("4e362b") if identity%3 else Color("a17b49")
	if identity in [0,4,5]:
		draw_arc(Vector2(0,5),10,0,PI,20,hair,6,true)
	if identity in [2,6]:
		draw_arc(Vector2(0,-11),12,PI,TAU,24,hair,8,true)
	else:
		draw_arc(Vector2(0,-11),13,PI,TAU,24,CREAM if identity%2 else c,9,true)
		draw_line(Vector2(-14,-12),Vector2(19 if identity%2 else -20,-12),CREAM if identity%2 else c,4,true)
	if identity in [0,3,7]:
		for x in [-6,6]: draw_style_box(_portrait_head(INK),Rect2(x-5,-4,10,6))
		draw_line(Vector2(-2,-2),Vector2(2,-2),INK,2,true)
	else:
		for x in [-5,5]:
			draw_line(Vector2(x-3,-6),Vector2(x+2,-5),hair,2,true)
			draw_circle(Vector2(x,-2),1.5,INK)
	draw_line(Vector2(0,0),Vector2(2,4),skin.darkened(0.24),1.5,true)
	draw_arc(Vector2(0,5),5,0.2,2.7,12,CREAM,1.5,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-9,13),Vector2(0,19),Vector2(-4,23)]),CREAM)
	draw_colored_polygon(PackedVector2Array([Vector2(9,13),Vector2(0,19),Vector2(4,23)]),CREAM)
	draw_set_transform(Vector2.ZERO)

func _portrait_head(color: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new(); box.bg_color=color
	box.set_corner_radius_all(7)
	return box

func _game_hud() -> void:
	var h: Array=Data.HOLES[game.hole_index]
	panel(Rect2(24,22,1232,77),Color(0.06,0.18,0.14,0.94),14)
	text(Vector2(43,54),"Breakfast Balls.",25,CREAM,serif)
	text(Vector2(44,78),"MAGNOLIA PINES",11,GOLD,bold)
	draw_line(Vector2(273,38),Vector2(273,81),Color("53745c"),1)
	text(Vector2(295,53),"PRACTICE · 1 / 2 / 3" if game.practice_active else "HOLE %02d · %d/%d"%[game.hole_index+1,game.round_position+1,game.round_length],14,GOLD,bold)
	text(Vector2(295,79),["24-foot putt","22-yard chip","55-yard pitch"][game.practice_station] if game.practice_active else h[0],19,CREAM,bold)
	text(Vector2(505,53),"CALM" if game.practice_active else "PAR %d"%h[1],17,CREAM,bold)
	text(Vector2(505,77),"NO RECORDS" if game.practice_active else "%d YARDS"%Data.hole_yards(game.hole_index,game.round_tees),12,MUTED)
	text(Vector2(629,53),"SHORT GAME" if game.practice_active else "CLOSEST TO PIN" if game.mode==2 else "STROKE PLAY" if game.mode==0 else "SKINS · POT %d"%game.skin_pot,14,GOLD,bold)
	text(Vector2(629,78),"R RETRY · 1/2/3 STATION" if game.practice_active else game.tee_name(game.round_tees).to_upper()+(" · REMOTE" if game.remote_timing_enabled else ""),12,MUTED)
	button(Rect2(866,40,105,39),"Retry" if game.practice_active else "Card","retrypractice" if game.practice_active else "card")
	button(Rect2(981,40,105,39),"Flyover","overview",game.overview)
	button(Rect2(1096,40,62,39),"?","help")
	button(Rect2(1168,40,65,39),"Ⅱ","pause")
	if game.players.is_empty(): return
	var p: Dictionary=game.players[game.player_index]
	panel(Rect2(24,117,308,91),Color(0.07,0.20,0.15,0.90),12)
	_avatar(Vector2(60,160),Color(Data.GOLFERS[p.golfer][2]),0.78,p.golfer)
	text(Vector2(91,146),"P%d · %s · %s"%[game.player_index+1,p.tag,game.relative_score(game.player_index)],12,GOLD,bold)
	text(Vector2(91,171),Data.GOLFERS[p.golfer][0],19,CREAM,bold)
	text(Vector2(91,192),"SHOT %d  /  %s"%[p.strokes+1 if game.state=="aim" else p.strokes,game.course.lie_at(game.ball_pos)],12,MUTED)
	if game.practice_active:
		panel(Rect2(24,292,308,100),INK,12)
		text(Vector2(40,317),"PRACTICE STATIONS · 1 / 2 / 3",11,GOLD,bold)
		for i in range(3): button(Rect2(36+i*98,332,92,39),["Putt","Chip","Pitch"][i],"station:%d"%i,game.practice_station==i)
	if p.breakfast_used:
		panel(Rect2(24,290,222,29),INK,8)
		center(Rect2(24,290,222,29),"BREAKFAST BALL USED",11,GOLD,bold)
	if game.mode==2:
		panel(Rect2(354,111,522,45),INK,10)
		center(Rect2(354,111,522,45),"ONE SHOT EACH · FINISH ON THE GREEN · 100 PTS MAX",12,GOLD,bold)
	if game.breakfast_flash>0 and game.state=="aim":
		panel(Rect2(370,300,540,94),INK,16,GOLD)
		center(Rect2(385,309,510,38),"FRESH EGG. FRESH START.",25,CREAM,serif)
		center(Rect2(385,353,510,27),"Breakfast Ball served · Your next shot counts",14,GOLD,bold)
	# Wind compass.
	panel(Rect2(24,220,174,61),Color(0.07,0.20,0.15,0.88),12)
	var wind_angle: float=atan2(game.wind.x,-game.wind.y)-game.aim
	var v:=Vector2(sin(wind_angle),-cos(wind_angle))
	_arrow(Vector2(54,250)-v*12,Vector2(54,250)+v*12,GOLD,2)
	text(Vector2(80,247),"%d MPH"%roundi(game.wind.length()),16,CREAM,bold)
	text(Vector2(80,267),"WIND",10,MUTED)
	_minimap(Rect2(1037,118,219,329))
	if game.state=="aim" and game.club==13: _green_grid()
	if game.state in ["aim","flight","result"] and not (game.state=="flight" and game.swing_elapsed<=1.65):
		# Small flag label anchors the distance to the world.
		var pin3: Vector3=game.course.pin+Vector3(0,5.0,0)
		if not game.camera.is_position_behind(pin3):
			var screen: Vector2=game.camera.unproject_position(pin3)
			if screen.x>340 and screen.x<1000 and screen.y>140 and screen.y<510:
				panel(Rect2(screen-Vector2(52,32),Vector2(104,30)),INK,7)
				center(Rect2(screen-Vector2(52,32),Vector2(104,30)),game.distance_text(),15,GOLD,bold)
	if game.state=="flight": _ball_tracker()
	panel(Rect2(24,577,914,179),Color(0.06,0.18,0.14,0.96),14)
	text(Vector2(45,605),"THE BAG",11,GOLD,bold)
	text(Vector2(45,639),Data.CLUBS[game.club][0],27,CREAM,serif)
	var range_label: String=game.range_text()
	text(Vector2(45,665),range_label,15,MUTED)
	text(Vector2(45,688),"Surface-adjusted estimate" if game.club==13 else "Low flight · more rollout" if game.style_index()==2 else "Lofted flight · soft landing" if game.style_index()==1 else "Lie-adjusted carry baseline",11,MUTED)
	if game.club>=9 and game.club<=12:
		for i in range(3): button(Rect2(45+i*73,704,68,29),Data.SHOT_STYLES[i].name,"shotstyle:%d"%i,game.style_index()==i)
		text(Vector2(45,748),"X shot type · Q / E club",10,MUTED)
	else:
		button(Rect2(45,706,44,33),"‹","club:-1")
		button(Rect2(98,706,44,33),"›","club:1")
		text(Vector2(157,728),"Q / E",11,MUTED)
	draw_line(Vector2(277,597),Vector2(277,735),Color("41634c"),1)
	text(Vector2(299,605),"TO THE CUP",11,GOLD,bold)
	text(Vector2(299,650),game.distance_text(),35,CREAM,bold)
	var elev: float=(game.course.pin.y-game.ball_pos.y)*3.28084
	text(Vector2(300,676),"%s %.0f ft  ·  %s"%["↑" if elev>=0 else "↓",absf(elev),game.course.lie_at(game.ball_pos).capitalize()],13,MUTED)
	button(Rect2(299,704,197,34),["Topspin","Neutral spin","Backspin"][game.spin+1],"spin")
	text(Vector2(527,605),"14 CLUBS. NO EXCUSES.",11,GOLD,bold)
	for i in range(14):
		var r:=Rect2(527+(i%7)*54,620+int(i/7)*42,47,34)
		panel(r,GOLD if game.club==i else Color("284d3f"),6)
		center(r,Data.CLUBS[i][1],13,INK if game.club==i else CREAM,bold)
		buttons.append([r,"selectclub:%d"%i])
	text(Vector2(527,728),"Drag the course / ← → to aim",12,MUTED)
	_swing_pad()
	text(Vector2(26,783),"H  Help     V  Flyover     R  Retry     ESC  Pause" if game.practice_active else "H  Help     V  Flyover     TAB  Scorecard     ESC  Pause",12,Color("e9ebd6"))
	text(Vector2(639,783),"R retry · 1 putt / 2 chip / 3 pitch" if game.practice_active else "Hold Space · Release on center" if game.input_style==0 else "Click gold pad · Pull down · Return & release",12,Color("e9ebd6"))
	if game.state=="flight" and game.swing_elapsed>1.65:
		panel(Rect2(423,116,418,72),INK,12)
		center(Rect2(423,120,418,29),game.last_shot,16,GOLD,bold)
		center(Rect2(423,151,418,27),"%s  ·  %s"%[game.shot_distance_text(game.shot_distance),"IN FLIGHT" if game.in_air else "ROLLING"],14,CREAM)

func _swing_pad() -> void:
	panel(Rect2(958,577,298,179),GOLD,14)
	text(Vector2(976,602),"CONTACT SPEED  %.2f×"%game.contact_difficulty(),11,INK,bold)
	if game.state!="aim":
		center(Rect2(966,623,280,80),"LET IT COOK…",18,INK,bold); return
	var power: float=game.swing_power()
	if game.dragging or game.keyboard_charge:
		text(Vector2(976,635),"%d%%"%roundi(power*100),28,Color("9b3329") if power>1 else INK,bold)
		panel(Rect2(1080,620,151,10),Color("c5a45c"),4)
		panel(Rect2(1080,620,151*minf(power,1),10),Color("9b3329") if power>1 else INK,4)
		text(Vector2(976,660),game.power_distance_text(power),16,INK,bold)
		text(Vector2(976,682),"OVERSWING: CONTACT LOSS" if power>1 else "PATH %+.0f%%"%(game.path_offset*100),10,Color("9b3329") if power>1 else INK,bold)
		draw_line(Vector2(1003,710),Vector2(1217,710),INK,2,true)
		draw_rect(Rect2(1099,703,22,14),Color("7c9951"))
		var needle: float=1110+game.face_meter()*106
		draw_line(Vector2(needle,699),Vector2(needle,721),INK,3,true)
		text(Vector2(992,743),"RELEASE WITH THE NEEDLE CENTERED",10,INK,bold)
	else:
		if game.input_style==0:
			text(Vector2(976,634),"01  Hold SPACE for power",14,INK,bold)
			text(Vector2(976,660),"02  Release on center",14,INK,bold)
			text(Vector2(976,687),"A / D adjusts swing path",12,INK)
			text(Vector2(976,709),"Keep centered for a straight path",11,INK)
		else:
			text(Vector2(976,628),"01  Click & hold here",13,INK,bold)
			text(Vector2(976,651),"02  Pull down for power",13,INK,bold)
			text(Vector2(976,674),"03  Return & release on center",12,INK,bold)
			text(Vector2(976,698),"Sideways pull sets swing path",11,INK)
			text(Vector2(976,716),"Trackpad: keep the click held",11,INK)
		text(Vector2(976,742),"Past 100% = overswing penalty",10,INK)

func _arrow(a: Vector2,b: Vector2,c: Color,width: float=1.0) -> void:
	draw_line(a,b,c,width,true)
	var dir: Vector2=(b-a).normalized()
	draw_line(b,b-dir.rotated(0.55)*7,c,width,true)
	draw_line(b,b-dir.rotated(-0.55)*7,c,width,true)

var map_bounds:=Rect2(-100,-450,200,480)

func _minimap(r: Rect2) -> void:
	panel(r,Color(0.06,0.18,0.14,0.91),12)
	text(r.position+Vector2(16,25),"THE YARDAGE BOOK",11,GOLD,bold)
	var maprect:=Rect2(r.position+Vector2(12,40),Vector2(r.size.x-24,r.size.y-83))
	map_bounds=Rect2(-65,-game.course.length_m-45,130,75+game.course.length_m)
	for i in range(41):
		var z: float=-game.course.length_m*i/40.0
		var x: float=game.course.center_x(z)
		map_bounds=map_bounds.expand(Vector2(x-60,z)).expand(Vector2(x+60,z))
	for player in game.players: map_bounds=map_bounds.expand(Vector2(player.pos.x,player.pos.z))
	map_bounds=map_bounds.expand(Vector2(game.ball_pos.x,game.ball_pos.z)).grow(8)
	var tree_marks:=PackedVector2Array()
	for tree in game.course.trees:
		var point:=_map_point(tree,maprect)
		if maprect.has_point(point):
			tree_marks.append(point-Vector2(0.7,0)); tree_marks.append(point+Vector2(0.7,0))
	if tree_marks.size()>1: draw_multiline(tree_marks,Color("3c684b"),2.5,true)
	for cut in [14.0,7.0,0.0]:
		var polygon:=PackedVector2Array()
		for side in [-1,1]:
			for j in range(41):
				var i: int=j if side==-1 else 40-j
				var z: float=-15-(game.course.length_m-15)*i/40.0
				polygon.append(_map_point(Vector3(game.course.center_x(z)+side*(game.course.fairway_width(z)+cut),0,z),maprect))
		draw_colored_polygon(polygon,Color("476c3d") if cut==14 else Color("719054") if cut==7 else Color("93b36a"))
	for yards in range(100,Data.hole_yards(game.hole_index,game.round_tees),100):
		var z: float=game.course.tee.z-yards*game.YARD
		var p:=_map_point(Vector3(game.course.center_x(z),0,z),maprect)
		draw_dashed_line(Vector2(maprect.position.x,p.y),Vector2(maprect.end.x,p.y),Color(0.9,0.9,0.7,0.18),1,3)
		text(Vector2(maprect.end.x-24,p.y-3),str(yards),9,MUTED)
	_map_ellipse(Vector4(game.course.pin.x,game.course.pin.z,game.course.green_radii.x,game.course.green_radii.y),maprect,Color("bed893"))
	_map_ellipse(Vector4(game.course.tee.x,game.course.tee.z,8,5),maprect,Color("b9c98e"))
	for e in game.course.bunkers: _map_ellipse(e,maprect,Color("e5d4ab"))
	for e in game.course.ponds: _map_ellipse(e,maprect,Color("5aacae"))
	var creek:=PackedVector2Array()
	for p in game.course.creek_points: creek.append(_map_point(Vector3(p.x,0,p.y),maprect))
	if creek.size()>1:
		var creek_scale: float=minf(maprect.size.x/map_bounds.size.x,maprect.size.y/map_bounds.size.y)
		draw_polyline(creek,Color("5aacae"),9.0*creek_scale,true)
	var cup:=_map_point(game.course.pin,maprect)
	draw_line(cup,cup-Vector2(0,12),INK,1.5,true)
	draw_colored_polygon(PackedVector2Array([cup-Vector2(0,12),cup+Vector2(8,-9),cup-Vector2(0,6)]),GOLD)
	for i in range(game.players.size()):
		if i==game.player_index or game.players[i].done: continue
		var p:=_map_point(game.players[i].pos,maprect)
		draw_circle(p,4,Color(Data.GOLFERS[game.players[i].golfer][2]))
		text(p+Vector2(5,0),str(i+1),9,CREAM)
	var trace:=PackedVector2Array()
	for p in game.trail:
		var point:=_map_point(p,maprect)
		if maprect.has_point(point): trace.append(point)
	if trace.size()>1: draw_polyline(trace,Color("f0c868"),1.5,true)
	var bp:=_map_point(game.ball_pos,maprect)
	draw_circle(bp,6,INK); draw_circle(bp,3.5,CREAM)
	if game.state=="aim":
		var end:=_map_point(game.marker.position,maprect)
		end=Vector2(clampf(end.x,maprect.position.x,maprect.end.x),clampf(end.y,maprect.position.y,maprect.end.y))
		draw_dashed_line(bp,end,GOLD,1.5,4)
		draw_arc(end,5,0,TAU,20,GOLD,1.5,true)
	text(r.position+Vector2(14,r.size.y-26),"● BALL   ⚑ PIN   ◯ TARGET",9,CREAM)
	var scale: float=minf(maprect.size.x/map_bounds.size.x,maprect.size.y/map_bounds.size.y)
	var a: Vector2=r.position+Vector2(14,r.size.y-14)
	draw_line(a,a+Vector2(50*game.YARD*scale,0),GOLD,2,true)
	text(a+Vector2(50*game.YARD*scale+5,3),"50 yd",9,MUTED)
	text(r.position+Vector2(r.size.x-74,r.size.y-11),"N ↑  V VIEW",9,MUTED)

func _map_ellipse(e: Vector4,r: Rect2,color: Color) -> void:
	var polygon:=PackedVector2Array()
	for i in range(40):
		var a: float=TAU*i/40.0
		polygon.append(_map_point(Vector3(e.x+cos(a)*e.z,0,e.y+sin(a)*e.w),r))
	draw_colored_polygon(polygon,color)

func _map_point(p: Vector3,r: Rect2) -> Vector2:
	var scale: float=minf(r.size.x/map_bounds.size.x,r.size.y/map_bounds.size.y)
	return r.get_center()+(Vector2(p.x,p.z)-map_bounds.get_center())*scale

func _ball_tracker() -> void:
	if game.impact_pending:
		return
	var raw: Vector2=game.camera.unproject_position(game.ball_pos)
	if game.camera.is_position_behind(game.ball_pos): raw=Vector2(640,130)
	var p:=Vector2(clampf(raw.x,355,1005),clampf(raw.y,135,505))
	var offscreen: bool=p.distance_to(raw)>5
	draw_circle(p,15,Color(0.05,0.14,0.17,0.55))
	draw_arc(p,15,0,TAU,48,CREAM,2.5,true)
	draw_arc(p,20,0,TAU,48,GOLD,1.5,true)
	if offscreen: _arrow(p,p+(raw-p).normalized()*32,GOLD,2)
	else: draw_circle(p,3,CREAM)
	var height: float=maxf(0,game.ball_pos.y-game.course.height_at(game.ball_pos.x,game.ball_pos.z))
	var label_pos:=Vector2(clampf(p.x-110,340,790),p.y+29 if p.y<440 else p.y-66)
	panel(Rect2(label_pos,Vector2(220,38)),INK,8)
	center(Rect2(label_pos,Vector2(220,38)),"%s · %d FT · %.1f s"%["AIR" if game.in_air else "ROLL",roundi(height*3.28084),game.shot_time],14,GOLD,bold)

func _green_grid() -> void:
	for x in range(-5,6):
		for z in range(-5,6):
			var p: Vector3=game.course.pin+Vector3(x*2,0,z*2)
			p.y=game.course.height_at(p.x,p.z)+0.24
			var q: Vector3=p+Vector3(1.6,0,0); q.y=game.course.height_at(q.x,q.z)+0.24
			if not game.camera.is_position_behind(p) and not game.camera.is_position_behind(q):
				var a: Vector2=game.camera.unproject_position(p); var b: Vector2=game.camera.unproject_position(q)
				if a.y>110 and a.y<570 and a.x>340 and b.x>340 and a.x<1010 and b.x<1010: draw_line(a,b,Color(0.9,1,0.75,0.24),1,true)
	var p: Vector3=game.ball_pos
	var slope:=Vector3(game.course.height_at(p.x-0.5,p.z)-game.course.height_at(p.x+0.5,p.z),0,game.course.height_at(p.x,p.z-0.5)-game.course.height_at(p.x,p.z+0.5))
	var downhill: Vector3=p+slope.normalized()*3.0
	downhill.y=game.course.height_at(downhill.x,downhill.z)+0.24
	if not game.camera.is_position_behind(p) and not game.camera.is_position_behind(downhill):
		var a: Vector2=game.camera.unproject_position(p)
		var b: Vector2=game.camera.unproject_position(downhill)
		var d: Vector2=(b-a).normalized()
		draw_line(a,b,GOLD,2,true)
		draw_line(b,b-d.rotated(0.5)*10,GOLD,2,true)
		draw_line(b,b-d.rotated(-0.5)*10,GOLD,2,true)
	text(Vector2(375,541),"GREEN READ  ·  gold arrow points downhill",14,CREAM,bold)

func _result() -> void:
	buttons.clear()
	panel(Rect2(350,275,580,273),INK,18,GOLD)
	center(Rect2(368,291,544,27),"PRACTICE · SAME SHOT, FRESH BALL" if game.practice_active else "SHOT SERVED",12,GOLD,bold)
	center(Rect2(363,326,554,43),game.result_title,22,CREAM,bold)
	center(Rect2(365,375,550,30),game.result_detail,13,MUTED)
	center(Rect2(365,411,550,26),game.shot_feedback(),14,CREAM,bold)
	if game.record_notice!="": center(Rect2(365,447,550,22),game.record_notice,11,GOLD,bold)
	elif game.practice_active:
		for i in range(3): button(Rect2(408+i*158,443,148,29),["1 Putt","2 Chip","3 Pitch"][i],"station:%d"%i,game.practice_station==i)
	if game.can_take_breakfast_ball():
		button(Rect2(374,487,233,43),"PLAY IT    ↵","continue",false,true)
		button(Rect2(619,487,287,43),"BREAKFAST BALL    B","breakfast")
	else: button(Rect2(493,487,294,43),"RETRY SHOT    ↵" if game.practice_active else "CONTINUE    ↵","continue",false,true)

func _scorecard() -> void:
	if game.mode==2:
		_challenge_scorecard()
		return
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.64))
	panel(Rect2(95,148,1090,517),CREAM,18)
	text(Vector2(130,196),"THE CLUBHOUSE" if game.state=="finished" else "THE SCORECARD",12,Color("647454"),bold)
	text(Vector2(130,242),"Breakfast Balls.",38,INK,serif)
	text(Vector2(755,231),game.tee_name(game.round_tees).to_upper()+" / "+("STROKE" if game.mode==0 else "SKINS"),13,INK,bold)
	var cell: float=43.0
	var startx: float=329.0
	panel(Rect2(122,267,1038,37),INK,5)
	text(Vector2(139,291),"GOLFER",12,CREAM,bold)
	for i in range(game.round_holes.size()): center(Rect2(startx+i*cell,267,cell,37),str(game.round_holes[i]+1),12,CREAM)
	center(Rect2(1103,267,57,37),"TOT",12,GOLD,bold)
	text(Vector2(139,331),"PAR",12,Color("6d795f"),bold)
	for i in range(game.round_holes.size()): center(Rect2(startx+i*cell,309,cell,31),str(Data.HOLES[game.round_holes[i]][1]),12,Color("6d795f"))
	for pi in range(game.players.size()):
		var y: float=349+pi*43
		if pi%2==0: panel(Rect2(122,y-1,1038,40),Color("e8e5cf"),4)
		text(Vector2(139,y+25),"%s · %s%s"%[game.players[pi].tag,Data.GOLFERS[game.players[pi].golfer][0].split(" ")[0]," *" if game.players[pi].breakfast_used else ""],14,INK,bold)
		for i in range(game.round_holes.size()):
			var value: String="—"
			var c: Color=Color("a3ab94")
			if i<game.players[pi].scores.size():
				var score: int=game.players[pi].scores[i]
				value=str(score); c=INK
				if score<Data.HOLES[game.round_holes[i]][1]: draw_circle(Vector2(startx+i*cell+cell/2,y+19),14,Color("e9c974"))
			center(Rect2(startx+i*cell,y,cell,37),value,13,c,bold)
		center(Rect2(1103,y,57,37),str(game.total_score(pi)),16,INK,bold)
		if game.mode==1: text(Vector2(145,y+38),"%d skins"%game.players[pi].skins,9,Color("647454"))
	var msg: String=game.winners_text() if game.state=="finished" else game.hole_message if game.hole_done else "Round in progress · Lowest total wins." if game.mode==0 else "Unique low score wins the pot. Ties carry forward."
	text(Vector2(133,558),msg,16,INK,bold)
	if game.players.any(func(p): return p.breakfast_used): text(Vector2(133,625),"* Breakfast Ball used · Round excluded from club records",12,Color("647454"))
	if game.state=="finished":
		text(Vector2(133,586),"Same time next Sunday?",14,Color("647454"))
		button(Rect2(844,593,304,44),"BACK TO THE CLUBHOUSE","menu",false,true)
	else:
		button(Rect2(844,593,304,44),"FINAL RESULTS  →" if game.hole_done and game.round_position+1>=game.round_length else "NEXT TEE  →" if game.hole_done else "BACK TO PLAY","next",false,true)

func _challenge_scorecard() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.64))
	panel(Rect2(95,148,1090,517),CREAM,18)
	text(Vector2(130,191),"DINER SPECIAL · FINAL RESULTS" if game.state=="finished" else "DINER SPECIAL · THE SCORECARD",12,Color("647454"),bold)
	text(Vector2(130,237),"Closest to pin.",38,INK,serif)
	text(Vector2(130,267),"100 points minus feet from the cup (rounded up) · Missed green: 0",14,Color("647454"))
	panel(Rect2(122,285,1038,38),INK,5)
	text(Vector2(139,310),"GOLFER",12,CREAM,bold)
	for i in range(3): center(Rect2(477+i*170,285,160,38),"HOLE %d"%(game.round_holes[i]+1),13,CREAM,bold)
	center(Rect2(1003,285,145,38),"TOTAL / 300",12,GOLD,bold)
	for pi in range(game.players.size()):
		var p: Dictionary=game.players[pi]
		var y: float=336+pi*47
		if pi%2==0: panel(Rect2(122,y,1038,44),Color("e8e5cf"),4)
		text(Vector2(139,y+27),"%s · %s"%[p.tag,Data.GOLFERS[p.golfer][0]],14,INK,bold)
		for i in range(3):
			var label: String="—"
			if i<p.challenge_results.size():
				var shot: Dictionary=p.challenge_results[i]
				label="ACE · 100 pts" if shot.holed else "%.1f ft · %d pts"%[shot.feet,shot.points] if shot.valid else "MISS · 0 pts"
			center(Rect2(477+i*170,y,160,44),label,13,INK)
		center(Rect2(1003,y,145,44),str(game.total_score(pi)),19,INK,bold)
	var message: String=game.winners_text() if game.state=="finished" else game.hole_message if game.hole_done else "One shot per golfer. Highest three-hole total wins."
	text(Vector2(133,553),message,16,INK,bold)
	if game.state=="finished":
		button(Rect2(133,593,284,44),"ANOTHER SERVING","retrychallenge",false,true)
		button(Rect2(844,593,304,44),"BACK TO THE CLUBHOUSE","menu")
	else:
		button(Rect2(844,593,304,44),"FINAL RESULTS  →" if game.hole_done and game.round_position==2 else "NEXT PIN  →" if game.hole_done else "BACK TO PLAY","next",false,true)

func _pause() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.65))
	panel(Rect2(425,245,430,304),INK,18,GOLD)
	center(Rect2(450,275,380,47),"Coffee break.",36,CREAM,serif)
	button(Rect2(464,349,352,46),"BACK TO THE FAIRWAY","resume",false,true)
	button(Rect2(464,410,352,42),"How to swing","help")
	button(Rect2(464,466,352,42),"End round & return to menu","menu")

func _help() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.02,0.08,0.05,0.8))
	panel(Rect2(228,70,824,665),CREAM,18)
	text(Vector2(269,120),"THE BREAKFAST BALLS FIELD GUIDE",12,Color("6a775b"),bold)
	text(Vector2(269,171),"A little touch goes a long way.",32,INK,serif)
	button(Rect2(269,192,250,34),"Keyboard","input:0",game.input_style==0)
	button(Rect2(533,192,330,34),"Mouse & Trackpad","input:1",game.input_style==1)
	var rows: Array=[
		["LINE IT UP", "Drag the course or use ← / → to aim. V shows the whole hole."],
		["CHOOSE YOUR SHOT", "Q / E selects clubs. Wedges: X cycles Full / Pitch / Chip."],
		["BUILD POWER", "Hold SPACE. Power keeps building; past 100% loses contact." if game.input_style==0 else "Click near the TOP of the gold pad. Hold the click and pull down."],
		["TIME CONTACT", "Release SPACE with the face needle centered. A / D adjusts path." if game.input_style==0 else "Return toward your start; release the click with the needle centered."],
		["FIND YOUR TOUCH", "Pitch flies higher and stops sooner. Chip flies low and runs out."],
		["READ THE DISTANCE", "Putter readouts use feet. Estimates are affected by break and hazards."],
		["KEEP THE CHALLENGE", "Rough / sand speed up contact. Wind, slope and spin still matter."],
		["PRACTICE & PLAY", "Practice: R retries; 1 / 2 / 3 switches shots. Rounds: water / OB +1."]
	]
	for i in range(rows.size()):
		var y: float=252+i*49
		text(Vector2(269,y),rows[i][0],12,INK,bold)
		text(Vector2(269,y+20),rows[i][1],14,Color("65735c"))
	text(Vector2(269,653),"Mouse / trackpad: sideways pull sets path; power keeps charging while held.",12,Color("65735c"))
	button(Rect2(715,674,295,40),"GOT IT. LET'S GOLF.","closehelp",false,true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		for i in range(buttons.size()-1,-1,-1):
			if buttons[i][0].has_point(event.position):
				_action(buttons[i][1]); get_viewport().set_input_as_handled(); return

func _action(action: String) -> void:
	var parts: PackedStringArray=action.split(":")
	var value: int=int(parts[1]) if parts.size()>1 else 0
	match parts[0]:
		"settings":
			if game.state=="menu": game.settings_open=true
		"closesettings": game.settings_open=false
		"input": game.set_input_style(value)
		"tees": game.tees=clampi(value,0,1)
		"recordtees": game.record_tees=clampi(value,0,1)
		"shotstyle": game.set_shot_style(value)
		"practice": game.start_practice()
		"station": game.set_practice_station(value)
		"retrypractice": game.retry_practice()
		"players": game.player_count=value; game.active_slot=mini(game.active_slot,value-1); game.mode=0 if value==1 and game.mode==1 else game.mode
		"mode": game.mode=value; game.player_count=maxi(2,game.player_count) if value==1 else game.player_count
		"holes": game.round_length=value
		"nine": game.nine_side=value
		"slot": game.active_slot=value
		"golfer": game.roster[game.active_slot]=value
		"play": game.begin_name_entry()
		"confirmname": game._accept_name_entry()
		"leaderboard": game.record_tees=game.tees; game.state="leaderboard"
		"closeleaderboard": game.state="menu"
		"help": game.help_open=true; game.dragging=false; game.keyboard_charge=false
		"closehelp": game.help_open=false
		"sound": game.toggle_sound()
		"remote": game.remote_timing_enabled=not game.remote_timing_enabled
		"parsec": game.parsec_setup_open=true
		"openparsec": game.open_parsec()
		"closeparsec": game.parsec_setup_open=false
		"club": game.change_club(value)
		"selectclub":
			game.select_club(value)
		"spin":
			if game.state=="aim" and not game.dragging and not game.keyboard_charge: game.spin=(game.spin+2)%3-1
		"overview":
			if game.state=="aim": game.overview=not game.overview
		"continue": game.advance_turn()
		"breakfast": game.take_breakfast_ball()
		"retrychallenge":
			if game.state=="finished" and game.mode==2: game.start_round()
		"card":
			if game.state=="aim" and not game.practice_active:
				game.dragging=false; game.keyboard_charge=false; game.score_return="aim"; game.state="scorecard"
		"next": game.next_hole()
		"pause":
			if game.state in ["aim","flight","result"]: game.previous_state=game.state; game.state="pause"; game.dragging=false; game.keyboard_charge=false
		"resume": game.state=game.previous_state
		"menu": game.return_to_menu()
	queue_redraw()
