@tool
extends Path3D

const TerrainCarver := preload("res://addons/live_river_road/terrain_carver.gd")
const PathMath := preload("res://addons/live_river_road/path_math.gd")
const WATER_SHADER := preload("res://addons/live_river_road/shaders/live_water.gdshader")
const ROAD_SHADER := preload("res://addons/live_river_road/shaders/live_road.gdshader")

@export_group("Terrain")

@export var terrain: Node3D:
	set(value):
		if terrain == value:
			return
		_disconnect_terrain_signals()
		terrain = value
		_connect_terrain_signals()
		update_configuration_warnings()
		_queue_rebuild()

## Yangi qo'shilgan nuqtalarni avtomatik ravishda Terrain3D sirtiga yopishtiradi.
@export var auto_snap_new_points: bool = true

## X/Z bo'yicha yon tomonga surilganda nuqtalar terrain relyefi bo'ylab silliq sirpanadi (Y o'qida esa erkin siljiydi).
@export var follow_terrain_on_xz_move: bool = true

## Agar true bo'lsa, nuqtalarning Y balandligi doim terrainga qulflanib turadi.
@export var lock_points_to_terrain: bool = false:
	set(value):
		lock_points_to_terrain = value
		_queue_rebuild()

## Carving o'chiq bo'lganda mesh terrain tepasidan silliq yurib, yer ichiga kirib ketmasligini ta'minlaydi.
@export var conform_mesh_to_terrain: bool = true:
	set(value):
		conform_mesh_to_terrain = value
		_queue_rebuild()

@export_group("Geometry & Smoothing")

@export_range(0.5, 100.0, 0.5)
var path_width: float = 6.0:
	set(value):
		path_width = value
		_queue_rebuild()

@export_range(-20.0, 20.0, 0.05)
var surface_offset: float = 0.08:
	set(value):
		surface_offset = value
		_queue_rebuild()

@export_range(0.15, 5.0, 0.05)
var bake_interval: float = 0.45:
	set(value):
		bake_interval = value
		_queue_rebuild()

@export var auto_round_corners: bool = true:
	set(value):
		auto_round_corners = value
		_queue_rebuild()

@export_range(0, 8, 1)
var height_smoothing: int = 3:
	set(value):
		height_smoothing = value
		_queue_rebuild()

@export_range(1, 16, 1)
var cross_segments: int = 4:
	set(value):
		cross_segments = maxi(value, 1)
		_queue_rebuild()

@export_range(0.0, 2.0, 0.02)
var skirt_depth: float = 0.25:
	set(value):
		skirt_depth = value
		_queue_rebuild()

@export_range(0.0, 0.3, 0.005)
var road_crown: float = 0.03:
	set(value):
		road_crown = value
		_queue_rebuild()

@export var generate_collision: bool = false:
	set(value):
		generate_collision = value
		_queue_rebuild()

@export_group("Terrain Carving (Non-Destructive)")

@export var live_terrain_preview: bool = true:
	set(value):
		if live_terrain_preview == value:
			return
		live_terrain_preview = value
		if not live_terrain_preview:
			revert_terrain_carving()
		else:
			_queue_rebuild()
			_schedule_terrain_carve()

@export_range(0.5, 40.0, 0.5)
var terrain_falloff: float = 7.0:
	set(value):
		terrain_falloff = value
		if live_terrain_preview:
			_schedule_terrain_carve()

@export_range(0.1, 10.0, 0.1)
var river_depth: float = 1.4:
	set(value):
		river_depth = value
		if live_terrain_preview:
			_schedule_terrain_carve()

@export_range(0.0, 3.0, 0.05)
var river_bank_height: float = 0.35:
	set(value):
		river_bank_height = value
		if live_terrain_preview:
			_schedule_terrain_carve()

@export_range(-1, 31, 1)
var terrain_texture_id: int = -1:
	set(value):
		terrain_texture_id = value
		if live_terrain_preview:
			_schedule_terrain_carve()

@export var paint_bank_wetness: bool = true:
	set(value):
		paint_bank_wetness = value
		if live_terrain_preview:
			_schedule_terrain_carve()

@export_range(0.5, 15.0, 0.5)
var wetness_width: float = 2.5:
	set(value):
		wetness_width = value
		if live_terrain_preview:
			_schedule_terrain_carve()

@export_tool_button("Snap Points to Terrain", "ToolMove") var btn_snap = snap_points_now
@export_tool_button("Apply Terrain Carving", "Bake") var btn_carve = apply_terrain_carving
@export_tool_button("Revert Terrain Carving", "Reload") var btn_revert = revert_terrain_carving
@export_tool_button("Rebuild Mesh", "MeshInstance3D") var btn_rebuild = _rebuild

@export_group("Material va Tekstura")
## Tayyor material bilan to'liq almashtirish (StandardMaterial3D, ShaderMaterial, ...). Bo'sh = standart shader.
@export var custom_material: Material = null:
	set(value):
		custom_material = value
		_apply_material()
@export_group("Yo'l: ko'rinish")
@export var road_color: Color = Color(0.16, 0.16, 0.17):
	set(value):
		road_color = value
		_sync_material_params()
@export var wear_color: Color = Color(0.22, 0.22, 0.23):
	set(value):
		wear_color = value
		_sync_material_params()
@export var shoulder_color: Color = Color(0.26, 0.23, 0.19):
	set(value):
		shoulder_color = value
		_sync_material_params()
@export_range(0.2, 1.0, 0.02) var road_roughness: float = 0.88:
	set(value):
		road_roughness = value
		_sync_material_params()
@export_range(1.0, 30.0, 0.5, "or_greater") var grain_scale: float = 12.0:
	set(value):
		grain_scale = value
		_sync_material_params()
@export_range(0.0, 1.0, 0.02, "or_greater") var bump_strength: float = 0.18:
	set(value):
		bump_strength = value
		_sync_material_params()
@export_range(0.0, 0.25, 0.01) var edge_blend: float = 0.08:
	set(value):
		edge_blend = value
		_sync_material_params()
@export_range(0.0, 1.0, 0.01) var shoulder_amount: float = 0.65:
	set(value):
		shoulder_amount = value
		_sync_material_params()
@export_range(0.0, 1.0, 0.01) var tire_wear_strength: float = 0.35:
	set(value):
		tire_wear_strength = value
		_sync_material_params()
@export_group("Yo'l: chiziqlar")
@export var show_center_line: bool = false:
	set(value):
		show_center_line = value
		_sync_material_params()
@export var line_color: Color = Color(0.86, 0.73, 0.28):
	set(value):
		line_color = value
		_sync_material_params()
@export_range(0.004, 0.1, 0.001) var line_width: float = 0.016:
	set(value):
		line_width = value
		_sync_material_params()
@export var solid_center_line: bool = false:
	set(value):
		solid_center_line = value
		_sync_material_params()
@export_range(0.5, 10.0, 0.1, "or_greater") var dash_period: float = 2.5:
	set(value):
		dash_period = value
		_sync_material_params()
@export_range(0.1, 0.95, 0.01) var dash_fill: float = 0.56:
	set(value):
		dash_fill = value
		_sync_material_params()
@export var show_edge_lines: bool = false:
	set(value):
		show_edge_lines = value
		_sync_material_params()
@export var edge_line_color: Color = Color(0.9, 0.9, 0.88):
	set(value):
		edge_line_color = value
		_sync_material_params()
@export_range(0.02, 0.25, 0.005) var edge_line_inset: float = 0.08:
	set(value):
		edge_line_inset = value
		_sync_material_params()
@export_group("Yo'l: tekstura")
## Yo'l uchun PBR tekstura to'plami (albedo, normal, roughness, AO).
@export var road_texture_set: LiveTextureSet = null:
	set(value):
		if road_texture_set != null and road_texture_set.changed.is_connected(_sync_material_params):
			road_texture_set.changed.disconnect(_sync_material_params)
		road_texture_set = value
		if road_texture_set != null and not road_texture_set.changed.is_connected(_sync_material_params):
			road_texture_set.changed.connect(_sync_material_params)
		_sync_material_params()
@export_group("Suv: ko'rinish")
@export var shallow_color: Color = Color(0.08, 0.36, 0.35):
	set(value):
		shallow_color = value
		_sync_material_params()
@export var deep_color: Color = Color(0.02, 0.11, 0.17):
	set(value):
		deep_color = value
		_sync_material_params()
@export var sky_tint: Color = Color(0.55, 0.74, 0.88):
	set(value):
		sky_tint = value
		_sync_material_params()
@export_range(0.1, 8.0, 0.05, "or_greater") var water_clarity: float = 1.75:
	set(value):
		water_clarity = value
		_sync_material_params()
@export_range(0.1, 1.0, 0.02) var min_opacity: float = 0.62:
	set(value):
		min_opacity = value
		_sync_material_params()
@export_range(0.01, 0.6, 0.01) var edge_fade_depth: float = 0.06:
	set(value):
		edge_fade_depth = value
		_sync_material_params()
@export_range(0.0, 4.0, 0.02, "or_greater") var flow_speed: float = 0.48:
	set(value):
		flow_speed = value
		_sync_material_params()
@export_range(0.2, 8.0, 0.05, "or_greater") var ripple_scale: float = 1.85:
	set(value):
		ripple_scale = value
		_sync_material_params()
@export_range(0.0, 1.5, 0.02, "or_greater") var ripple_strength: float = 0.42:
	set(value):
		ripple_strength = value
		_sync_material_params()
@export_range(0.0, 0.08, 0.002) var refraction_strength: float = 0.025:
	set(value):
		refraction_strength = value
		_sync_material_params()
@export_range(1.0, 8.0, 0.1) var fresnel_power: float = 4.5:
	set(value):
		fresnel_power = value
		_sync_material_params()
@export_range(0.01, 0.35, 0.005) var water_roughness: float = 0.035:
	set(value):
		water_roughness = value
		_sync_material_params()
@export_range(0.0, 1.0, 0.05) var water_specular: float = 0.85:
	set(value):
		water_specular = value
		_sync_material_params()
@export_range(0.0, 1.0, 0.02) var caustics_strength: float = 0.32:
	set(value):
		caustics_strength = value
		_sync_material_params()
@export_group("Suv: ko'pik")
@export_range(0.0, 1.0, 0.02) var foam_intensity: float = 0.30:
	set(value):
		foam_intensity = value
		_sync_material_params()
@export var foam_color: Color = Color(0.88, 0.93, 0.95):
	set(value):
		foam_color = value
		_sync_material_params()
@export_range(0.0, 0.5, 0.01) var foam_depth: float = 0.10:
	set(value):
		foam_depth = value
		_sync_material_params()
@export_group("Suv: tekstura")
## Suv to'lqini uchun birinchi normal map.
@export var water_normal_a: Texture2D = null:
	set(value):
		water_normal_a = value
		_sync_material_params()
## Ikkinchi normal map (boshqa tezlik va masshtabda aralashadi).
@export var water_normal_b: Texture2D = null:
	set(value):
		water_normal_b = value
		_sync_material_params()
@export var water_normal_tiling: Vector2 = Vector2(1.0, 1.0):
	set(value):
		water_normal_tiling = value
		_sync_material_params()
@export_range(0.0, 2.0, 0.01, "or_greater") var water_normal_strength: float = 0.6:
	set(value):
		water_normal_strength = value
		_sync_material_params()
## Qirg'oq ko'pigi uchun tekstura (kulrang).
@export var foam_texture: Texture2D = null:
	set(value):
		foam_texture = value
		_sync_material_params()
@export_range(0.1, 10.0, 0.1, "or_greater") var foam_texture_scale: float = 1.0:
	set(value):
		foam_texture_scale = value
		_sync_material_params()

@export_tool_button("Materialni tahrirlash (nusxa)", "Edit") var btn_edit_material = make_material_editable
@export_tool_button("Standart materialga qaytish", "Reload") var btn_reset_material = reset_material

const ROAD_ONLY_PROPS: Array[String] = ["road_color", "wear_color", "shoulder_color", "road_roughness", "grain_scale", "bump_strength", "edge_blend", "shoulder_amount", "tire_wear_strength", "show_center_line", "line_color", "line_width", "solid_center_line", "dash_period", "dash_fill", "show_edge_lines", "edge_line_color", "edge_line_inset", "road_texture_set"]
const RIVER_ONLY_PROPS: Array[String] = ["shallow_color", "deep_color", "sky_tint", "water_clarity", "min_opacity", "edge_fade_depth", "flow_speed", "ripple_scale", "ripple_strength", "refraction_strength", "fresnel_power", "water_roughness", "water_specular", "caustics_strength", "foam_intensity", "foam_color", "foam_depth", "water_normal_a", "water_normal_b", "water_normal_tiling", "water_normal_strength", "foam_texture", "foam_texture_scale"]

## Material yoki shader parametrlari o'zgarganda chiqadi.
signal material_changed
## Yo'lning geometriyasi (nuqtalar, kenglik) o'zgarganda chiqadi.
signal geometry_changed

@export_storage var _terrain_backup: Dictionary = {}

var _surface: MeshInstance3D
var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _generated_material: ShaderMaterial
var _updating := false
var _rebuild_queued := false
var _carve_timer: Timer
var _connected_terrain_data: Object = null
var _prev_world_points: PackedVector3Array = PackedVector3Array()
var _points_initialized := false
var _geometry_sig: int = 0
var _emitted_sig: int = -1


func _ready() -> void:
	set_notify_transform(true)

	if curve == null:
		curve = Curve3D.new()

	curve.bake_interval = bake_interval

	if not curve_changed.is_connected(_on_curve_changed):
		curve_changed.connect(_on_curve_changed)

	_setup_carve_timer()
	_connect_terrain_signals()
	_find_or_create_surface()
	_cache_prev_points()
	_points_initialized = true
	_rebuild()


func _enter_tree() -> void:
	add_to_group(&"live_river_path" if _is_river() else &"live_road_path")


func _exit_tree() -> void:
	_disconnect_terrain_signals()
	if is_inside_tree():
		if _is_river():
			get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, &"live_road_path", &"on_river_changed")
		else:
			get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, &"live_road_path", &"on_road_changed", get_instance_id())


func _setup_carve_timer() -> void:
	if not Engine.is_editor_hint() or _carve_timer != null:
		return
	_carve_timer = Timer.new()
	_carve_timer.one_shot = true
	_carve_timer.wait_time = 0.08
	_carve_timer.timeout.connect(_on_carve_timer_timeout)
	add_child(_carve_timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if is_inside_tree():
			_cache_prev_points()
			_queue_rebuild()


func _on_curve_changed() -> void:
	if not _updating:
		_queue_rebuild()


func _on_terrain_maps_edited(_edited_area: AABB) -> void:
	if not _updating and is_inside_tree():
		_queue_rebuild()


func _connect_terrain_signals() -> void:
	var data := _get_terrain_data()
	if data != null and data.has_signal("maps_edited"):
		if not data.is_connected("maps_edited", _on_terrain_maps_edited):
			data.connect("maps_edited", _on_terrain_maps_edited)
		_connected_terrain_data = data


func _disconnect_terrain_signals() -> void:
	if is_instance_valid(_connected_terrain_data):
		if _connected_terrain_data.has_signal("maps_edited") and _connected_terrain_data.is_connected("maps_edited", _on_terrain_maps_edited):
			_connected_terrain_data.disconnect("maps_edited", _on_terrain_maps_edited)
	_connected_terrain_data = null


func _find_or_create_surface() -> void:
	_surface = get_node_or_null("LiveSurface") as MeshInstance3D

	if _surface == null:
		_surface = MeshInstance3D.new()
		_surface.name = "LiveSurface"
		add_child(_surface)

		if Engine.is_editor_hint() and get_tree() != null:
			var root := get_tree().edited_scene_root
			if root != null:
				_surface.owner = root

	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_material()


func _apply_material() -> void:
	if _surface == null:
		return

	if custom_material != null:
		_surface.material_override = custom_material
		material_changed.emit()
		return

	if _generated_material == null:
		_generated_material = ShaderMaterial.new()

	_generated_material.shader = WATER_SHADER if _is_river() else ROAD_SHADER
	_surface.material_override = _generated_material
	_sync_material_params()


## Hozirgi (yo'l) materialini qaytaradi. Ko'prik usti uchun ishlatiladi.
func get_surface_material() -> Material:
	if custom_material != null:
		return custom_material
	return _generated_material


func make_material_editable() -> void:
	if _generated_material == null:
		_apply_material()
	if _generated_material != null:
		custom_material = _generated_material.duplicate()
		notify_property_list_changed()


func reset_material() -> void:
	custom_material = null
	notify_property_list_changed()


func _sync_material_params() -> void:
	if custom_material != null or _generated_material == null:
		return

	var m := _generated_material
	if _is_river():
		m.set_shader_parameter("shallow_color", shallow_color)
		m.set_shader_parameter("deep_color", deep_color)
		m.set_shader_parameter("sky_tint", sky_tint)
		m.set_shader_parameter("clarity", water_clarity)
		m.set_shader_parameter("min_opacity", min_opacity)
		m.set_shader_parameter("edge_fade_depth", edge_fade_depth)
		m.set_shader_parameter("flow_speed", flow_speed)
		m.set_shader_parameter("ripple_scale", ripple_scale)
		m.set_shader_parameter("ripple_strength", ripple_strength)
		m.set_shader_parameter("refraction_strength", refraction_strength)
		m.set_shader_parameter("fresnel_power", fresnel_power)
		m.set_shader_parameter("water_roughness", water_roughness)
		m.set_shader_parameter("water_specular", water_specular)
		m.set_shader_parameter("caustics_strength", caustics_strength)
		m.set_shader_parameter("foam_intensity", foam_intensity)
		m.set_shader_parameter("foam_color", foam_color)
		m.set_shader_parameter("foam_depth", foam_depth)
		m.set_shader_parameter("use_normal_textures", water_normal_a != null or water_normal_b != null)
		m.set_shader_parameter("water_normal_a", water_normal_a if water_normal_a != null else water_normal_b)
		m.set_shader_parameter("water_normal_b", water_normal_b if water_normal_b != null else water_normal_a)
		m.set_shader_parameter("normal_tiling", water_normal_tiling)
		m.set_shader_parameter("normal_texture_strength", water_normal_strength)
		m.set_shader_parameter("use_foam_texture", foam_texture != null)
		m.set_shader_parameter("foam_texture", foam_texture)
		m.set_shader_parameter("foam_texture_scale", foam_texture_scale)
	else:
		m.set_shader_parameter("road_color", road_color)
		m.set_shader_parameter("wear_color", wear_color)
		m.set_shader_parameter("shoulder_color", shoulder_color)
		m.set_shader_parameter("road_roughness", road_roughness)
		m.set_shader_parameter("grain_scale", grain_scale)
		m.set_shader_parameter("bump_strength", bump_strength)
		m.set_shader_parameter("edge_blend", edge_blend)
		m.set_shader_parameter("shoulder_amount", shoulder_amount)
		m.set_shader_parameter("tire_wear_strength", tire_wear_strength)
		m.set_shader_parameter("show_center_line", show_center_line)
		m.set_shader_parameter("line_color", line_color)
		m.set_shader_parameter("line_width", line_width)
		m.set_shader_parameter("solid_center_line", solid_center_line)
		m.set_shader_parameter("dash_period", dash_period)
		m.set_shader_parameter("dash_fill", dash_fill)
		m.set_shader_parameter("show_edge_lines", show_edge_lines)
		m.set_shader_parameter("edge_line_color", edge_line_color)
		m.set_shader_parameter("edge_line_inset", edge_line_inset)
		if road_texture_set != null:
			road_texture_set.apply_to_road_shader(m)
		else:
			m.set_shader_parameter("use_textures", false)
			m.set_shader_parameter("use_normal_texture", false)
			m.set_shader_parameter("use_roughness_texture", false)
			m.set_shader_parameter("use_ao_texture", false)
	material_changed.emit()


func _validate_property(property: Dictionary) -> void:
	var pname: String = property.name
	if _is_river():
		if pname in ROAD_ONLY_PROPS:
			property.usage = PROPERTY_USAGE_STORAGE
	else:
		if pname in RIVER_ONLY_PROPS:
			property.usage = PROPERTY_USAGE_STORAGE


func _is_river() -> bool:
	return false


## Tekstura paneli uchun: "node", "settings", "road_ts", "struct_ts", "rail_ts" nishonlarini topadi.
func get_panel_target(key: String, create: bool) -> Object:
	match key:
		"node":
			return self
		"settings":
			var s: Object = get("bridge_settings")
			if s == null and create and has_method("rebuild_bridges"):
				s = LiveBridgeSettings.new()
				set("bridge_settings", s)
			return s
		"junction":
			var js: Object = get("junction_settings")
			if js == null and create and has_method("rebuild_junctions"):
				js = LiveJunctionSettings.new()
				set("junction_settings", js)
			return js
		"lamp":
			var ls: Object = get("lamp_settings")
			if ls == null and create and has_method("clear_lamp_marks"):
				ls = LiveLampSettings.new()
				set("lamp_settings", ls)
			return ls
		"road_ts":
			var t: Object = get("road_texture_set")
			if t == null and create:
				t = LiveTextureSet.new()
				set("road_texture_set", t)
			return t
		"struct_ts", "rail_ts":
			var st: Object = get_panel_target("settings", create)
			if st == null:
				return null
			var prop := "structure_texture_set" if key == "struct_ts" else "railing_texture_set"
			var t2: Object = st.get(prop)
			if t2 == null and create:
				t2 = LiveTextureSet.new()
				st.set(prop, t2)
			return t2
	return null


func set_target_property(key: String, prop: String, value: Variant) -> void:
	var o := get_panel_target(key, true)
	if o != null:
		o.set(prop, value)


# --- Subklasslar (LiveRoad3D) uchun ilgaklar ---
func _prepare_build(_world_pts: PackedVector3Array, _distances: PackedFloat32Array) -> void:
	pass


func _post_height_pass(_world_pts: PackedVector3Array, _distances: PackedFloat32Array, _left_y: PackedFloat32Array, _right_y: PackedFloat32Array) -> void:
	pass


func _is_segment_hidden(_i: int) -> bool:
	return false


func _after_mesh_built() -> void:
	pass


func is_live_path() -> bool:
	return true


func _get_terrain_data() -> Object:
	if not is_instance_valid(terrain):
		return null

	if not terrain.is_class("Terrain3D"):
		return null

	return terrain.get("data")


func _get_surface_height(world_pos: Vector3) -> float:
	var data := _get_terrain_data()
	if data == null:
		return NAN

	if data.has_method("get_surface_height"):
		return data.call("get_surface_height", world_pos)

	return NAN


func _get_uncarved_height(world_pos: Vector3) -> float:
	if not _terrain_backup.is_empty() and is_instance_valid(terrain):
		var spacing: float = 1.0
		if terrain.get("vertex_spacing") != null:
			spacing = maxf(float(terrain.get("vertex_spacing")), 0.1)
		var gx := int(round(world_pos.x / spacing))
		var gz := int(round(world_pos.z / spacing))
		var key := Vector2i(gx, gz)
		if _terrain_backup.has(key):
			return float(_terrain_backup[key]["h"])
	return _get_surface_height(world_pos)


func _cache_prev_points() -> void:
	_prev_world_points.clear()
	if curve == null:
		return
	for i in range(curve.get_point_count()):
		_prev_world_points.append(to_global(curve.get_point_position(i)))


func snap_points_now() -> void:
	if curve == null or _get_terrain_data() == null:
		return
	_updating = true
	_snap_all_points()
	_cache_prev_points()
	_updating = false
	_rebuild()


func _snap_all_points() -> void:
	if curve == null or _get_terrain_data() == null:
		return
	for i in range(curve.get_point_count()):
		var local_pos := curve.get_point_position(i)
		var world_pos := to_global(local_pos)
		var height := _get_uncarved_height(world_pos)
		if not is_finite(height):
			continue
		var snapped_local := to_local(Vector3(world_pos.x, height, world_pos.z))
		if not local_pos.is_equal_approx(snapped_local):
			curve.set_point_position(i, snapped_local)


func _sync_points_with_terrain() -> void:
	if curve == null or _get_terrain_data() == null:
		_cache_prev_points()
		return

	if lock_points_to_terrain:
		_snap_all_points()
		_cache_prev_points()
		return

	var count := curve.get_point_count()
	if not _points_initialized:
		_cache_prev_points()
		_points_initialized = true
		return

	var prev_count := _prev_world_points.size()

	if count > prev_count:
		# Yangi nuqta qo'shilgan (Godot '+' tugmasi, Shift+Click yoki Inspector orqali)
		if auto_snap_new_points:
			var insert_idx := count - 1
			for i in range(prev_count):
				var cw := to_global(curve.get_point_position(i))
				if not cw.is_equal_approx(_prev_world_points[i]):
					insert_idx = i
					break

			for i in range(insert_idx, count):
				if i < prev_count and i + (count - prev_count) < count:
					# Faqat oraga qo'shilgan bitta nuqtani snap qilish
					if i != insert_idx:
						continue
				var local_pos := curve.get_point_position(i)
				var world_pos := to_global(local_pos)
				var h := _get_uncarved_height(world_pos)
				if is_finite(h):
					curve.set_point_position(i, to_local(Vector3(world_pos.x, h, world_pos.z)))
	elif count == prev_count and follow_terrain_on_xz_move:
		# Mavjud nuqta surilgan: Y o'zgarmagan bo'lsa (faqat X/Z surilgan), terrain bo'ylab sirpanadi;
		# Y o'zgargan bo'lsa (tepaga/pastga tortilgan), foydalanuvchi tanlagan Y saqlanadi!
		for i in range(count):
			var local_pos := curve.get_point_position(i)
			var curr_w := to_global(local_pos)
			var prev_w := _prev_world_points[i]
			var y_changed: bool = absf(curr_w.y - prev_w.y) > 0.002
			var xz_changed: bool = Vector2(curr_w.x - prev_w.x, curr_w.z - prev_w.z).length_squared() > 0.000004
			if xz_changed and not y_changed:
				var old_h := _get_uncarved_height(prev_w)
				var new_h := _get_uncarved_height(curr_w)
				if is_finite(old_h) and is_finite(new_h):
					var offset_y := prev_w.y - old_h
					curr_w.y = new_h + offset_y
					curve.set_point_position(i, to_local(curr_w))

	_cache_prev_points()


func enforce_downhill() -> void:
	if curve == null or curve.get_point_count() < 2:
		return
	_updating = true
	var prev_world := to_global(curve.get_point_position(0))
	for i in range(1, curve.get_point_count()):
		var local_p := curve.get_point_position(i)
		var world_p := to_global(local_p)
		if world_p.y > prev_world.y - 0.05:
			world_p.y = prev_world.y - 0.05
			curve.set_point_position(i, to_local(world_p))
		prev_world = world_p
	_cache_prev_points()
	_updating = false
	_rebuild()


func apply_terrain_carving() -> Dictionary:
	if _updating:
		return {}
	_updating = true
	var after := TerrainCarver.carve_path(self, _terrain_backup)
	_updating = false
	return after


func revert_terrain_carving() -> void:
	if _terrain_backup.is_empty():
		return
	_updating = true
	TerrainCarver.restore_backup(terrain, _terrain_backup, true)
	_terrain_backup.clear()
	_updating = false
	_queue_rebuild()


func get_backup_copy() -> Dictionary:
	return _terrain_backup.duplicate(true)


func restore_snapshot(snapshot: Dictionary) -> void:
	_updating = true
	TerrainCarver.apply_snapshot(terrain, snapshot)
	_terrain_backup = snapshot.duplicate(true)
	_updating = false


func _schedule_terrain_carve() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _carve_timer == null:
		_setup_carve_timer()
	if _carve_timer != null:
		_carve_timer.start()


func _on_carve_timer_timeout() -> void:
	if live_terrain_preview and is_inside_tree():
		apply_terrain_carving()


func _bump_epoch() -> void:
	Engine.set_meta("lrr_epoch", int(Engine.get_meta("lrr_epoch", 0)) + 1)


func _queue_rebuild() -> void:
	_bump_epoch()
	if not is_inside_tree() or _updating:
		return
	if not _rebuild_queued:
		_rebuild_queued = true
		call_deferred("_execute_queued_rebuild")


func _execute_queued_rebuild() -> void:
	_rebuild_queued = false
	_rebuild()


func _has_custom_handles() -> bool:
	if curve == null:
		return false
	for i in range(curve.get_point_count()):
		if not curve.get_point_in(i).is_zero_approx() or not curve.get_point_out(i).is_zero_approx():
			return true
	return false


static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


## Filtrlanmagan (xom) silliqlangan nuqtalar.
func get_raw_smoothed_world_points() -> PackedVector3Array:
	var world_pts := PackedVector3Array()
	if curve == null or curve.get_point_count() < 2:
		return world_pts

	var step := maxf(bake_interval, 0.15)
	var use_catmull := auto_round_corners and curve.get_point_count() >= 3 and not _has_custom_handles()

	if use_catmull:
		var ctrl := PackedVector3Array()
		for i in range(curve.get_point_count()):
			ctrl.append(to_global(curve.get_point_position(i)))

		for i in range(ctrl.size() - 1):
			var p1 := ctrl[i]
			var p2 := ctrl[i + 1]
			var seg_len := p1.distance_to(p2)
			if seg_len < 0.001:
				continue

			var p0 := ctrl[i - 1] if i > 0 else (2.0 * p1 - p2)
			var p3 := ctrl[i + 2] if i + 2 < ctrl.size() else (2.0 * p2 - p1)

			if i > 0:
				var d01 := p1.distance_to(p0)
				if d01 > 0.001:
					p0 = p1 + (p0 - p1).normalized() * minf(d01, seg_len * 1.4)
			if i + 2 < ctrl.size():
				var d23 := p2.distance_to(p3)
				if d23 > 0.001:
					p3 = p2 + (p3 - p2).normalized() * minf(d23, seg_len * 1.4)

			var subdiv := maxi(int(ceil(seg_len / step)), 2)
			var start_k := 0 if i == 0 else 1
			for k in range(start_k, subdiv + 1):
				var t := float(k) / float(subdiv)
				var wp := _catmull_rom(p0, p1, p2, p3, t)
				if world_pts.is_empty() or world_pts[world_pts.size() - 1].distance_squared_to(wp) > 0.0004:
					world_pts.append(wp)
	else:
		var raw_points := curve.get_baked_points()
		for pt in raw_points:
			var wp := to_global(pt)
			if world_pts.is_empty() or world_pts[world_pts.size() - 1].distance_squared_to(wp) > 0.0004:
				world_pts.append(wp)

	return world_pts


## Mesh, carve va boshqalar ishlatadigan nuqtalar (chorraha kesimlari va balandligi qo'llangan).
func get_smoothed_world_points() -> PackedVector3Array:
	return _filter_smoothed_points(get_raw_smoothed_world_points())


func _filter_smoothed_points(pts: PackedVector3Array) -> PackedVector3Array:
	return pts


func _on_rebuild_finished() -> void:
	pass


func _build_mesh() -> void:
	if _surface == null:
		_find_or_create_surface()

	var world_pts := get_smoothed_world_points()
	if world_pts.size() < 2:
		_surface.mesh = null
		_update_collision(null)
		_geometry_sig = 0
		_prepare_build(world_pts, PackedFloat32Array())
		_after_mesh_built()
		return

	var segs := maxi(cross_segments, 1)
	var half_width := path_width * 0.5
	var river_mode := _is_river()
	var use_skirt := (not river_mode) and (skirt_depth > 0.001)
	var is_carved := live_terrain_preview or not _terrain_backup.is_empty()
	var hug_terrain := (not is_carved) and conform_mesh_to_terrain and is_instance_valid(terrain)

	var distances := PackedFloat32Array()
	var total_distance := 0.0
	for i in range(world_pts.size()):
		if i > 0:
			total_distance += world_pts[i - 1].distance_to(world_pts[i])
		distances.append(total_distance)

	_geometry_sig = hash([world_pts, path_width, surface_offset])
	_prepare_build(world_pts, distances)

	var rows: Array[PackedVector3Array] = []
	var row_uv_v := PackedFloat32Array()
	var row_alpha := PackedFloat32Array()

	for c in range(segs + 1):
		var t := float(c) / float(segs)
		row_uv_v.append(t)
		if river_mode:
			row_alpha.append(sin(t * PI))
		else:
			row_alpha.append(1.0)

	var left_y := PackedFloat32Array()
	var right_y := PackedFloat32Array()
	var dirs: Array[Vector3] = []

	var off_l := PackedFloat32Array()
	var off_r := PackedFloat32Array()

	for i in range(world_pts.size()):
		var fr := PathMath.row_frame(world_pts, i, half_width)
		var direction: Vector3 = fr[0]
		dirs.append(direction)
		off_l.append(float(fr[1]))
		off_r.append(float(fr[2]))

		var wc := world_pts[i]
		var side := Vector3(-direction.z, 0.0, direction.x)

		if river_mode:
			var wy := wc.y
			if hug_terrain:
				var ch := _get_surface_height(wc)
				if is_finite(ch):
					wy = ch
			wy += surface_offset
			left_y.append(wy)
			right_y.append(wy)
		else:
			if hug_terrain:
				var le := wc - side * half_width
				var re := wc + side * half_width
				var hc := _get_surface_height(wc)
				var hl := _get_surface_height(le)
				var hr := _get_surface_height(re)
				var yl := hl if is_finite(hl) else wc.y
				var yr := hr if is_finite(hr) else wc.y
				if is_finite(hc):
					yl = maxf(yl, hc - road_crown * 0.5)
					yr = maxf(yr, hc - road_crown * 0.5)
				left_y.append(yl + surface_offset)
				right_y.append(yr + surface_offset)
			else:
				left_y.append(wc.y + surface_offset)
				right_y.append(wc.y + surface_offset)

	if height_smoothing > 0 and world_pts.size() >= 3:
		for _pass in range(height_smoothing):
			var nl := left_y.duplicate()
			var nr := right_y.duplicate()
			for i in range(1, world_pts.size() - 1):
				nl[i] = 0.25 * left_y[i - 1] + 0.5 * left_y[i] + 0.25 * left_y[i + 1]
				nr[i] = 0.25 * right_y[i - 1] + 0.5 * right_y[i] + 0.25 * right_y[i + 1]
			left_y = nl
			right_y = nr

	_post_height_pass(world_pts, distances, left_y, right_y)

	if hug_terrain and not river_mode:
		for i in range(world_pts.size()):
			var wc := world_pts[i]
			var side := Vector3(-dirs[i].z, 0.0, dirs[i].x)
			var hl := _get_surface_height(wc - side * half_width)
			var hc := _get_surface_height(wc)
			var hr := _get_surface_height(wc + side * half_width)
			if is_finite(hl):
				left_y[i] = maxf(left_y[i], hl + surface_offset)
			if is_finite(hr):
				right_y[i] = maxf(right_y[i], hr + surface_offset)
			if is_finite(hc):
				var min_mid := hc + surface_offset
				left_y[i] = maxf(left_y[i], min_mid - road_crown * 0.5)
				right_y[i] = maxf(right_y[i], min_mid - road_crown * 0.5)

	for i in range(world_pts.size()):
		var wc := world_pts[i]
		var side := Vector3(-dirs[i].z, 0.0, dirs[i].x)
		var row_pts := PackedVector3Array()

		for c in range(segs + 1):
			var t := float(c) / float(segs)
			var offset_x := lerpf(-off_l[i], off_r[i], t)
			var wp := wc + side * offset_x
			if river_mode:
				wp.y = left_y[i]
			else:
				var crown := sin(t * PI) * road_crown
				var base_y := lerpf(left_y[i], right_y[i], t) + crown
				if hug_terrain:
					var h_here := _get_surface_height(wp)
					if is_finite(h_here):
						base_y = maxf(base_y, h_here + surface_offset)
				wp.y = base_y
			row_pts.append(to_local(wp))

		if i > 0:
			var prev_row := rows[i - 1]
			var seg_dir := to_local(world_pts[i]) - to_local(world_pts[i - 1])
			seg_dir.y = 0.0
			if seg_dir.length_squared() > 0.00001:
				seg_dir = seg_dir.normalized()
				for c in range(row_pts.size()):
					var d_xz := row_pts[c] - prev_row[c]
					d_xz.y = 0.0
					var proj := d_xz.dot(seg_dir)
					if proj < 0.01:
						row_pts[c] += seg_dir * (0.01 - proj)

		rows.append(row_pts)

	# Har bir chekka o'z yoy uzunligi bo'yicha UV oladi: burilishda tekstura cho'zilmaydi va ezilmaydi
	var ul := PackedFloat32Array()
	var ur := PackedFloat32Array()
	var acc_l := 0.0
	var acc_r := 0.0
	for i in range(rows.size()):
		if i > 0:
			acc_l += rows[i][0].distance_to(rows[i - 1][0])
			acc_r += rows[i][segs].distance_to(rows[i - 1][segs])
		ul.append(acc_l / maxf(path_width, 0.5))
		ur.append(acc_r / maxf(path_width, 0.5))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	st.set_smooth_group(0)
	for i in range(rows.size() - 1):
		if _is_segment_hidden(i):
			continue
		var r0 := rows[i]
		var r1 := rows[i + 1]

		for c in range(segs):
			var v00 := r0[c]
			var v10 := r1[c]
			var v01 := r0[c + 1]
			var v11 := r1[c + 1]

			var vv0 := row_uv_v[c]
			var vv1 := row_uv_v[c + 1]
			var a0 := row_alpha[c]
			var a1 := row_alpha[c + 1]
			var u00 := lerpf(ul[i], ur[i], vv0)
			var u10 := lerpf(ul[i + 1], ur[i + 1], vv0)
			var u01 := lerpf(ul[i], ur[i], vv1)
			var u11 := lerpf(ul[i + 1], ur[i + 1], vv1)

			st.set_color(Color(1.0, 1.0, 1.0, a0))
			st.set_uv(Vector2(u00, vv0))
			st.add_vertex(v00)

			st.set_color(Color(1.0, 1.0, 1.0, a0))
			st.set_uv(Vector2(u10, vv0))
			st.add_vertex(v10)

			st.set_color(Color(1.0, 1.0, 1.0, a1))
			st.set_uv(Vector2(u01, vv1))
			st.add_vertex(v01)

			st.set_color(Color(1.0, 1.0, 1.0, a1))
			st.set_uv(Vector2(u01, vv1))
			st.add_vertex(v01)

			st.set_color(Color(1.0, 1.0, 1.0, a0))
			st.set_uv(Vector2(u10, vv0))
			st.add_vertex(v10)

			st.set_color(Color(1.0, 1.0, 1.0, a1))
			st.set_uv(Vector2(u11, vv1))
			st.add_vertex(v11)

	if use_skirt:
		var left_skirt := PackedVector3Array()
		var right_skirt := PackedVector3Array()
		for i in range(rows.size()):
			var side := Vector3(-dirs[i].z, 0.0, dirs[i].x)
			var l_top := to_global(rows[i][0])
			var r_top := to_global(rows[i][segs])
			var ls := l_top - side * (skirt_depth * 0.4)
			ls.y -= skirt_depth
			var rs := r_top + side * (skirt_depth * 0.4)
			rs.y -= skirt_depth
			left_skirt.append(to_local(ls))
			right_skirt.append(to_local(rs))

		st.set_smooth_group(1)
		for i in range(rows.size() - 1):
			if _is_segment_hidden(i):
				continue
			_add_quad_with_alpha(st, left_skirt[i], left_skirt[i + 1], rows[i][0], rows[i + 1][0], ul[i], ul[i + 1], 0.0, 0.04, 0.0, 1.0)

		st.set_smooth_group(2)
		for i in range(rows.size() - 1):
			if _is_segment_hidden(i):
				continue
			_add_quad_with_alpha(st, rows[i][segs], rows[i + 1][segs], right_skirt[i], right_skirt[i + 1], ur[i], ur[i + 1], 0.96, 1.0, 1.0, 0.0)

	st.generate_normals()
	st.generate_tangents()

	var generated_mesh := st.commit()
	_surface.mesh = generated_mesh
	_update_collision(generated_mesh)
	_after_mesh_built()


func _add_quad_with_alpha(st: SurfaceTool, v00: Vector3, v10: Vector3, v01: Vector3, v11: Vector3, u0: float, u1: float, vv0: float, vv1: float, a0: float, a1: float) -> void:
	st.set_color(Color(1.0, 1.0, 1.0, a0))
	st.set_uv(Vector2(u0, vv0))
	st.add_vertex(v00)

	st.set_color(Color(1.0, 1.0, 1.0, a0))
	st.set_uv(Vector2(u1, vv0))
	st.add_vertex(v10)

	st.set_color(Color(1.0, 1.0, 1.0, a1))
	st.set_uv(Vector2(u0, vv1))
	st.add_vertex(v01)

	st.set_color(Color(1.0, 1.0, 1.0, a1))
	st.set_uv(Vector2(u0, vv1))
	st.add_vertex(v01)

	st.set_color(Color(1.0, 1.0, 1.0, a0))
	st.set_uv(Vector2(u1, vv0))
	st.add_vertex(v10)

	st.set_color(Color(1.0, 1.0, 1.0, a1))
	st.set_uv(Vector2(u1, vv1))
	st.add_vertex(v11)


func _update_collision(mesh_res: Mesh) -> void:
	if not generate_collision or mesh_res == null or _is_river():
		if is_instance_valid(_collision_body):
			_collision_body.queue_free()
			_collision_body = null
			_collision_shape = null
		return

	if not is_instance_valid(_collision_body):
		_collision_body = get_node_or_null("LiveCollision") as StaticBody3D
	if _collision_body == null:
		_collision_body = StaticBody3D.new()
		_collision_body.name = "LiveCollision"
		add_child(_collision_body)
		if Engine.is_editor_hint() and get_tree() != null:
			var root := get_tree().edited_scene_root
			if root != null:
				_collision_body.owner = root

	if not is_instance_valid(_collision_shape):
		_collision_shape = _collision_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		_collision_body.add_child(_collision_shape)
		if Engine.is_editor_hint() and get_tree() != null:
			var root := get_tree().edited_scene_root
			if root != null:
				_collision_shape.owner = root

	_collision_shape.shape = mesh_res.create_trimesh_shape()


func _rebuild() -> void:
	if _updating:
		return

	if not is_inside_tree():
		return

	_bump_epoch()
	_updating = true

	if _surface == null:
		_find_or_create_surface()

	if curve != null:
		curve.bake_interval = bake_interval
		_sync_points_with_terrain()
		_build_mesh()

	_updating = false
	_bump_epoch()

	if _geometry_sig != _emitted_sig:
		_emitted_sig = _geometry_sig
		geometry_changed.emit()
		if _is_river() and is_inside_tree():
			get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, &"live_road_path", &"on_river_changed")

	_on_rebuild_finished()

	if live_terrain_preview and Engine.is_editor_hint():
		_schedule_terrain_carve()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if terrain == null:
		warnings.append("Terrain3D node biriktirilmagan.")
	elif not terrain.is_class("Terrain3D"):
		warnings.append("Tanlangan node Terrain3D emas.")

	if curve == null or curve.get_point_count() < 2:
		warnings.append("Kamida ikkita Curve3D control point kerak.")

	return warnings