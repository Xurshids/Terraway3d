@tool
@icon("res://addons/live_river_road/icons/river.svg")
extends "live_path_3d.gd"


func _init() -> void:
	path_width = 10.0
	surface_offset = 0.05
	cross_segments = 6
	skirt_depth = 0.0
	road_crown = 0.0
	height_smoothing = 2
	river_depth = 1.4
	river_bank_height = 0.35
	terrain_falloff = 7.0
	paint_bank_wetness = true
	live_terrain_preview = true


func _is_river() -> bool:
	return true
