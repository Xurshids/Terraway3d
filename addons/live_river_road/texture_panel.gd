@tool
extends AcceptDialog
## Tekstura va Material boshqaruvi paneli.
## Yo'l, suv va ko'prik uchun material, tekstura va barcha sozlamalarni bitta joyda o'zgartiradi.
## Barcha o'zgarishlar Undo/Redo bilan ishlaydi.

const ICON_DIR := "res://addons/live_river_road/icons/"

var undo: EditorUndoRedoManager
var node: Node = null

var _tabs: TabContainer
var _defaults_ts: LiveTextureSet
var _defaults_bs: LiveBridgeSettings

const WATER_PRESETS := {
	"Toza daryo": {"shallow_color": Color(0.08, 0.36, 0.35), "deep_color": Color(0.02, 0.11, 0.17), "water_clarity": 1.75, "min_opacity": 0.62},
	"Feruza": {"shallow_color": Color(0.1, 0.6, 0.62), "deep_color": Color(0.02, 0.25, 0.35), "water_clarity": 2.6, "min_opacity": 0.55},
	"Botqoq": {"shallow_color": Color(0.22, 0.3, 0.12), "deep_color": Color(0.08, 0.12, 0.06), "water_clarity": 0.5, "min_opacity": 0.85},
	"Loyqa suv": {"shallow_color": Color(0.45, 0.34, 0.2), "deep_color": Color(0.25, 0.18, 0.1), "water_clarity": 0.35, "min_opacity": 0.92},
	"Chuqur ko'l": {"shallow_color": Color(0.03, 0.2, 0.3), "deep_color": Color(0.0, 0.04, 0.1), "water_clarity": 1.0, "min_opacity": 0.8},
}

const ROAD_PRESETS := {
	"Asfalt": {"road_color": Color(0.16, 0.16, 0.17), "wear_color": Color(0.22, 0.22, 0.23), "shoulder_color": Color(0.26, 0.23, 0.19), "road_roughness": 0.88, "grain_scale": 12.0, "bump_strength": 0.18, "show_center_line": true},
	"Tuproq yo'l": {"road_color": Color(0.36, 0.26, 0.16), "wear_color": Color(0.3, 0.21, 0.13), "shoulder_color": Color(0.28, 0.3, 0.15), "road_roughness": 1.0, "grain_scale": 6.0, "bump_strength": 0.5, "show_center_line": false, "show_edge_lines": false},
	"Shag'al": {"road_color": Color(0.5, 0.47, 0.42), "wear_color": Color(0.42, 0.4, 0.36), "shoulder_color": Color(0.38, 0.36, 0.3), "road_roughness": 0.95, "grain_scale": 22.0, "bump_strength": 0.7, "show_center_line": false, "show_edge_lines": false},
	"Qum": {"road_color": Color(0.76, 0.66, 0.45), "wear_color": Color(0.68, 0.58, 0.4), "shoulder_color": Color(0.6, 0.52, 0.35), "road_roughness": 1.0, "grain_scale": 18.0, "bump_strength": 0.25, "show_center_line": false, "show_edge_lines": false},
	"Bruschatka": {"road_color": Color(0.4, 0.38, 0.36), "wear_color": Color(0.34, 0.32, 0.3), "shoulder_color": Color(0.3, 0.28, 0.25), "road_roughness": 0.85, "grain_scale": 4.0, "bump_strength": 0.8, "show_center_line": false, "show_edge_lines": false},
}

const ENUM_ITEMS := {
	"style": ["Plita (Beam)", "Tosh arka", "Bukri arka", "Yog'och", "Ferma (Truss)", "Osma ko'prik"],
	"deck_surface": ["Yo'l materiali davom etadi", "Yog'och taxtalar"],
	"pier_shape": ["Devor", "Yumaloq devor", "Dumaloq ustunlar", "Kvadrat ustunlar"],
	"railing_style": ["Yo'q", "Ustun va to'sin", "Tosh devor (parapet)", "Yog'och to'siq", "Arqonli"],
	"custom_fit": ["Uzunlikka cho'zish", "Butunlay cho'zish", "Takrorlash (tile)", "Asl o'lcham"],
}

const STYLE_ICONS := ["bridge_slab", "bridge_arch", "bridge_humpback", "bridge_wood", "bridge_truss", "bridge_suspension"]


func _init() -> void:
	title = "Tekstura va Material"
	ok_button_text = "Yopish"
	min_size = Vector2i(600, 720)
	exclusive = false
	transient = false
	_defaults_ts = LiveTextureSet.new()
	_defaults_bs = LiveBridgeSettings.new()
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(580, 640)
	add_child(_tabs)


func open_for(p_node: Node) -> void:
	node = p_node
	_rebuild()
	popup_centered(Vector2i(640, 760))


func _is_river() -> bool:
	return is_instance_valid(node) and bool(node.call("_is_river"))


# ---------------------------------------------------------------------------
#  Qator tavsiflari
# ---------------------------------------------------------------------------
static func R(target: String, prop: String, label: String, kind: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"target": target, "prop": prop, "label": label, "kind": kind}
	d.merge(extra)
	return d


static func H(text: String) -> Dictionary:
	return {"kind": "header", "text": text}


func _rows_river() -> Array:
	return [
		{"kind": "preset", "label": "Tayyor suv turi", "items": WATER_PRESETS, "target": "node"},
		R("node", "custom_material", "Tayyor material", "res", {"base": "Material"}),
		H("Rang va shaffoflik"),
		R("node", "shallow_color", "Sayoz suv rangi", "color"),
		R("node", "deep_color", "Chuqur suv rangi", "color"),
		R("node", "sky_tint", "Osmon aksi", "color"),
		R("node", "water_clarity", "Tiniqlik", "float", {"min": 0.1, "max": 8.0, "step": 0.05}),
		R("node", "min_opacity", "Minimal shaffoflik", "float", {"min": 0.1, "max": 1.0, "step": 0.02}),
		R("node", "edge_fade_depth", "Chekka xiralashuvi", "float", {"min": 0.01, "max": 0.6, "step": 0.01}),
		H("Harakat va to'lqin"),
		R("node", "flow_speed", "Oqim tezligi", "float", {"min": 0.0, "max": 4.0, "step": 0.02}),
		R("node", "ripple_scale", "To'lqin masshtabi", "float", {"min": 0.2, "max": 8.0, "step": 0.05}),
		R("node", "ripple_strength", "To'lqin kuchi", "float", {"min": 0.0, "max": 1.5, "step": 0.02}),
		R("node", "refraction_strength", "Sinish (refraction)", "float", {"min": 0.0, "max": 0.08, "step": 0.002}),
		H("Yorug'lik"),
		R("node", "fresnel_power", "Fresnel", "float", {"min": 1.0, "max": 8.0, "step": 0.1}),
		R("node", "water_roughness", "G'adir-budurlik", "float", {"min": 0.01, "max": 0.35, "step": 0.005}),
		R("node", "water_specular", "Yaltirash", "float", {"min": 0.0, "max": 1.0, "step": 0.05}),
		R("node", "caustics_strength", "Kaustika", "float", {"min": 0.0, "max": 1.0, "step": 0.02}),
		H("Qirg'oq ko'pigi"),
		R("node", "foam_intensity", "Ko'pik kuchi", "float", {"min": 0.0, "max": 1.0, "step": 0.02}),
		R("node", "foam_color", "Ko'pik rangi", "color"),
		R("node", "foam_depth", "Ko'pik chuqurligi", "float", {"min": 0.0, "max": 0.5, "step": 0.01}),
	]


func _rows_water_tex() -> Array:
	return [
		H("Suv normal map teksturalari"),
		R("node", "water_normal_a", "Normal map A", "res", {"base": "Texture2D"}),
		R("node", "water_normal_b", "Normal map B", "res", {"base": "Texture2D"}),
		R("node", "water_normal_tiling", "Takrorlanish (tiling)", "vec2", {"min": 0.01, "max": 50.0, "step": 0.01}),
		R("node", "water_normal_strength", "Normal kuchi", "float", {"min": 0.0, "max": 2.0, "step": 0.01}),
		H("Ko'pik teksturasi"),
		R("node", "foam_texture", "Ko'pik teksturasi", "res", {"base": "Texture2D"}),
		R("node", "foam_texture_scale", "Ko'pik masshtabi", "float", {"min": 0.1, "max": 10.0, "step": 0.1}),
	]


func _rows_road() -> Array:
	return [
		{"kind": "preset", "label": "Tayyor yo'l turi", "items": ROAD_PRESETS, "target": "node"},
		R("node", "custom_material", "Tayyor material", "res", {"base": "Material"}),
		H("Rang"),
		R("node", "road_color", "Asosiy rang", "color"),
		R("node", "wear_color", "G'ildirak izi rangi", "color"),
		R("node", "shoulder_color", "Yo'l chetlari rangi", "color"),
		H("Sirt"),
		R("node", "road_roughness", "G'adir-budurlik", "float", {"min": 0.2, "max": 1.0, "step": 0.02}),
		R("node", "grain_scale", "Don o'lchami", "float", {"min": 1.0, "max": 30.0, "step": 0.5}),
		R("node", "bump_strength", "Notekislik", "float", {"min": 0.0, "max": 1.0, "step": 0.02}),
		R("node", "tire_wear_strength", "G'ildirak izi kuchi", "float", {"min": 0.0, "max": 1.0, "step": 0.01}),
		R("node", "shoulder_amount", "Chet aralashuvi", "float", {"min": 0.0, "max": 1.0, "step": 0.01}),
		R("node", "edge_blend", "Chekka xiralashuvi", "float", {"min": 0.0, "max": 0.25, "step": 0.01}),
	]


func _rows_road_lines() -> Array:
	return [
		H("O'rta chiziq"),
		R("node", "show_center_line", "Ko'rsatish", "bool"),
		R("node", "line_color", "Rangi", "color"),
		R("node", "solid_center_line", "Uzluksiz chiziq", "bool"),
		R("node", "dash_period", "Shtrix davri", "float", {"min": 0.5, "max": 10.0, "step": 0.1}),
		R("node", "dash_fill", "Shtrix to'liqligi", "float", {"min": 0.1, "max": 0.95, "step": 0.01}),
		R("node", "line_width", "Chiziq qalinligi", "float", {"min": 0.004, "max": 0.1, "step": 0.001}),
		H("Chekka chiziqlar"),
		R("node", "show_edge_lines", "Ko'rsatish", "bool"),
		R("node", "edge_line_color", "Rangi", "color"),
		R("node", "edge_line_inset", "Chetdan masofa", "float", {"min": 0.02, "max": 0.25, "step": 0.005}),
	]


func _ts_rows(target: String, with_set_picker: bool) -> Array:
	var rows: Array = []
	if with_set_picker:
		rows.append(R("node", "road_texture_set", "Tekstura to'plami (.tres)", "res", {"base": "LiveTextureSet"}))
	rows.append_array([
		H("Teksturalar"),
		R(target, "albedo_texture", "Albedo (rang)", "res", {"base": "Texture2D"}),
		R(target, "normal_texture", "Normal map", "res", {"base": "Texture2D"}),
		R(target, "roughness_texture", "Roughness", "res", {"base": "Texture2D"}),
		R(target, "ao_texture", "Ambient Occlusion", "res", {"base": "Texture2D"}),
		H("Parametrlar"),
		R(target, "tint", "Rang tusi (tint)", "color"),
		R(target, "uv_tiling", "Takrorlanish (tiling)", "vec2", {"min": 0.01, "max": 100.0, "step": 0.01}),
		R(target, "uv_offset", "Siljish (offset)", "vec2", {"min": -10.0, "max": 10.0, "step": 0.01}),
		R(target, "normal_strength", "Normal kuchi", "float", {"min": 0.0, "max": 4.0, "step": 0.05}),
		R(target, "roughness", "G'adir-budurlik", "float", {"min": 0.0, "max": 1.0, "step": 0.01}),
		R(target, "metallic", "Metallik", "float", {"min": 0.0, "max": 1.0, "step": 0.01}),
		R(target, "triplanar", "Triplanar (dunyo koordinatasi)", "bool"),
	])
	return rows


func _rows_bridge() -> Array:
	return [
		R("node", "auto_bridges", "Avtomatik ko'prik", "bool"),
		R("settings", "style", "Ko'prik shakli", "enum", {"preset_on_change": true}),
		{"kind": "button", "text": "Shakl namunasini qayta qo'llash", "action": "apply_preset", "icon": "bridges_rebuild"},
		H("O'lcham"),
		R("settings", "width_extra", "Yon kenglik", "float", {"min": 0.0, "max": 6.0, "step": 0.05}),
		R("settings", "deck_thickness", "Plita qalinligi", "float", {"min": 0.05, "max": 4.0, "step": 0.05}),
		R("settings", "deck_camber", "O'rtada ko'tarilish", "float", {"min": 0.0, "max": 8.0, "step": 0.05}),
		R("settings", "min_clearance", "Suvdan balandlik", "float", {"min": 0.0, "max": 12.0, "step": 0.1}),
		R("settings", "bank_margin", "Qirg'oqqa cho'zilish", "float", {"min": 0.0, "max": 20.0, "step": 0.1}),
		R("settings", "ramp_length", "Yo'l ko'tarilish masofasi", "float", {"min": 0.0, "max": 80.0, "step": 0.5}),
		R("settings", "merge_gap", "Birlashtirish masofasi", "float", {"min": 0.0, "max": 60.0, "step": 0.5}),
		R("settings", "deck_surface", "Ko'prik usti", "enum"),
		H("Tayanchlar"),
		R("settings", "pier_count", "Tayanchlar soni (-1 = auto)", "int", {"min": -1, "max": 40, "step": 1}),
		R("settings", "pier_shape", "Tayanch shakli", "enum"),
		R("settings", "pier_width", "Tayanch qalinligi", "float", {"min": 0.1, "max": 8.0, "step": 0.05}),
		R("settings", "max_unsupported", "Tayanchlar oralig'i", "float", {"min": 2.0, "max": 200.0, "step": 0.5}),
		R("settings", "abutment_enabled", "Chekka tayanchlar", "bool"),
		H("Arka"),
		R("settings", "arch_count", "Arkalar soni (0 = auto)", "int", {"min": 0, "max": 24, "step": 1}),
		R("settings", "arch_rise_ratio", "Arka balandligi", "float", {"min": 0.1, "max": 0.5, "step": 0.01}),
		R("settings", "arch_thickness", "Arka qalinligi", "float", {"min": 0.1, "max": 3.0, "step": 0.05}),
		H("Panjara"),
		R("settings", "railing_style", "Panjara turi", "enum"),
		R("settings", "railing_height", "Balandligi", "float", {"min": 0.2, "max": 3.0, "step": 0.05}),
		R("settings", "post_spacing", "Ustunlar oralig'i", "float", {"min": 0.3, "max": 10.0, "step": 0.1}),
		R("settings", "rail_count", "To'sinlar soni", "int", {"min": 1, "max": 6, "step": 1}),
		H("Ferma va osma ko'prik"),
		R("settings", "truss_height", "Ferma balandligi", "float", {"min": 1.0, "max": 15.0, "step": 0.1}),
		R("settings", "tower_height", "Minora balandligi", "float", {"min": 2.0, "max": 60.0, "step": 0.5}),
		R("settings", "cable_sag", "Arqon cho'kishi", "float", {"min": 0.2, "max": 30.0, "step": 0.1}),
		{"kind": "button", "text": "Barcha sozlamalarni inspektorda ochish", "action": "inspect_settings", "icon": "settings"},
	]


func _rows_bridge_material() -> Array:
	var rows: Array = [
		H("Tayyor materiallar (bo'lsa, tekstura e'tiborsiz qoladi)"),
		R("settings", "structure_material", "Konstruksiya materiali", "res", {"base": "Material"}),
		R("settings", "railing_material", "Panjara/metall materiali", "res", {"base": "Material"}),
		R("settings", "deck_material", "Ko'prik usti materiali", "res", {"base": "Material"}),
		H("Rang"),
		R("settings", "use_style_colors", "Shaklga mos standart rang", "bool"),
		R("settings", "structure_tint", "Konstruksiya rangi", "color"),
		R("settings", "railing_tint", "Panjara rangi", "color"),
		H("Konstruksiya teksturalari"),
		R("settings", "structure_texture_set", "Tekstura to'plami (.tres)", "res", {"base": "LiveTextureSet"}),
	]
	rows.append_array(_ts_rows("struct_ts", false).slice(0))
	rows.append(H("Panjara teksturalari"))
	rows.append(R("settings", "railing_texture_set", "Tekstura to'plami (.tres)", "res", {"base": "LiveTextureSet"}))
	rows.append_array(_ts_rows("rail_ts", false).slice(0))
	return rows


func _rows_custom_mesh() -> Array:
	return [
		H("O'zingizning ko'prik modelingiz"),
		R("settings", "custom_mesh", "Mesh", "res", {"base": "Mesh"}),
		R("settings", "custom_scene", "Sahna (PackedScene)", "res", {"base": "PackedScene"}),
		R("settings", "custom_material", "Material (ixtiyoriy)", "res", {"base": "Material"}),
		H("Joylashuv"),
		R("settings", "custom_fit", "Moslashish usuli", "enum"),
		R("settings", "custom_mesh_length", "Asl uzunlik (0 = auto)", "float", {"min": 0.0, "max": 200.0, "step": 0.1}),
		R("settings", "custom_offset", "Siljish", "vec3", {"min": -100.0, "max": 100.0, "step": 0.05}),
		R("settings", "custom_rotation_y", "Burish (Y, gradus)", "float", {"min": -180.0, "max": 180.0, "step": 1.0}),
		R("settings", "custom_scale", "Masshtab", "vec3", {"min": 0.01, "max": 50.0, "step": 0.01}),
		R("settings", "custom_keep_road_surface", "Yo'l usti yuzasi saqlansin", "bool"),
		R("settings", "generate_collision", "To'qnashuv (collision)", "bool"),
		{"kind": "button", "text": "O'z modelini olib tashlash", "action": "clear_custom", "icon": "revert"},
		{"kind": "note", "text": "Mesh uzunligi Z o'qi bo'ylab, ko'prik usti Y=0 da bo'lsin. Markaz avtomatik moslanadi."},
	]


# ---------------------------------------------------------------------------
#  Interfeysni qurish
# ---------------------------------------------------------------------------
func _rebuild() -> void:
	var keep := _tabs.current_tab
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	if not is_instance_valid(node):
		return
	if _is_river():
		title = "Suv: material va teksturalar"
		_add_tab("Suv", "river", _rows_river())
		_add_tab("Tekstura", "texture", _rows_water_tex())
	else:
		title = "Yo'l va ko'prik: material va teksturalar"
		_add_tab("Yo'l", "road", _rows_road())
		_add_tab("Chiziqlar", "settings", _rows_road_lines())
		_add_tab("Tekstura", "texture", _ts_rows("road_ts", true))
		_add_tab("Ko'prik", "bridge", _rows_bridge())
		_add_tab("Ko'prik materiali", "material", _rows_bridge_material())
		_add_tab("O'z mesh", "bridge_custom", _rows_custom_mesh())
	if keep >= 0 and keep < _tabs.get_tab_count():
		_tabs.current_tab = keep


func _add_tab(tab_title: String, icon: String, rows: Array) -> void:
	var sc := ScrollContainer.new()
	sc.name = tab_title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	var grid: GridContainer = null
	for spec in rows:
		var kind: String = spec["kind"]
		if kind == "header":
			var l := Label.new()
			l.text = spec["text"]
			l.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
			vb.add_child(HSeparator.new())
			vb.add_child(l)
			grid = null
			continue
		if kind == "note":
			var n := Label.new()
			n.text = spec["text"]
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.modulate = Color(1, 1, 1, 0.65)
			vb.add_child(n)
			grid = null
			continue
		if kind == "button":
			var b := Button.new()
			b.text = spec["text"]
			if spec.has("icon"):
				b.icon = load(ICON_DIR + spec["icon"] + ".svg")
			b.pressed.connect(_on_action.bind(spec["action"]))
			vb.add_child(b)
			grid = null
			continue
		if grid == null:
			grid = GridContainer.new()
			grid.columns = 2
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 4)
			vb.add_child(grid)
		var lab := Label.new()
		lab.text = spec.get("label", spec.get("prop", ""))
		lab.custom_minimum_size.x = 190
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(lab)
		var ctl := _make_control(spec)
		ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(ctl)
	_tabs.add_child(sc)
	var idx := _tabs.get_tab_count() - 1
	_tabs.set_tab_title(idx, tab_title)
	_tabs.set_tab_icon(idx, load(ICON_DIR + icon + ".svg"))


# ---------------------------------------------------------------------------
#  Obyektlarni topish
# ---------------------------------------------------------------------------
func _get_obj(key: String, create: bool) -> Object:
	if not is_instance_valid(node):
		return null
	return node.call("get_panel_target", key, create)


func _read(spec: Dictionary) -> Variant:
	var obj := _get_obj(spec["target"], false)
	var prop: String = spec["prop"]
	if obj != null:
		return obj.get(prop)
	match spec["target"]:
		"settings":
			return _defaults_bs.get(prop)
		"road_ts", "struct_ts", "rail_ts":
			return _defaults_ts.get(prop)
	return null


## Qiymatni Undo/Redo bilan qo'llaydi. Kerak bo'lsa tekstura to'plamini avtomatik yaratadi.
## Barcha o'zgarishlar node metodlari orqali o'tadi (bitta undo tarixi uchun).
func _write(spec: Dictionary, value: Variant) -> void:
	if not is_instance_valid(node):
		return
	var target: String = spec["target"]
	var prop: String = spec["prop"]
	var old: Variant = _read(spec)
	if typeof(old) == typeof(value) and typeof(value) != TYPE_OBJECT and old == value:
		return
	undo.create_action("Live Path: " + prop, UndoRedo.MERGE_ENDS, node)
	undo.add_do_method(node, &"set_target_property", target, prop, value)
	undo.add_undo_method(node, &"set_target_property", target, prop, old)
	undo.commit_action()


# ---------------------------------------------------------------------------
#  Boshqaruv elementlari
# ---------------------------------------------------------------------------
func _make_control(spec: Dictionary) -> Control:
	var kind: String = spec["kind"]
	match kind:
		"preset":
			return _make_preset(spec)
		"res":
			var rp := EditorResourcePicker.new()
			rp.base_type = spec["base"]
			rp.editable = true
			rp.toggle_mode = false
			rp.edited_resource = _read(spec)
			rp.resource_changed.connect(func(res: Resource):
				_write(spec, res)
				if spec["prop"] in ["road_texture_set", "structure_texture_set", "railing_texture_set", "custom_mesh", "custom_scene"]:
					_rebuild.call_deferred())
			return rp
		"color":
			var cp := ColorPickerButton.new()
			cp.custom_minimum_size = Vector2(80, 28)
			cp.edit_alpha = false
			cp.color = _read(spec)
			cp.color_changed.connect(func(c: Color): _write(spec, c))
			return cp
		"bool":
			var cb := CheckButton.new()
			cb.button_pressed = bool(_read(spec))
			cb.toggled.connect(func(p: bool): _write(spec, p))
			return cb
		"enum":
			var ob := OptionButton.new()
			var items: Array = ENUM_ITEMS[spec["prop"]]
			for i in range(items.size()):
				if spec["prop"] == "style":
					ob.add_icon_item(load(ICON_DIR + STYLE_ICONS[i] + ".svg"), items[i], i)
				else:
					ob.add_item(items[i], i)
			ob.selected = int(_read(spec))
			ob.item_selected.connect(func(i: int):
				_write(spec, i)
				if spec.get("preset_on_change", false):
					var s := _get_obj("settings", true)
					if s != null:
						s.call("apply_style_defaults")
					_rebuild.call_deferred())
			return ob
		"float", "int":
			return _make_spin(spec, kind == "int")
		"vec2", "vec3":
			return _make_vec(spec, kind == "vec3")
	return Label.new()


func _make_spin(spec: Dictionary, is_int: bool) -> Control:
	var sp := EditorSpinSlider.new()
	sp.min_value = spec.get("min", 0.0)
	sp.max_value = spec.get("max", 1.0)
	sp.step = spec.get("step", 0.01)
	sp.allow_greater = true
	sp.value = float(_read(spec))
	sp.custom_minimum_size = Vector2(150, 0)
	sp.value_changed.connect(func(v: float): _write(spec, int(v) if is_int else v))
	return sp


func _make_vec(spec: Dictionary, is_v3: bool) -> Control:
	var hb := HBoxContainer.new()
	var cur: Variant = _read(spec)
	var n := 3 if is_v3 else 2
	var sliders: Array = []
	for i in range(n):
		var sp := EditorSpinSlider.new()
		sp.min_value = spec.get("min", -100.0)
		sp.max_value = spec.get("max", 100.0)
		sp.step = spec.get("step", 0.01)
		sp.allow_greater = true
		sp.allow_lesser = true
		sp.value = cur[i]
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.custom_minimum_size = Vector2(60, 0)
		hb.add_child(sp)
		sliders.append(sp)
	for sp in sliders:
		sp.value_changed.connect(func(_v: float):
			if is_v3:
				_write(spec, Vector3(sliders[0].value, sliders[1].value, sliders[2].value))
			else:
				_write(spec, Vector2(sliders[0].value, sliders[1].value)))
	return hb


func _make_preset(spec: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var names: Array = (spec["items"] as Dictionary).keys()
	ob.add_item("— tanlang —", 0)
	for i in range(names.size()):
		ob.add_item(names[i], i + 1)
	ob.item_selected.connect(func(i: int):
		if i == 0:
			return
		_apply_preset(spec["items"][names[i - 1]])
		_rebuild.call_deferred())
	hb.add_child(ob)
	return hb


func _apply_preset(values: Dictionary) -> void:
	if not is_instance_valid(node):
		return
	undo.create_action("Live Path: preset", UndoRedo.MERGE_DISABLE, node)
	for prop in values:
		undo.add_do_method(node, &"set_target_property", "node", prop, values[prop])
		undo.add_undo_method(node, &"set_target_property", "node", prop, node.get(prop))
	undo.commit_action()


func _on_action(action: String) -> void:
	match action:
		"apply_preset":
			var s := _get_obj("settings", true)
			if s != null:
				s.call("apply_style_defaults")
				_rebuild.call_deferred()
		"inspect_settings":
			var s2 := _get_obj("settings", true)
			if s2 != null:
				EditorInterface.inspect_object(s2)
		"clear_custom":
			var s3 := _get_obj("settings", true)
			if s3 != null:
				undo.create_action("Live Bridge: clear custom mesh", UndoRedo.MERGE_DISABLE, node)
				for p in ["custom_mesh", "custom_scene", "custom_material"]:
					undo.add_do_method(node, &"set_target_property", "settings", p, null)
					undo.add_undo_method(node, &"set_target_property", "settings", p, s3.get(p))
				undo.commit_action()
				_rebuild.call_deferred()
