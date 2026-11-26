@tool
extends RefCounted

const MAP_COLOR := 2
const MAP_MAX := 3


static func carve_path(path_node: Path3D, backup: Dictionary) -> Dictionary:
	var terrain: Node3D = path_node.get("terrain")
	if not is_instance_valid(terrain) or not terrain.is_class("Terrain3D"):
		return {}

	var data: Object = terrain.get("data")
	if data == null:
		return {}

	if not backup.is_empty():
		restore_backup(terrain, backup, false)
		backup.clear()

	var world_pts: PackedVector3Array = path_node.call("get_smoothed_world_points")
	if world_pts.size() < 2:
		return {}

	var spacing: float = 1.0
	if terrain.get("vertex_spacing") != null:
		spacing = maxf(float(terrain.get("vertex_spacing")), 0.1)

	var is_river: bool = bool(path_node.call("_is_river"))
	var path_width: float = float(path_node.get("path_width"))
	var surface_offset: float = float(path_node.get("surface_offset"))
	var falloff_width: float = float(path_node.get("terrain_falloff"))
	var channel_depth: float = float(path_node.get("river_depth"))
	var bank_height: float = float(path_node.get("river_bank_height"))

	var paint_texture_id: int = int(path_node.get("terrain_texture_id"))
	var paint_wetness: bool = is_river and bool(path_node.get("paint_bank_wetness"))
	var wetness_width: float = float(path_node.get("wetness_width"))

	var half_width: float = path_width * 0.5
	var total_radius: float = half_width + falloff_width + (wetness_width if paint_wetness else 0.0)

	# key: Vector2i(gx, gz), value: [min_dist, target_y]
	var samples: Dictionary = {}

	var skip_segments := PackedByteArray()
	if not is_river and path_node.has_method("get_carve_skip_segments"):
		skip_segments = path_node.call("get_carve_skip_segments")

	for i in range(world_pts.size() - 1):
		if skip_segments.size() > i and skip_segments[i] == 1:
			continue
		var a := world_pts[i]
		var b := world_pts[i + 1]
		var ab_xz := Vector2(b.x - a.x, b.z - a.z)
		var ab_len_sq := ab_xz.length_squared()
		if ab_len_sq < 0.000001:
			continue

		var min_x := minf(a.x, b.x) - total_radius
		var max_x := maxf(a.x, b.x) + total_radius
		var min_z := minf(a.z, b.z) - total_radius
		var max_z := maxf(a.z, b.z) + total_radius

		var gx0 := int(floor(min_x / spacing))
		var gx1 := int(ceil(max_x / spacing))
		var gz0 := int(floor(min_z / spacing))
		var gz1 := int(ceil(max_z / spacing))

		for gx in range(gx0, gx1 + 1):
			var wx := float(gx) * spacing
			for gz in range(gz0, gz1 + 1):
				var wz := float(gz) * spacing
				var ap_xz := Vector2(wx - a.x, wz - a.z)
				var t := clampf(ap_xz.dot(ab_xz) / ab_len_sq, 0.0, 1.0)
				var closest_xz := Vector2(a.x, a.z) + ab_xz * t
				var dist := Vector2(wx - closest_xz.x, wz - closest_xz.y).length()
				if dist > total_radius:
					continue

				var key := Vector2i(gx, gz)
				var interp_y := lerpf(a.y, b.y, t)
				if not samples.has(key) or dist < samples[key][0]:
					samples[key] = [dist, interp_y]

	if samples.is_empty():
		return {}

	# Yo'l daryo kanalini to'ldirib yubormasligi uchun (ko'prik ostida terrain o'zgarmaydi)
	var corridors: Array = []
	if not is_river and path_node.has_method("get_river_corridors"):
		corridors = path_node.call("get_river_corridors")

	var undo_after: Dictionary = {}

	for key: Vector2i in samples.keys():
		var world_pos := Vector3(float(key.x) * spacing, 0.0, float(key.y) * spacing)
		if not data.call("has_regionp", world_pos):
			continue

		if not corridors.is_empty() and _in_corridor(corridors, world_pos):
			continue

		var orig_h: float = data.call("get_height", world_pos)
		if not is_finite(orig_h):
			continue

		var orig_ctrl: int = int(data.call("get_control", world_pos))
		var orig_col: Color = data.call("get_pixel", MAP_COLOR, world_pos)

		backup[key] = {
			"h": orig_h,
			"c": orig_ctrl,
			"col": orig_col,
			"pos": world_pos,
		}

		var entry: Array = samples[key]
		var dist: float = entry[0]
		var curve_y: float = entry[1]

		var new_h := orig_h
		var new_col := orig_col

		if is_river:
			var water_y := curve_y + surface_offset
			var bank_edge := half_width * 1.15
			var outer_edge := bank_edge + falloff_width

			if dist <= bank_edge:
				var norm_d := clampf(dist / maxf(half_width, 0.01), 0.0, 1.15)
				if norm_d <= 1.0:
					var profile := 1.0 - norm_d * norm_d
					new_h = water_y - channel_depth * profile
				else:
					var bank_t := clampf((dist - half_width) / maxf(bank_edge - half_width, 0.01), 0.0, 1.0)
					new_h = lerpf(water_y, maxf(orig_h, water_y + bank_height), _quintic(bank_t))
			elif dist <= outer_edge and falloff_width > 0.001:
				var fall_t := clampf((dist - bank_edge) / falloff_width, 0.0, 1.0)
				var bank_top := maxf(orig_h, water_y + bank_height)
				new_h = lerpf(bank_top, orig_h, _quintic(fall_t))

			if paint_wetness and dist <= half_width + wetness_width:
				var wet_t := 1.0 - smoothstep(half_width * 0.85, half_width + wetness_width, dist)
				var target_alpha := lerpf(orig_col.a, 0.08, wet_t)
				new_col = Color(orig_col.r, orig_col.g, orig_col.b, minf(orig_col.a, target_alpha))
		else:
			# Yo'l uchun: terrain yo'l tagidan 3cm pastda bo'ladi -> terrain tepaga chiqib qolmaydi
			var road_bed_y := curve_y - 0.03
			var outer_edge := half_width + falloff_width
			if dist <= half_width:
				new_h = road_bed_y
			elif dist <= outer_edge and falloff_width > 0.001:
				var fall_t := clampf((dist - half_width) / falloff_width, 0.0, 1.0)
				new_h = lerpf(road_bed_y, orig_h, _quintic(fall_t))

		if not is_equal_approx(new_h, orig_h):
			data.call("set_height", world_pos, new_h)

		if paint_texture_id >= 0 and dist <= half_width + falloff_width * 0.35:
			var tex_blend := 1.0 - smoothstep(half_width * 0.85, half_width + falloff_width * 0.35, dist)
			if tex_blend > 0.05:
				data.call("set_control_auto", world_pos, false)
				data.call("set_control_overlay_id", world_pos, paint_texture_id)
				data.call("set_control_blend", world_pos, clampf(tex_blend, 0.0, 1.0))

		if not new_col.is_equal_approx(orig_col):
			data.call("set_pixel", MAP_COLOR, world_pos, new_col)

		if data.has_method("get_region_location") and data.has_method("set_region_modified"):
			var rloc: Vector2i = data.call("get_region_location", world_pos)
			data.call("set_region_modified", rloc, true)

		undo_after[key] = {
			"h": data.call("get_height", world_pos),
			"c": int(data.call("get_control", world_pos)),
			"col": data.call("get_pixel", MAP_COLOR, world_pos),
			"pos": world_pos,
		}

	_refresh_terrain(terrain, data)
	return undo_after


static func _in_corridor(corridors: Array, world_pos: Vector3) -> bool:
	for c in corridors:
		var r: Array = (c["index"] as RefCounted).call("nearest", world_pos)
		if float(r[0]) <= float(c["radius"]):
			return true
	return false


static func _quintic(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func restore_backup(terrain: Node3D, backup: Dictionary, refresh: bool = true) -> void:
	if backup.is_empty():
		return
	if not is_instance_valid(terrain) or not terrain.is_class("Terrain3D"):
		return
	var data: Object = terrain.get("data")
	if data == null:
		return

	for key in backup.keys():
		var rec: Dictionary = backup[key]
		var pos: Vector3 = rec["pos"]
		if not data.call("has_regionp", pos):
			continue
		data.call("set_height", pos, rec["h"])
		data.call("set_control", pos, rec["c"])
		data.call("set_pixel", MAP_COLOR, pos, rec["col"])
		if data.has_method("get_region_location") and data.has_method("set_region_modified"):
			var rloc: Vector2i = data.call("get_region_location", pos)
			data.call("set_region_modified", rloc, true)

	if refresh:
		_refresh_terrain(terrain, data)


static func apply_snapshot(terrain: Node3D, snapshot: Dictionary) -> void:
	restore_backup(terrain, snapshot, true)


static func _refresh_terrain(terrain: Node3D, data: Object) -> void:
	if data.has_method("update_maps"):
		data.call("update_maps", MAP_MAX, true, false)
	var col: Object = terrain.get("collision")
	if col != null and col.has_method("is_enabled") and col.call("is_enabled"):
		if col.has_method("build"):
			col.call("build")