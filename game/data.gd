extends RefCounted

# Shared carry scale, flight time, landing retention and animation amplitude.
const SHOT_STYLES = [
	{"name":"Full", "range":1.0, "hang":0.0, "landing":0.18, "swing":1.0},
	{"name":"Pitch", "range":0.60, "hang":3.1, "landing":0.14, "swing":0.65},
	{"name":"Chip", "range":0.24, "hang":1.55, "landing":0.26, "swing":0.32}
]
# Yards moved forward along the existing routing. All other starts stay intact.
const CLUB_TEE_ADVANCE = [0,0,65,0,75,0,55,0,0,0,0,0,0,65,0,0,0,0]

static func hole_yards(index: int, tees: int=0) -> int:
	return HOLES[index][2] - (CLUB_TEE_ADVANCE[index] if tees==1 else 0)

# Carry yards. Trackman 2023 tour averages (published May 2024) for woods/irons/PW.
# 4H and specialty wedges are explicit gameplay estimates, not measured tour means.
const CLUBS = [
	["Driver", "DR", 282.0, 13.0, false], ["3 Wood", "3W", 249.0, 16.0, false],
	["5 Wood", "5W", 236.0, 19.0, false], ["4 Hybrid", "4H", 231.0, 22.0, true],
	["5 Iron", "5i", 199.0, 25.0, false], ["6 Iron", "6i", 188.0, 28.0, false],
	["7 Iron", "7i", 176.0, 32.0, false], ["8 Iron", "8i", 164.0, 36.0, false],
	["9 Iron", "9i", 152.0, 40.0, false], ["Pitching Wedge", "PW", 142.0, 43.0, false],
	["Gap Wedge", "GW", 120.0, 47.0, true], ["Sand Wedge", "SW", 105.0, 51.0, true],
	["Lob Wedge", "LW", 85.0, 57.0, true], ["Putter", "PT", 35.0, 0.0, true]
]
const GOLFERS = [
	["Tommy Beatswood", "Fairway DJ", "#e6b95c"],
	["Thotty Scheffler", "Certified pin seeker", "#e8998d"],
	["Rory Whacklroy", "Grip it. Rip it. Brunch.", "#9bbddb"],
	["Ballin Morikowa", "Fresh irons, fresh fit", "#b5c98b"],
	["Jon Rahmlette", "Scrambling specialist", "#c7a2d5"],
	["Bready Couples", "Smooth like butter", "#e3c9a0"],
	["Justin Thyme", "Never late to the tee", "#87c6b7"],
	["Bubba Waffles", "Extra syrup. Extra draw.", "#e1a376"]
]
# Original layouts inspired by Augusta's terrain and strategic themes, not a replica.
# name, par, yards, dogleg metres, elevation metres, hazard style
const HOLES = [
	["First Pour", 4, 445, 34, 8, 0], ["Buttered Bend", 5, 585, -108, -6, 1],
	["Short Stack", 4, 350, -15, 5, 0], ["Morning Glory", 3, 240, 0, -4, 0],
	["Pine & Dine", 4, 495, -48, 13, 0], ["Sunny Side", 3, 180, 0, -9, 0],
	["The Squeeze", 4, 450, 2, 6, 0], ["Rise & Grind", 5, 570, -45, 17, 0],
	["Last Crumb", 4, 460, -39, -10, 0], ["Downhill Diner", 4, 495, -100, -22, 0],
	["Cold Brew", 4, 520, 34, -13, 2], ["Golden Hour", 3, 155, 0, -3, 3],
	["Amen & Eggs", 5, 545, -112, -7, 3], ["Peach Please", 4, 440, -20, 8, 0],
	["Second Helping", 5, 550, 8, -9, 3], ["Pink Sunday", 3, 170, 0, -3, 2],
	["Biscuit Business", 4, 450, 0, 8, 0], ["The Check", 4, 465, 73, 15, 0]
]

static func score_name(strokes: int, par: int) -> String:
	if strokes == 1: return "HOLE IN ONE!"
	match strokes - par:
		-3: return "ALBATROSS!"
		-2: return "EAGLE!"
		-1: return "BIRDIE!"
		0: return "PAR. ORDER UP."
		1: return "BOGEY"
		2: return "DOUBLE BOGEY"
	return "+%d · NEXT HOLE, FRESH START" % (strokes - par)

static func skin_winner(scores: Array) -> int:
	var best: int = 1000
	var winner: int = -1
	for i in range(scores.size()):
		if scores[i] < best:
			best = scores[i]
			winner = i
		elif scores[i] == best:
			winner = -1
	return winner
