extends "res://game/course.gd"

var test_lie: String="GREEN"
var transition: bool=false
var slope: float=0.0

func height_at(_x: float,z: float) -> float:
	return -z*slope

func lie_at(p: Vector3) -> String:
	return "GREEN" if transition and p.z< -4.0 else test_lie
