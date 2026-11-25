@tool
@icon("res://addons/live_river_road/icons/road.svg")
extends "live_path_3d.gd"
## Yo'l. Daryo bilan kesishgan joyda avtomatik ko'prik quradi.

const BridgeBuilder := preload("res://addons/live_river_road/bridge_builder.gd")
const PathIndex := preload("res://addons/live_river_road/path_index.gd")
const JunctionSolver := preload("res://addons/live_river_road/junction_solver.gd")
const JunctionBuilder := preload("res://addons/live_river_road/junction_builder.gd")
const LampBuilder := preload("res://addons/live_river_road/lamp_builder.gd")

@export_group("Ko'priklar (Bridges)")
## Yo'l daryo bilan kesishganda avtomatik ko'prik quriladi.
@export var auto_bridges: bool = true:
	set(value):
		auto_bridges = value
		_queue_rebuild()

## Ko'prik shakli va sozlamalari. Bo'sh bo'lsa avtomatik yaratiladi.
@export var bridge_settings: LiveBridgeSettings:
	set(value):
		if bridge_settings != null and bridge_settings.changed.is_connected(_on_bridge_settings_changed):
			bridge_settings.changed.disconnect(_on_bridge_settings_changed)
		bridge_settings = value
		if bridge_settings != null:
			bridge_settings.changed.connect(_on_bridge_settings_changed)
		_on_bridge_settings_changed()

@export_tool_button("Ko'priklarni qayta qurish", "Reload") var btn_rebuild_bridges = rebuild_bridges

@export_group("Chorrahalar (Junctions)")
## Boshqa yo'l bilan kesishganda chorraha, yo'nalishlar ko'p bo'lsa aylana (roundabout) quriladi.
@export var auto_junctions: bool = true:
	set(value):
		auto_junctions = value
		_queue_rebuild()

## Chorraha va aylana sozlamalari. Bo'sh bo'lsa avtomatik yaratiladi.
@export var junction_settings: LiveJunctionSettings:
	set(value):
		if junction_settings != null and junction_settings.changed.is_connected(_on_junction_settings_changed):
			junction_settings.changed.disconnect(_on_junction_settings_changed)
		junction_settings = value
		if junction_settings != null:
			junction_settings.changed.connect(_on_junction_settings_changed)
		_on_junction_settings_changed()

@export_tool_button("Chorrahalarni qayta qurish", "Reload") var btn_rebuild_junctions = rebuild_junctions

@export_group("Yoritgichlar (Lamps)")
## Belgilangan nuqtalarga MultiMesh yordamida yoritgichlar qo'yadi (belgilash: toolbar > Yoritgich, Shift+Click).
@export var lamps_enabled: bool = false:
	set(value):
		lamps_enabled = value
		_queue_rebuild()

@export var lamp_settings: LiveLampSettings:
	set(value):
		if lamp_settings != null and lamp_settings.changed.is_connected(_on_lamp_settings_changed):
			lamp_settings.changed.disconnect(_on_lamp_settings_changed)
		lamp_settings = value
		if lamp_settings != null:
			lamp_settings.changed.connect(_on_lamp_settings_changed)
		_on_lamp_settings_changed()

@export_tool_button("Barcha belgilarni o'chirish", "Remove") var btn_clear_lamp_marks = clear_lamp_marks

@export_storage var lamp_point_indices := PackedInt32Array()
@export_storage var lamp_point_positions := PackedVector3Array()

var _bridge_spans: Array = []
var _hidden := PackedByteArray()
var _bridge_root: Node3D
var _bridge_sig: int = 0
var _settings_version: int = 0
var _force_bridges := false
var _junction_hidden := PackedByteArray()
var _jset_version: int = 0
var _lamp_version: int = 0
var _junction_root: Node3D
var _junction_nodes: Dictionary = {}
var _junction_sigs: Dictionary = {}
var _lamp_root: Node3D
var _lamp_sig: int = 0
var _force_lamps := false
var _raw_sig: int = 0
var _last_pts := PackedVector3Array()


func _init() -> void:
	path_width = 6.0
	surface_offset = 0.06
	cross_segments = 4
	skirt_depth = 0.25
	road_crown = 0.03
	height_smoothing = 3
	terrain_falloff = 6.0
	live_terrain_preview = true


func _ready() -> void:
	if bridge_settings == null:
		bridge_settings = LiveBridgeSettings.new()
	if junction_settings == null:
		junction_settings = LiveJunctionSettings.new()
	if lamp_settings == null:
		lamp_settings = LiveLampSettings.new()
	if not material_changed.is_connected(_apply_bridge_materials):
		material_changed.connect(_apply_bridge_materials)
	if not material_changed.is_connected(_apply_junction_materials):
		material_changed.connect(_apply_junction_materials)
	super._ready()


func _exit_tree() -> void:
	super._exit_tree()


func _on_bridge_settings_changed() -> void:
	_settings_version += 1
	_queue_rebuild()


## Daryo o'zgarganda (guruh orqali) chaqiriladi.
func on_river_changed() -> void:
	if auto_bridges:
		_queue_rebuild()


func rebuild_bridges() -> void:
	_force_bridges = true
	_queue_rebuild()


func get_bridge_count() -> int:
	return _bridge_spans.size()


# ---------------------------------------------------------------------------
#  Kesishmalarni aniqlash
# ---------------------------------------------------------------------------
func _collect_rivers() -> Array:
	var res: Array = []
	if not is_inside_tree():
		return res
	for n in get_tree().get_nodes_in_group(&"live_river_path"):
		if n == self or not is_instance_valid(n) or not (n is Node3D):
			continue
		if not (n as Node3D).is_visible_in_tree():
			continue
		res.append(n)
	return res


func _detect_spans(world_pts: PackedVector3Array, distances: PackedFloat32Array) -> Array:
	var spans: Array = []
	var st := bridge_settings
	if not auto_bridges or st == null or world_pts.size() < 2:
		return spans

	var intervals: Array = []
	for river in _collect_rivers():
		var rpts: PackedVector3Array = river.call("get_smoothed_world_points")
		if rpts.size() < 2:
			continue
		var half: float = float(river.get("path_width")) * 0.5
		var water_off: float = float(river.get("surface_offset"))
		var thr: float = half + st.bank_margin
		var idx := PathIndex.new()
		idx.build(rpts, maxf(thr * 1.05, 8.0))
		var inside := false
		var start := 0
		var wy := -INF
		for i in range(world_pts.size()):
			var r: Array = idx.nearest(world_pts[i])
			var is_in: bool = float(r[0]) <= thr
			if is_in:
				if not inside:
					inside = true
					start = i
					wy = -INF
				wy = maxf(wy, (r[1] as Vector3).y + water_off)
			elif inside:
				intervals.append({"a": start, "b": i - 1, "water_y": wy})
				inside = false
		if inside:
			intervals.append({"a": start, "b": world_pts.size() - 1, "water_y": wy})

	if intervals.is_empty():
		return spans

	# Bir oz kengaytirish va tartiblash
	var last := world_pts.size() - 1
	for iv in intervals:
		iv["a"] = maxi(int(iv["a"]) - 1, 0)
		iv["b"] = mini(int(iv["b"]) + 1, last)
	intervals.sort_custom(func(x, y): return int(x["a"]) < int(y["a"]))

	# Yaqin kesishmalarni birlashtirish
	var merged: Array = []
	for iv in intervals:
		if merged.is_empty():
			merged.append(iv)
			continue
		var prev: Dictionary = merged[merged.size() - 1]
		var gap := distances[int(iv["a"])] - distances[int(prev["b"])]
		if int(iv["a"]) <= int(prev["b"]) or gap < st.merge_gap:
			prev["b"] = maxi(int(prev["b"]), int(iv["b"]))
			prev["water_y"] = maxf(float(prev["water_y"]), float(iv["water_y"]))
		else:
			merged.append(iv)

	for iv in merged:
		var a: int = iv["a"]
		var b: int = iv["b"]
		if b <= a:
			continue
		var plan_len := 0.0
		for i in range(a, b):
			plan_len += Vector2(world_pts[i + 1].x - world_pts[i].x, world_pts[i + 1].z - world_pts[i].z).length()
		if plan_len < st.min_span_length:
			continue
		spans.append({"a": a, "b": b, "water_y": float(iv["water_y"]), "len": plan_len})
	return spans


# ---------------------------------------------------------------------------
#  Asosiy qurilish ilgaklari
# ---------------------------------------------------------------------------
func _prepare_build(world_pts: PackedVector3Array, distances: PackedFloat32Array) -> void:
	_bridge_spans = _detect_spans(world_pts, distances)
	_hidden.resize(maxi(world_pts.size() - 1, 0))
	_hidden.fill(0)
	for sp in _bridge_spans:
		for i in range(int(sp["a"]), int(sp["b"])):
			_hidden[i] = 1
	if _junction_hidden.size() == _hidden.size():
		for i in range(_hidden.size()):
			if _junction_hidden[i] == 1:
				_hidden[i] = 1
	_last_pts = world_pts


func _is_segment_hidden(i: int) -> bool:
	return i >= 0 and i < _hidden.size() and _hidden[i] == 1


func _post_height_pass(world_pts: PackedVector3Array, distances: PackedFloat32Array, left_y: PackedFloat32Array, right_y: PackedFloat32Array) -> void:
	var st := bridge_settings
	if st == null or _bridge_spans.is_empty():
		return
	var n := world_pts.size()
	var in_span := PackedByteArray()
	in_span.resize(n)
	in_span.fill(0)
	for sp in _bridge_spans:
		for i in range(int(sp["a"]), int(sp["b"]) + 1):
			in_span[i] = 1

	for sp in _bridge_spans:
		var a: int = sp["a"]
		var b: int = sp["b"]
		var ya := 0.5 * (left_y[a] + right_y[a])
		var yb := 0.5 * (left_y[b] + right_y[b])
		var water_y: float = sp["water_y"]
		var lift := BridgeBuilder.compute_lift(st, ya, yb, float(sp["len"]), water_y)
		var d0 := distances[a]
		var dl := maxf(distances[b] - d0, 0.001)
		var pts := PackedVector3Array()
		var dists := PackedFloat32Array()
		for i in range(a, b + 1):
			var u := (distances[i] - d0) / dl
			var y := BridgeBuilder.deck_level(st, ya, yb, u, lift)
			left_y[i] = y
			right_y[i] = y
			pts.append(Vector3(world_pts[i].x, y, world_pts[i].z))
			dists.append(distances[i])
		sp["pts"] = pts
		sp["dists"] = dists
		sp["width"] = path_width

		# Yo'l bilan silliq ulanish (ramp)
		var ramp := maxf(st.ramp_length, lift * 10.0)
		if ramp > 0.01:
			var y_start := ya + lift
			var y_end := yb + lift
			var i := a - 1
			while i >= 0 and in_span[i] == 0:
				var dd := distances[a] - distances[i]
				if dd >= ramp:
					break
				var w := 1.0 - smoothstep(0.0, ramp, dd)
				left_y[i] = lerpf(left_y[i], y_start, w)
				right_y[i] = lerpf(right_y[i], y_start, w)
				i -= 1
			i = b + 1
			while i < n and in_span[i] == 0:
				var dd2 := distances[i] - distances[b]
				if dd2 >= ramp:
					break
				var w2 := 1.0 - smoothstep(0.0, ramp, dd2)
				left_y[i] = lerpf(left_y[i], y_end, w2)
				right_y[i] = lerpf(right_y[i], y_end, w2)
				i += 1


func _after_mesh_built() -> void:
	_rebuild_bridge_nodes()
	_rebuild_junction_nodes()
	_rebuild_lamps()


# ---------------------------------------------------------------------------
#  Ko'prik node'larini yaratish
# ---------------------------------------------------------------------------
func _ground_height(p: Vector3) -> float:
	return _get_surface_height(p)


func _get_bridge_root() -> Node3D:
	if is_instance_valid(_bridge_root):
		return _bridge_root
	_bridge_root = get_node_or_null("LiveBridges") as Node3D
	if _bridge_root == null:
		_bridge_root = Node3D.new()
		_bridge_root.name = "LiveBridges"
		add_child(_bridge_root)  # owner o'rnatilmaydi: sahnaga saqlanmaydi, har safar qayta quriladi
	_bridge_root.top_level = true
	_bridge_root.global_transform = Transform3D.IDENTITY
	return _bridge_root


func _free_bridge_root() -> void:
	var root := get_node_or_null("LiveBridges")
	if root != null:
		root.queue_free()
	_bridge_root = null


func _rebuild_bridge_nodes() -> void:
	if not is_inside_tree():
		return
	var st := bridge_settings
	if _bridge_spans.is_empty() or st == null:
		_free_bridge_root()
		_bridge_sig = 0
		return

	var sig_parts: Array = []
	for sp in _bridge_spans:
		sig_parts.append([sp.get("pts", PackedVector3Array()), sp.get("water_y", 0.0)])
	var sig := hash([sig_parts, _settings_version, path_width])
	if sig == _bridge_sig and not _force_bridges and is_instance_valid(_bridge_root):
		return
	_force_bridges = false
	_bridge_sig = sig

	var root := _get_bridge_root()
	for ch in root.get_children():
		root.remove_child(ch)
		ch.queue_free()

	var ground := Callable(self, "_ground_height")
	var k := 0
	for sp in _bridge_spans:
		if not sp.has("pts"):
			continue
		var res: Dictionary = BridgeBuilder.build(sp, st, ground)
		var mi := MeshInstance3D.new()
		mi.name = "Bridge_%d" % k
		mi.set_meta("live_bridge", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if st.cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh: ArrayMesh = res["mesh"]
		if mesh.get_surface_count() > 0:
			mi.mesh = mesh
		root.add_child(mi)
		mi.set_meta("roles", res["roles"])
		_assign_bridge_materials(mi, st)
		if st.generate_collision and mi.mesh != null:
			var body := StaticBody3D.new()
			body.name = "Collision"
			var shape := CollisionShape3D.new()
			shape.shape = mi.mesh.create_trimesh_shape()
			body.add_child(shape)
			mi.add_child(body)
		if st.is_custom():
			_place_custom(mi, sp, st)
		k += 1


func _assign_bridge_materials(mi: MeshInstance3D, st: LiveBridgeSettings) -> void:
	if mi.mesh == null:
		return
	var roles: Array = mi.get_meta("roles", [])
	var mats := BridgeBuilder.make_materials(st, get_surface_material())
	for i in range(roles.size()):
		var m: Material = mats.get(roles[i])
		mi.set_surface_override_material(i, m)


func _apply_bridge_materials() -> void:
	if not is_instance_valid(_bridge_root) or bridge_settings == null:
		return
	for ch in _bridge_root.get_children():
		if ch is MeshInstance3D:
			_assign_bridge_materials(ch, bridge_settings)


func _place_custom(parent: MeshInstance3D, sp: Dictionary, st: LiveBridgeSettings) -> void:
	# Mesh
	if st.custom_mesh != null:
		var transforms := BridgeBuilder.custom_transforms(sp, st, st.custom_mesh.get_aabb())
		var idx := 0
		for t in transforms:
			var ci := MeshInstance3D.new()
			ci.name = "CustomMesh_%d" % idx
			ci.mesh = st.custom_mesh
			ci.transform = t
			if st.custom_material != null:
				ci.material_override = st.custom_material
			ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if st.cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(ci)
			if st.generate_collision:
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				shape.shape = st.custom_mesh.create_trimesh_shape()
				body.add_child(shape)
				ci.add_child(body)
			idx += 1
	# Sahna
	if st.custom_scene != null:
		var probe: Node = st.custom_scene.instantiate()
		var aabb := _scene_aabb(probe)
		probe.queue_free()
		var transforms2 := BridgeBuilder.custom_transforms(sp, st, aabb)
		var j := 0
		for t2 in transforms2:
			var inst: Node = st.custom_scene.instantiate()
			if inst is Node3D:
				(inst as Node3D).transform = t2
			inst.name = "CustomScene_%d" % j
			parent.add_child(inst)
			j += 1


func _scene_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var xf: Transform3D = it[1]
		if n is Node3D and n != node:
			xf = xf * (n as Node3D).transform
		if n is VisualInstance3D:
			var box: AABB = xf * (n as VisualInstance3D).get_aabb()
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for c in n.get_children():
			stack.append([c, xf])
	return result


# ---------------------------------------------------------------------------
#  Terrain carve uchun: daryo kanalini yo'l buzmasligi uchun
# ---------------------------------------------------------------------------
func get_river_corridors() -> Array:
	var res: Array = []
	if not auto_bridges or bridge_settings == null:
		return res
	for river in _collect_rivers():
		var rpts: PackedVector3Array = river.call("get_smoothed_world_points")
		if rpts.size() < 2:
			continue
		var radius: float = float(river.get("path_width")) * 0.5 * 1.15
		var idx := PathIndex.new()
		idx.build(rpts, maxf(radius * 1.05, 8.0))
		res.append({"index": idx, "radius": radius})
	return res


# ---------------------------------------------------------------------------
#  Chorrahalar va aylanalar
# ---------------------------------------------------------------------------
func _on_junction_settings_changed() -> void:
	_jset_version += 1
	JunctionSolver.invalidate()
	_queue_rebuild()


func rebuild_junctions() -> void:
	_junction_sigs.clear()
	JunctionSolver.invalidate()
	_queue_rebuild()


## Boshqa yo'l o'zgarganda (guruh orqali) chaqiriladi.
func on_road_changed(from_id: int) -> void:
	if from_id != get_instance_id() and auto_junctions:
		_queue_rebuild()


func _on_rebuild_finished() -> void:
	var raw := get_raw_smoothed_world_points()
	var sig := hash([raw, path_width, auto_junctions, _jset_version, is_visible_in_tree()])
	if sig != _raw_sig:
		_raw_sig = sig
		if is_inside_tree():
			get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, &"live_road_path", &"on_road_changed", get_instance_id())


func get_junction_entry() -> Dictionary:
	if not auto_junctions or junction_settings == null or not is_inside_tree() or not is_visible_in_tree():
		return {}
	var pts := get_raw_smoothed_world_points()
	if pts.size() < 2:
		return {}
	return {"id": get_instance_id(), "pts": pts, "hw": path_width * 0.5, "settings": junction_settings, "y_off": surface_offset}


func _junction_result() -> Dictionary:
	if not auto_junctions or junction_settings == null or not is_inside_tree():
		return {}
	var nodes: Array = []
	var ids: Array = []
	for n in get_tree().get_nodes_in_group(&"live_road_path"):
		if is_instance_valid(n) and n.has_method("get_junction_entry") and bool(n.get("auto_junctions")) and (n as Node3D).is_visible_in_tree():
			nodes.append(n)
			ids.append(n.get_instance_id())
	if nodes.size() < 2:
		return {}
	ids.sort()
	var key := hash(ids)
	var epoch := int(Engine.get_meta("lrr_epoch", 0))
	var res := JunctionSolver.peek(epoch, key)
	if res.is_empty():
		var entries: Array = []
		for n2 in nodes:
			var e: Dictionary = n2.call("get_junction_entry")
			if not e.is_empty():
				entries.append(e)
		res = JunctionSolver.solve(entries)
		JunctionSolver.store(epoch, key, res)
	return res


func _filter_smoothed_points(pts: PackedVector3Array) -> PackedVector3Array:
	_junction_hidden = PackedByteArray()
	var res := _junction_result()
	if res.is_empty():
		return pts
	var r = res["roads"].get(get_instance_id())
	if r == null:
		return pts
	if int(r["raw_hash"]) != hash(pts):
		JunctionSolver.invalidate()
		res = _junction_result()
		r = res["roads"].get(get_instance_id()) if not res.is_empty() else null
		if r == null or int(r["raw_hash"]) != hash(pts):
			return pts
	_junction_hidden = r["hidden"]
	return r["pts"]


func _get_junction_root() -> Node3D:
	if is_instance_valid(_junction_root):
		return _junction_root
	_junction_root = get_node_or_null("LiveJunctions") as Node3D
	if _junction_root == null:
		_junction_root = Node3D.new()
		_junction_root.name = "LiveJunctions"
		add_child(_junction_root)
	_junction_root.top_level = true
	_junction_root.global_transform = Transform3D.IDENTITY
	return _junction_root


func _free_junction_root() -> void:
	var root := get_node_or_null("LiveJunctions")
	if root != null:
		root.queue_free()
	_junction_root = null
	_junction_nodes.clear()
	_junction_sigs.clear()


func _rebuild_junction_nodes() -> void:
	if not is_inside_tree():
		return
	var res := _junction_result()
	var owned: Array = []
	if not res.is_empty():
		for cl in res["clusters"]:
			if int(cl["owner"]) == get_instance_id():
				owned.append(cl)
	if owned.is_empty():
		_free_junction_root()
		return
	var root := _get_junction_root()
	var keep := {}
	for cl in owned:
		var key = cl["key"]
		keep[key] = true
		var sig := hash([cl["arms"], cl["center"], cl["R_cut"], cl["ring"], _jset_version, path_width])
		var old = _junction_nodes.get(key)
		if old != null and is_instance_valid(old) and _junction_sigs.get(key) == sig:
			continue
		if old != null and is_instance_valid(old):
			root.remove_child(old)
			old.queue_free()
		var built: Dictionary = JunctionBuilder.build(cl, path_width)
		var mesh: ArrayMesh = built["mesh"]
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Junction_%d" % (absi(int(key)) % 1000000)
		mi.mesh = mesh
		mi.set_meta("roles", built["roles"])
		mi.set_meta("cluster", cl)
		root.add_child(mi)
		_assign_junction_materials(mi, cl)
		var st: LiveJunctionSettings = cl["settings"]
		if st.generate_collision:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = mesh.create_trimesh_shape()
			body.add_child(shape)
			mi.add_child(body)
		if bool(cl["ring"]) and st.island_scene != null:
			var inst: Node = st.island_scene.instantiate()
			if inst is Node3D:
				(inst as Node3D).position = Vector3((cl["center"] as Vector3).x, (cl["center"] as Vector3).y + st.island_curb_height, (cl["center"] as Vector3).z)
			mi.add_child(inst)
		_junction_nodes[key] = mi
		_junction_sigs[key] = sig
	for key2 in _junction_nodes.keys():
		if not keep.has(key2):
			var n3 = _junction_nodes[key2]
			if is_instance_valid(n3):
				n3.queue_free()
			_junction_nodes.erase(key2)
			_junction_sigs.erase(key2)


func _assign_junction_materials(mi: MeshInstance3D, cl: Dictionary) -> void:
	var st: LiveJunctionSettings = cl["settings"]
	var roles: Array = mi.get_meta("roles", [])
	for i in range(roles.size()):
		var m: Material = null
		match roles[i]:
			&"deck":
				m = get_surface_material()
			&"structure":
				m = st.curb_material
				if m == null:
					var sm := StandardMaterial3D.new()
					sm.albedo_color = st.curb_color
					sm.roughness = 0.9
					m = sm
			&"railing":
				m = st.island_material
				if m == null:
					var gm := StandardMaterial3D.new()
					gm.albedo_color = st.island_color
					gm.roughness = 1.0
					m = gm
		mi.set_surface_override_material(i, m)


func _apply_junction_materials() -> void:
	if not is_instance_valid(_junction_root):
		return
	for ch in _junction_root.get_children():
		if ch is MeshInstance3D and ch.has_meta("cluster"):
			_assign_junction_materials(ch, ch.get_meta("cluster"))


# ---------------------------------------------------------------------------
#  Yoritgichlar (MultiMesh)
# ---------------------------------------------------------------------------
func _on_lamp_settings_changed() -> void:
	_lamp_version += 1
	_queue_rebuild()


func has_lamp_mark(idx: int) -> bool:
	return lamp_point_indices.find(idx) >= 0


func set_lamp_mark(idx: int, on: bool) -> void:
	if curve == null or idx < 0 or idx >= curve.get_point_count():
		return
	var i := lamp_point_indices.find(idx)
	if on and i < 0:
		lamp_point_indices.append(idx)
		lamp_point_positions.append(curve.get_point_position(idx))
		if not lamps_enabled:
			lamps_enabled = true
	elif not on and i >= 0:
		lamp_point_indices.remove_at(i)
		lamp_point_positions.remove_at(i)
	_queue_rebuild()


func toggle_lamp_mark(idx: int) -> bool:
	set_lamp_mark(idx, not has_lamp_mark(idx))
	return has_lamp_mark(idx)


func clear_lamp_marks() -> void:
	lamp_point_indices = PackedInt32Array()
	lamp_point_positions = PackedVector3Array()
	_queue_rebuild()


func get_lamp_mark_world_positions() -> PackedVector3Array:
	var res := PackedVector3Array()
	if curve == null:
		return res
	for idx in lamp_point_indices:
		if idx < curve.get_point_count():
			res.append(to_global(curve.get_point_position(idx)))
	return res


## Nuqta o'chirilsa/siljisa, belgilarni eng yaqin nuqtaga qayta bog'laydi.
func _validate_lamp_marks() -> void:
	if curve == null:
		return
	var cnt := curve.get_point_count()
	var new_idx := PackedInt32Array()
	var new_pos := PackedVector3Array()
	for k in range(lamp_point_indices.size()):
		var idx := lamp_point_indices[k]
		var pos := lamp_point_positions[k] if k < lamp_point_positions.size() else Vector3.ZERO
		var found := -1
		if idx < cnt and curve.get_point_position(idx).distance_to(pos) <= 4.0:
			found = idx
		else:
			var best := 4.0
			for j in range(cnt):
				var d := curve.get_point_position(j).distance_to(pos)
				if d < best:
					best = d
					found = j
		if found >= 0 and new_idx.find(found) < 0:
			new_idx.append(found)
			new_pos.append(curve.get_point_position(found))
	lamp_point_indices = new_idx
	lamp_point_positions = new_pos


func _get_lamp_root() -> Node3D:
	if is_instance_valid(_lamp_root):
		return _lamp_root
	_lamp_root = get_node_or_null("LiveLamps") as Node3D
	if _lamp_root == null:
		_lamp_root = Node3D.new()
		_lamp_root.name = "LiveLamps"
		add_child(_lamp_root)
	_lamp_root.top_level = true
	_lamp_root.global_transform = Transform3D.IDENTITY
	return _lamp_root


func _free_lamp_root() -> void:
	var root := get_node_or_null("LiveLamps")
	if root != null:
		root.queue_free()
	_lamp_root = null


func _project_s(pts: PackedVector3Array, s: PackedFloat32Array, wp: Vector3) -> float:
	var best := INF
	var best_s := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 0.000001:
			t = clampf(((wp.x - a.x) * ab.x + (wp.z - a.z) * ab.y) / l2, 0.0, 1.0)
		var d := Vector2(a.x + ab.x * t - wp.x, a.z + ab.y * t - wp.z).length()
		if d < best:
			best = d
			best_s = lerpf(s[i], s[i + 1], t)
	return best_s


func _compute_lamp_transforms(st: LiveLampSettings) -> Array:
	var res: Array = []
	var pts := _last_pts
	if pts.size() < 2:
		return res
	var s := PathMath.arc_lengths(pts)
	var marks: Array = []
	for idx in lamp_point_indices:
		if idx < curve.get_point_count():
			marks.append(_project_s(pts, s, to_global(curve.get_point_position(idx))))
	marks.sort()
	var positions: Array = []
	if st.lamp_mode == LiveLampSettings.LampMode.POINTS:
		positions = marks
	else:
		var i := 0
		while i < marks.size():
			if i + 1 < marks.size():
				var a: float = marks[i]
				var b: float = marks[i + 1]
				var sp := maxf(st.spacing, 1.0)
				var n := int(floor((b - a) / sp))
				for k in range(n + 1):
					positions.append(a + float(k) * sp)
				if (b - a) - float(n) * sp > sp * 0.4:
					positions.append(b)
				i += 2
			else:
				positions.append(marks[i])
				i += 1
	var alt := 0
	for sv in positions:
		var seg := PathMath.seg_of(s, float(sv))
		if _is_segment_hidden(seg):
			continue
		var p := PathMath.point_at(pts, s, float(sv))
		var a2 := pts[seg]
		var b2 := pts[mini(seg + 1, pts.size() - 1)]
		var t := Vector3(b2.x - a2.x, 0.0, b2.z - a2.z)
		if t.length_squared() < 0.000001:
			continue
		t = t.normalized()
		var side := Vector3(-t.z, 0.0, t.x)
		var sides: Array = []
		match st.lamp_side:
			LiveLampSettings.LampSide.LEFT:
				sides = [-1.0]
			LiveLampSettings.LampSide.RIGHT:
				sides = [1.0]
			LiveLampSettings.LampSide.BOTH:
				sides = [-1.0, 1.0]
			_:
				sides = [-1.0 if alt % 2 == 0 else 1.0]
				alt += 1
		for sg in sides:
			var pos := p + side * float(sg) * (path_width * 0.5 + st.edge_offset)
			var y := p.y
			if st.ground_snap:
				var h := _get_surface_height(pos)
				if is_finite(h) and absf(h - p.y) < 1.5:
					y = h
			pos.y = y + st.height_offset
			var xaxis := -side * float(sg)
			var bs := Basis(xaxis, Vector3.UP, xaxis.cross(Vector3.UP))
			if st.custom_mesh != null:
				bs = bs * Basis(Vector3.UP, deg_to_rad(st.custom_rotation_y))
				bs = bs.scaled_local(st.custom_scale * st.lamp_scale)
			else:
				bs = bs.scaled_local(Vector3.ONE * st.lamp_scale)
			res.append(Transform3D(bs, pos))
	return res


func _lamp_lod_mesh(st: LiveLampSettings, level: int) -> Mesh:
	if level == 0:
		return st.custom_mesh if st.custom_mesh != null else LampBuilder.build_mesh(st, 0)
	if level == 1:
		return st.lod1_mesh if st.lod1_mesh != null else LampBuilder.build_mesh(st, 1)
	return st.lod2_mesh if st.lod2_mesh != null else LampBuilder.build_mesh(st, 2)


func _lamp_lod_material(st: LiveLampSettings, level: int) -> Material:
	if level == 0 and st.custom_mesh != null:
		return st.custom_material
	return null


func _create_lamp_multimesh(
	parent: Node3D,
	label: String,
	mesh: Mesh,
	transforms: Array,
	st: LiveLampSettings,
	lod_begin: float,
	lod_end: float
) -> MultiMeshInstance3D:
	if mesh == null or transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i] as Transform3D)
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = mm
	instance.material_override = _lamp_lod_material(st, 0) if label.ends_with("_LOD0") else null
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if st.cast_shadows and label.ends_with("_LOD0") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_begin = maxf(lod_begin, 0.0)
	instance.visibility_range_end = maxf(lod_end, 0.0)
	parent.add_child(instance)
	return instance


func _rebuild_lamps() -> void:
	if not is_inside_tree() or curve == null:
		return
	_validate_lamp_marks()
	var st := lamp_settings
	if not lamps_enabled or st == null or lamp_point_indices.is_empty() or _last_pts.size() < 2:
		_free_lamp_root()
		_lamp_sig = 0
		return
	var sig := hash([_geometry_sig, lamp_point_indices, lamp_point_positions, _lamp_version, path_width, _hidden])
	if sig == _lamp_sig and is_instance_valid(_lamp_root) and not _force_lamps:
		return
	_force_lamps = false
	_lamp_sig = sig
	var transforms := _compute_lamp_transforms(st)
	if transforms.is_empty():
		_free_lamp_root()
		return

	var root := _get_lamp_root()
	for ch in root.get_children():
		root.remove_child(ch)
		ch.queue_free()

	# Har bir fazoviy chunk va LOD alohida MultiMesh: uzoq chunk yaqin chunkni
	# ko'rinish/culling hisobida ushlab turmaydi.
	var chunks: Dictionary = {}
	var chunk_length := maxf(st.lod_chunk_length, 20.0)
	var path_distances := PathMath.arc_lengths(_last_pts)
	var all_lights: Array[OmniLight3D] = []
	var light_local := Vector3(st.arm_length, st.pole_height + st.arm_rise - 0.25, 0.0) if st.custom_mesh == null else Vector3(0.0, st.pole_height, 0.0)

	for xf_variant in transforms:
		var xf: Transform3D = xf_variant
		var chunk_id := int(floor(_project_s(_last_pts, path_distances, xf.origin) / chunk_length))
		if not chunks.has(chunk_id):
			chunks[chunk_id] = []
		(chunks[chunk_id] as Array).append(xf)

		if st.real_lights:
			var light := OmniLight3D.new()
			light.name = "LampLight_%d" % all_lights.size()
			light.light_color = st.light_color
			light.omni_range = st.light_range
			light.light_energy = st.light_energy
			light.shadow_enabled = false
			light.position = xf * light_local
			light.visible = false
			root.add_child(light)
			all_lights.append(light)

	var d0 := maxf(st.lod0_end_distance, 5.0)
	var d1 := maxf(st.lod1_end_distance, d0 + 5.0)
	var final_end := st.visibility_range
	var use_lods := st.lod_enabled
	var chunk_keys: Array = chunks.keys()
	chunk_keys.sort()
	for chunk_id in chunk_keys:
		var chunk_transforms: Array = chunks[chunk_id]
		var chunk_root := Node3D.new()
		chunk_root.name = "LampChunk_%d" % int(chunk_id)
		root.add_child(chunk_root)

		if not use_lods:
			_create_lamp_multimesh(chunk_root, "Lamps_LOD0", _lamp_lod_mesh(st, 0), chunk_transforms, st, 0.0, final_end)
			continue

		if final_end > 0.0 and final_end <= d0:
			_create_lamp_multimesh(chunk_root, "Lamps_LOD0", _lamp_lod_mesh(st, 0), chunk_transforms, st, 0.0, final_end)
		elif final_end > 0.0 and final_end <= d1:
			_create_lamp_multimesh(chunk_root, "Lamps_LOD0", _lamp_lod_mesh(st, 0), chunk_transforms, st, 0.0, d0)
			_create_lamp_multimesh(chunk_root, "Lamps_LOD1", _lamp_lod_mesh(st, 1), chunk_transforms, st, d0, final_end)
		else:
			_create_lamp_multimesh(chunk_root, "Lamps_LOD0", _lamp_lod_mesh(st, 0), chunk_transforms, st, 0.0, d0)
			_create_lamp_multimesh(chunk_root, "Lamps_LOD1", _lamp_lod_mesh(st, 1), chunk_transforms, st, d0, d1)
			_create_lamp_multimesh(chunk_root, "Lamps_LOD2", _lamp_lod_mesh(st, 2), chunk_transforms, st, d1, final_end)

	if st.real_lights and not all_lights.is_empty():
		var controller := load("res://addons/live_river_road/lamp_light_controller.gd").new() as Node3D
		controller.name = "LampLightController"
		root.add_child(controller)
		controller.call(
			"configure",
			all_lights,
			st.max_active_lights,
			st.light_activation_range,
			st.light_update_interval,
			st.night_mode_enabled
		)


func get_lamp_count() -> int:
	if not is_instance_valid(_lamp_root):
		return 0
	var total := 0
	for chunk in _lamp_root.get_children():
		if chunk is Node3D and String(chunk.name).begins_with("LampChunk_"):
			for lod in chunk.get_children():
				if lod is MultiMeshInstance3D and lod.multimesh != null:
					if String(lod.name).ends_with("_LOD0"):
						total += lod.multimesh.instance_count
	return total
