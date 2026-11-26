@tool
extends EditorPlugin

const RIVER := preload("res://addons/live_river_road/live_river_3d.gd")
const ROAD := preload("res://addons/live_river_road/live_road_3d.gd")
const LIVE_PATH := preload("res://addons/live_river_road/live_path_3d.gd")
const TexturePanel := preload("res://addons/live_river_road/texture_panel.gd")

const ICON_DIR := "res://addons/live_river_road/icons/"
const STYLE_ICONS := ["bridge_slab", "bridge_arch", "bridge_humpback", "bridge_wood", "bridge_truss", "bridge_suspension"]
const STYLE_NAMES := ["Plita (Beam)", "Tosh arka", "Bukri arka", "Yog'och", "Ferma (Truss)", "Osma ko'prik"]

var _current_path: Path3D = null
var _toolbar: HBoxContainer
var _add_mode_btn: Button
var _live_terrain_btn: Button
var _snap_btn: Button
var _downhill_btn: Button
var _carve_btn: Button
var _revert_btn: Button
var _bridge_sep: VSeparator
var _bridge_auto_btn: Button
var _bridge_style_opt: OptionButton
var _bridge_rebuild_btn: Button
var _junction_sep: VSeparator
var _junction_btn: Button
var _junction_mode_opt: OptionButton
var _lamp_btn: Button
var _last_camera: Camera3D = null
var _tex_sep: VSeparator
var _texture_btn: Button
var _panel: AcceptDialog


func _icon(name: String) -> Texture2D:
	return load(ICON_DIR + name + ".svg") as Texture2D


func _enter_tree() -> void:
	add_custom_type("LiveRiver3D", "Path3D", RIVER, _icon("river"))
	add_custom_type("LiveRoad3D", "Path3D", ROAD, _icon("road"))
	_panel = TexturePanel.new()
	_panel.undo = get_undo_redo()
	EditorInterface.get_base_control().add_child(_panel)
	_build_toolbar()
	print("Live River & Road Studio: Enabled")


func _exit_tree() -> void:
	_destroy_toolbar()
	if is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	remove_custom_type("LiveRiver3D")
	remove_custom_type("LiveRoad3D")


func _make_button(text: String, icon: String, tip: String, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = _icon(icon)
	b.tooltip_text = tip
	b.toggle_mode = toggle
	b.flat = false
	return b


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.visible = false

	_add_mode_btn = _make_button("Add Point", "add_point", "Yoqilganda (yoki Shift+Click) Terrain3D ustiga yangi nuqta qo'shadi.", true)
	_toolbar.add_child(_add_mode_btn)

	_live_terrain_btn = _make_button("Live Terrain", "live_terrain", "Nuqtalarni tepaga/pastga/yonga siljitganda terrain ham unga mos ko'tariladi va o'yiladi.", true)
	_live_terrain_btn.toggled.connect(_on_live_terrain_toggled)
	_toolbar.add_child(_live_terrain_btn)

	_snap_btn = _make_button("Snap", "snap", "Barcha nuqtalarni terrain yuzasiga yopishtiradi.")
	_snap_btn.pressed.connect(_on_snap_pressed)
	_toolbar.add_child(_snap_btn)

	_downhill_btn = _make_button("Downhill", "downhill", "Daryo doimo pastga oqishini ta'minlaydi (nuqtalar balandligini tuzatadi).")
	_downhill_btn.pressed.connect(_on_downhill_pressed)
	_toolbar.add_child(_downhill_btn)

	_carve_btn = _make_button("Carve", "carve", "Terrain'ni yo'l/daryo bo'ylab o'yib (yoki tekislab) chiqadi.")
	_carve_btn.pressed.connect(_on_carve_pressed)
	_toolbar.add_child(_carve_btn)

	_revert_btn = _make_button("Revert", "revert", "Terrain o'zgarishlarini asl holatiga qaytaradi.")
	_revert_btn.pressed.connect(_on_revert_pressed)
	_toolbar.add_child(_revert_btn)

	# --- Ko'prik boshqaruvi (faqat yo'l uchun) ---
	_bridge_sep = VSeparator.new()
	_toolbar.add_child(_bridge_sep)

	_bridge_auto_btn = _make_button("Ko'prik", "bridges_auto", "Daryo bilan kesishgan joyda avtomatik ko'prik qurish.", true)
	_bridge_auto_btn.toggled.connect(_on_bridge_auto_toggled)
	_toolbar.add_child(_bridge_auto_btn)

	_bridge_style_opt = OptionButton.new()
	_bridge_style_opt.tooltip_text = "Ko'prik shakli"
	for i in range(STYLE_NAMES.size()):
		_bridge_style_opt.add_icon_item(_icon(STYLE_ICONS[i]), STYLE_NAMES[i], i)
	_bridge_style_opt.item_selected.connect(_on_bridge_style_selected)
	_toolbar.add_child(_bridge_style_opt)

	_bridge_rebuild_btn = _make_button("", "bridges_rebuild", "Ko'priklarni qayta qurish.")
	_bridge_rebuild_btn.pressed.connect(_on_bridge_rebuild_pressed)
	_toolbar.add_child(_bridge_rebuild_btn)

	# --- Chorraha va aylana ---
	_junction_sep = VSeparator.new()
	_toolbar.add_child(_junction_sep)

	_junction_btn = _make_button("Chorraha", "junction", "Yo'llar kesishganda avtomatik chorraha, yo'nalishlar ko'p bo'lsa aylana (roundabout) qurish.", true)
	_junction_btn.toggled.connect(_on_junction_toggled)
	_toolbar.add_child(_junction_btn)

	_junction_mode_opt = OptionButton.new()
	_junction_mode_opt.tooltip_text = "Chorraha turi"
	var jicons := ["junction_auto", "junction_cross", "junction_ring", "junction_none"]
	var jnames := ["Avtomatik", "Chorraha", "Aylana", "Yo'q"]
	for i in range(jnames.size()):
		_junction_mode_opt.add_icon_item(_icon(jicons[i]), jnames[i], i)
	_junction_mode_opt.item_selected.connect(_on_junction_mode_selected)
	_toolbar.add_child(_junction_mode_opt)

	_lamp_btn = _make_button("Yoritgich", "lamp", "Yoqilganda: Shift+Click bilan Path3D nuqtalarini belgilang/belgisini oling. Belgilangan joylarga yoritgich (MultiMesh) qo'yiladi.", true)
	_lamp_btn.toggled.connect(_on_lamp_toggled)
	_toolbar.add_child(_lamp_btn)

	# --- Material va tekstura ---
	_tex_sep = VSeparator.new()
	_toolbar.add_child(_tex_sep)

	_texture_btn = _make_button("Tekstura", "texture", "Yo'l, suv va ko'prik uchun material, tekstura va sozlamalar paneli.")
	_texture_btn.pressed.connect(_on_texture_pressed)
	_toolbar.add_child(_texture_btn)

	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)


func _destroy_toolbar() -> void:
	if is_instance_valid(_toolbar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null


func _handles(p_object: Object) -> bool:
	return p_object != null and p_object is LIVE_PATH


func _edit(p_object: Object) -> void:
	if p_object is LIVE_PATH:
		_current_path = p_object
		_update_toolbar_state()
	else:
		_current_path = null


func _make_visible(p_visible: bool) -> void:
	if is_instance_valid(_toolbar):
		_toolbar.visible = p_visible and is_instance_valid(_current_path)
		if not p_visible and is_instance_valid(_add_mode_btn):
			_add_mode_btn.button_pressed = false


func _update_toolbar_state() -> void:
	if not is_instance_valid(_current_path):
		return
	var is_river := bool(_current_path.call("_is_river"))
	if is_instance_valid(_downhill_btn):
		_downhill_btn.visible = is_river
	for c in [_bridge_sep, _bridge_auto_btn, _bridge_style_opt, _bridge_rebuild_btn, _junction_sep, _junction_btn, _junction_mode_opt, _lamp_btn]:
		if is_instance_valid(c):
			c.visible = not is_river
	if is_instance_valid(_live_terrain_btn):
		_live_terrain_btn.set_pressed_no_signal(bool(_current_path.get("live_terrain_preview")))
	if not is_river:
		if is_instance_valid(_bridge_auto_btn):
			_bridge_auto_btn.set_pressed_no_signal(bool(_current_path.get("auto_bridges")))
		var st = _current_path.get("bridge_settings")
		if st != null and is_instance_valid(_bridge_style_opt):
			_bridge_style_opt.select(int(st.get("style")))
		if is_instance_valid(_junction_btn):
			_junction_btn.set_pressed_no_signal(bool(_current_path.get("auto_junctions")))
		var js = _current_path.get("junction_settings")
		if js != null and is_instance_valid(_junction_mode_opt):
			_junction_mode_opt.select(int(js.get("junction_mode")))


func _on_bridge_auto_toggled(pressed: bool) -> void:
	if not is_instance_valid(_current_path):
		return
	var undo := get_undo_redo()
	undo.create_action("Toggle Auto Bridges", UndoRedo.MERGE_DISABLE, _current_path)
	undo.add_do_method(_current_path, &"set_target_property", "node", "auto_bridges", pressed)
	undo.add_undo_method(_current_path, &"set_target_property", "node", "auto_bridges", not pressed)
	undo.commit_action()


func _on_bridge_style_selected(index: int) -> void:
	if not is_instance_valid(_current_path):
		return
	var st = _current_path.get("bridge_settings")
	if st == null:
		st = LiveBridgeSettings.new()
		_current_path.set("bridge_settings", st)
	var old_style: int = int(st.get("style"))
	var undo := get_undo_redo()
	undo.create_action("Change Bridge Style", UndoRedo.MERGE_DISABLE, _current_path)
	undo.add_do_method(_current_path, &"set_target_property", "settings", "style", index)
	undo.add_undo_method(_current_path, &"set_target_property", "settings", "style", old_style)
	undo.commit_action()
	st.call("apply_style_defaults")


func _on_junction_toggled(pressed: bool) -> void:
	if not is_instance_valid(_current_path):
		return
	var undo := get_undo_redo()
	undo.create_action("Toggle Auto Junctions", UndoRedo.MERGE_DISABLE, _current_path)
	undo.add_do_method(_current_path, &"set_target_property", "node", "auto_junctions", pressed)
	undo.add_undo_method(_current_path, &"set_target_property", "node", "auto_junctions", not pressed)
	undo.commit_action()


func _on_junction_mode_selected(index: int) -> void:
	if not is_instance_valid(_current_path):
		return
	var js = _current_path.get("junction_settings")
	if js == null:
		js = LiveJunctionSettings.new()
		_current_path.set("junction_settings", js)
	var old: int = int(js.get("junction_mode"))
	var undo := get_undo_redo()
	undo.create_action("Change Junction Mode", UndoRedo.MERGE_DISABLE, _current_path)
	undo.add_do_method(_current_path, &"set_target_property", "junction", "junction_mode", index)
	undo.add_undo_method(_current_path, &"set_target_property", "junction", "junction_mode", old)
	undo.commit_action()


func _on_lamp_toggled(_pressed: bool) -> void:
	update_overlays()


func _lamp_mode_active() -> bool:
	return is_instance_valid(_lamp_btn) and _lamp_btn.button_pressed and is_instance_valid(_current_path) and _current_path.has_method("toggle_lamp_mark")


func _shrink_of(camera: Camera3D) -> float:
	var vp := camera.get_parent()
	if vp is SubViewport and vp.get_parent() is SubViewportContainer:
		var container := vp.get_parent() as SubViewportContainer
		if container.stretch_shrink > 1:
			return float(container.stretch_shrink)
	return 1.0


## Shift+Click: sichqoncha yaqinidagi Path3D nuqtasini yoritgich uchun belgilaydi / belgisini oladi.
func _try_mark_lamp(camera: Camera3D, mouse_pos: Vector2) -> void:
	var curve: Curve3D = _current_path.curve
	if curve == null:
		return
	var shrink := _shrink_of(camera)
	var best := -1
	var best_d := 18.0
	for i in range(curve.get_point_count()):
		var wp: Vector3 = _current_path.to_global(curve.get_point_position(i))
		if camera.is_position_behind(wp):
			continue
		var sp := camera.unproject_position(wp) * shrink
		var d := sp.distance_to(mouse_pos)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	var was: bool = bool(_current_path.call("has_lamp_mark", best))
	var undo := get_undo_redo()
	undo.create_action("Toggle Lamp Mark", UndoRedo.MERGE_DISABLE, _current_path)
	undo.add_do_method(_current_path, &"set_lamp_mark", best, not was)
	undo.add_undo_method(_current_path, &"set_lamp_mark", best, was)
	undo.commit_action()
	update_overlays()


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if not is_instance_valid(_current_path) or not _current_path.has_method("get_lamp_mark_world_positions") or _last_camera == null or not is_instance_valid(_last_camera):
		return
	var marks: PackedVector3Array = _current_path.call("get_lamp_mark_world_positions")
	var shrink := _shrink_of(_last_camera)
	var icon := _icon("lamp")
	for wp in marks:
		if _last_camera.is_position_behind(wp):
			continue
		var sp := _last_camera.unproject_position(wp) * shrink
		overlay.draw_circle(sp, 11.0, Color(0.0, 0.0, 0.0, 0.55))
		overlay.draw_arc(sp, 11.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.3), 2.0)
		overlay.draw_texture(icon, sp - Vector2(8, 8))


func _on_bridge_rebuild_pressed() -> void:
	if is_instance_valid(_current_path) and _current_path.has_method("rebuild_bridges"):
		_current_path.call("rebuild_bridges")


func _on_texture_pressed() -> void:
	if is_instance_valid(_current_path) and is_instance_valid(_panel):
		_panel.call("open_for", _current_path)


func _on_live_terrain_toggled(pressed: bool) -> void:
	if is_instance_valid(_current_path):
		_current_path.set("live_terrain_preview", pressed)


func _forward_3d_gui_input(p_camera: Camera3D, p_event: InputEvent) -> int:
	if not is_instance_valid(_current_path):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	_last_camera = p_camera
	if p_event is InputEventMouseMotion and _current_path.has_method("get_lamp_mark_world_positions"):
		update_overlays()

	if _lamp_mode_active() and p_event is InputEventMouseButton:
		var lmb := p_event as InputEventMouseButton
		if lmb.button_index == MOUSE_BUTTON_LEFT and lmb.pressed and lmb.shift_pressed:
			_try_mark_lamp(p_camera, lmb.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var wants_add: bool = mb.shift_pressed or (is_instance_valid(_add_mode_btn) and _add_mode_btn.button_pressed)
			if not wants_add:
				return EditorPlugin.AFTER_GUI_INPUT_PASS

			var hit := _raycast_terrain_or_plane(p_camera, mb.position)
			if hit.is_finite():
				_add_point_with_undo(hit)
				return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _raycast_terrain_or_plane(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	var vp := camera.get_parent()
	var sample_pos := mouse_pos
	if vp is SubViewport and vp.get_parent() is SubViewportContainer:
		var container := vp.get_parent() as SubViewportContainer
		if container.stretch_shrink > 1:
			sample_pos = mouse_pos / float(container.stretch_shrink)

	var ray_origin := camera.project_ray_origin(sample_pos)
	var ray_dir := camera.project_ray_normal(sample_pos)

	var terrain: Node3D = _current_path.get("terrain")
	if is_instance_valid(terrain) and terrain.is_class("Terrain3D") and terrain.has_method("get_intersection"):
		if terrain.has_method("set_camera"):
			terrain.call("set_camera", camera)
		# CPU raymarch (gpuMode = false) Terrain3D tanlanmaganida ham aniq ishlaydi
		var hit: Vector3 = terrain.call("get_intersection", ray_origin, ray_dir, false)
		if hit.z >= 3.4e38 or not is_finite(hit.y):
			hit = terrain.call("get_intersection", ray_origin, ray_dir, true)
		if hit.z < 3.4e38 and is_finite(hit.y):
			var exact_y: float = _current_path.call("_get_uncarved_height", hit)
			if is_finite(exact_y):
				hit.y = exact_y
			return hit

	var plane := Plane(Vector3.UP, _current_path.global_position.y)
	var plane_hit = plane.intersects_ray(ray_origin, ray_dir)
	if plane_hit != null:
		var fallback: Vector3 = plane_hit as Vector3
		var exact_y2: float = _current_path.call("_get_uncarved_height", fallback)
		if is_finite(exact_y2):
			fallback.y = exact_y2
		return fallback
	return Vector3(INF, INF, INF)


func _add_point_with_undo(world_hit: Vector3) -> void:
	var curve := _current_path.curve
	if curve == null:
		curve = Curve3D.new()
		_current_path.curve = curve

	var local_pos := _current_path.to_local(world_hit)
	var idx := curve.get_point_count()

	var undo := get_undo_redo()
	undo.create_action("Add Live Path Point")
	undo.add_do_method(curve, &"add_point", local_pos)
	undo.add_undo_method(curve, &"remove_point", idx)
	undo.commit_action()


func _on_snap_pressed() -> void:
	if not is_instance_valid(_current_path) or _current_path.curve == null:
		return
	var curve := _current_path.curve
	var old_positions: Array[Vector3] = []
	for i in range(curve.get_point_count()):
		old_positions.append(curve.get_point_position(i))

	_current_path.call("snap_points_now")

	var new_positions: Array[Vector3] = []
	for i in range(curve.get_point_count()):
		new_positions.append(curve.get_point_position(i))

	var undo := get_undo_redo()
	undo.create_action("Snap Path Points to Terrain")
	for i in range(curve.get_point_count()):
		undo.add_do_method(curve, &"set_point_position", i, new_positions[i])
		undo.add_undo_method(curve, &"set_point_position", i, old_positions[i])
	undo.commit_action(false)


func _on_downhill_pressed() -> void:
	if not is_instance_valid(_current_path) or _current_path.curve == null:
		return
	var curve := _current_path.curve
	var old_positions: Array[Vector3] = []
	for i in range(curve.get_point_count()):
		old_positions.append(curve.get_point_position(i))

	_current_path.call("enforce_downhill")

	var new_positions: Array[Vector3] = []
	for i in range(curve.get_point_count()):
		new_positions.append(curve.get_point_position(i))

	var undo := get_undo_redo()
	undo.create_action("Enforce River Downhill")
	for i in range(curve.get_point_count()):
		undo.add_do_method(curve, &"set_point_position", i, new_positions[i])
		undo.add_undo_method(curve, &"set_point_position", i, old_positions[i])
	undo.commit_action(false)


func _on_carve_pressed() -> void:
	if not is_instance_valid(_current_path):
		return
	var before: Dictionary = _current_path.call("get_backup_copy")
	var after: Dictionary = _current_path.call("apply_terrain_carving")
	if after.is_empty():
		return

	var undo := get_undo_redo()
	undo.create_action("Carve Terrain along Path")
	undo.add_do_method(_current_path, &"restore_snapshot", after)
	if before.is_empty():
		undo.add_undo_method(_current_path, &"revert_terrain_carving")
	else:
		undo.add_undo_method(_current_path, &"restore_snapshot", before)
	undo.commit_action(false)


func _on_revert_pressed() -> void:
	if not is_instance_valid(_current_path):
		return
	var before: Dictionary = _current_path.call("get_backup_copy")
	if before.is_empty():
		return

	var undo := get_undo_redo()
	undo.create_action("Revert Terrain Carving")
	undo.add_do_method(_current_path, &"revert_terrain_carving")
	undo.add_undo_method(_current_path, &"restore_snapshot", before)
	undo.commit_action()