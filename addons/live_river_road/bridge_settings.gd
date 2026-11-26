@tool
@icon("res://addons/live_river_road/icons/bridge_settings.svg")
class_name LiveBridgeSettings
extends Resource
## Ko'prik generatsiyasi sozlamalari. LiveRoad3D.bridge_settings ga biriktiriladi.
## .tres sifatida saqlab, bir nechta yo'lda qayta ishlatish mumkin.

enum Style { SLAB, STONE_ARCH, HUMPBACK, WOODEN, TRUSS, SUSPENSION }
enum PierShape { WALL, WALL_ROUNDED, COLUMNS_ROUND, COLUMNS_SQUARE }
enum RailingStyle { NONE, POSTS_AND_RAILS, SOLID_PARAPET, WOODEN_FENCE, CABLE_RAILS }
enum DeckSurface { ROAD, PLANKS }
enum CustomFit { STRETCH_LENGTH, STRETCH_ALL, TILE_ALONG, KEEP_SCALE }

var _mute := false

@export_group("Umumiy")
## Ko'prik shakli. Tayyor sozlamalar uchun 'Uslub namunasini qo'llash' tugmasini bosing.
@export var style: Style = Style.SLAB:
	set(v):
		style = v
		_emit()
## Yo'l kengligidan har ikki tomonga qo'shimcha kenglik (m).
@export_range(0.0, 6.0, 0.05, "or_greater") var width_extra: float = 0.6:
	set(v):
		width_extra = v
		_emit()
## Ko'prik poli (plita) qalinligi.
@export_range(0.05, 4.0, 0.05, "or_greater") var deck_thickness: float = 0.5:
	set(v):
		deck_thickness = v
		_emit()
## O'rtada ko'tarilish balandligi (m). 0 = tekis.
@export_range(0.0, 8.0, 0.05, "or_greater") var deck_camber: float = 0.0:
	set(v):
		deck_camber = v
		_emit()
## Suv sathi bilan ko'prik osti orasidagi minimal masofa (m).
@export_range(0.0, 12.0, 0.1, "or_greater") var min_clearance: float = 1.2:
	set(v):
		min_clearance = v
		_emit()
## Ko'prik suv chetidan qancha uzoqroqqa cho'ziladi (m).
@export_range(0.0, 20.0, 0.1, "or_greater") var bank_margin: float = 2.0:
	set(v):
		bank_margin = v
		_emit()
## Shundan yaqin ikki ko'prik bittaga birlashtiriladi (m).
@export_range(0.0, 60.0, 0.5, "or_greater") var merge_gap: float = 10.0:
	set(v):
		merge_gap = v
		_emit()
## Bundan qisqa kesishmalarga ko'prik qurilmaydi (m).
@export_range(0.0, 30.0, 0.5, "or_greater") var min_span_length: float = 2.0:
	set(v):
		min_span_length = v
		_emit()
## Yo'l ko'prik balandligiga silliq ko'tariladigan masofa (m).
@export_range(0.0, 80.0, 0.5, "or_greater") var ramp_length: float = 5.0:
	set(v):
		ramp_length = v
		_emit()
## ROAD = yo'l materiali davom etadi, PLANKS = yog'och taxtalar.
@export var deck_surface: DeckSurface = DeckSurface.ROAD:
	set(v):
		deck_surface = v
		_emit()
## Chet bordyur balandligi.
@export_range(0.0, 1.0, 0.01, "or_greater") var curb_height: float = 0.12:
	set(v):
		curb_height = v
		_emit()
## Taxta uzunligi (PLANKS rejimi).
@export_range(0.1, 2.0, 0.01, "or_greater") var plank_length: float = 0.35:
	set(v):
		plank_length = v
		_emit()
## Taxtalar orasidagi tirqish.
@export_range(0.0, 0.3, 0.005) var plank_gap: float = 0.04:
	set(v):
		plank_gap = v
		_emit()
@export_group("Tayanchlar (Piers)")
## -1 = avtomatik, 0 = tayanchsiz, n = aniq soni.
@export_range(-1, 40, 1, "or_greater") var pier_count: int = -1:
	set(v):
		pier_count = v
		_emit()
## Avtomatik tayanch oralig'i (m).
@export_range(2.0, 200.0, 0.5, "or_greater") var max_unsupported: float = 12.0:
	set(v):
		max_unsupported = v
		_emit()
## Tayanch shakli.
@export var pier_shape: PierShape = PierShape.WALL_ROUNDED:
	set(v):
		pier_shape = v
		_emit()
## Tayanch qalinligi (yo'l bo'ylab).
@export_range(0.1, 8.0, 0.05, "or_greater") var pier_width: float = 1.2:
	set(v):
		pier_width = v
		_emit()
## Tayanch yerga qancha botib kiradi.
@export_range(0.0, 5.0, 0.1, "or_greater") var pier_embed: float = 0.6:
	set(v):
		pier_embed = v
		_emit()
## Ko'prik boshi va oxirida tayanch devor (abutment).
@export var abutment_enabled: bool = true:
	set(v):
		abutment_enabled = v
		_emit()
## Abutment qalinligi.
@export_range(0.2, 8.0, 0.1, "or_greater") var abutment_width: float = 1.6:
	set(v):
		abutment_width = v
		_emit()
@export_group("Arka (Arch)")
## 0 = avtomatik. HUMPBACK doim 1 ta arka.
@export_range(0, 24, 1, "or_greater") var arch_count: int = 0:
	set(v):
		arch_count = v
		_emit()
## Avtomatik arka oralig'i (m).
@export_range(2.0, 80.0, 0.5, "or_greater") var arch_max_span: float = 10.0:
	set(v):
		arch_max_span = v
		_emit()
## Arka balandligi / oralig' (0.5 = yarim aylana).
@export_range(0.1, 0.5, 0.01) var arch_rise_ratio: float = 0.38:
	set(v):
		arch_rise_ratio = v
		_emit()
## Arka halqasi qalinligi.
@export_range(0.1, 3.0, 0.05, "or_greater") var arch_thickness: float = 0.6:
	set(v):
		arch_thickness = v
		_emit()
## Arka tepasi va ko'prik poli orasidagi to'ldirma.
@export_range(0.0, 3.0, 0.05, "or_greater") var arch_fill: float = 0.35:
	set(v):
		arch_fill = v
		_emit()
## Arka silliqligi (segmentlar soni).
@export_range(6, 64, 1) var arch_segments: int = 18:
	set(v):
		arch_segments = v
		_emit()
@export_group("Panjara (Railing)")
## Panjara turi.
@export var railing_style: RailingStyle = RailingStyle.POSTS_AND_RAILS:
	set(v):
		railing_style = v
		_emit()
## Panjara balandligi.
@export_range(0.2, 3.0, 0.05, "or_greater") var railing_height: float = 1.0:
	set(v):
		railing_height = v
		_emit()
## Ustunlar orasidagi masofa.
@export_range(0.3, 10.0, 0.1, "or_greater") var post_spacing: float = 2.0:
	set(v):
		post_spacing = v
		_emit()
## Ustun qalinligi.
@export_range(0.03, 0.6, 0.01, "or_greater") var post_size: float = 0.14:
	set(v):
		post_size = v
		_emit()
## Gorizontal to'sinlar soni.
@export_range(1, 6, 1) var rail_count: int = 2:
	set(v):
		rail_count = v
		_emit()
## To'sin qalinligi.
@export_range(0.02, 0.4, 0.01, "or_greater") var rail_size: float = 0.08:
	set(v):
		rail_size = v
		_emit()
## Devor (parapet) qalinligi.
@export_range(0.05, 1.5, 0.05, "or_greater") var parapet_thickness: float = 0.3:
	set(v):
		parapet_thickness = v
		_emit()
@export_group("Ferma (Truss)")
## Ferma balandligi.
@export_range(1.0, 15.0, 0.1, "or_greater") var truss_height: float = 3.8:
	set(v):
		truss_height = v
		_emit()
## Sterjenlar qalinligi.
@export_range(0.04, 1.0, 0.01, "or_greater") var truss_member_size: float = 0.18:
	set(v):
		truss_member_size = v
		_emit()
## 0 = avtomatik panellar soni.
@export_range(0, 60, 1, "or_greater") var truss_panels: int = 0:
	set(v):
		truss_panels = v
		_emit()
## Tepada ko'ndalang bog'lovchilar.
@export var truss_top_bracing: bool = true:
	set(v):
		truss_top_bracing = v
		_emit()
@export_group("Osma ko'prik (Suspension)")
## Minora balandligi (yo'ldan yuqori).
@export_range(2.0, 60.0, 0.5, "or_greater") var tower_height: float = 9.0:
	set(v):
		tower_height = v
		_emit()
## Minora qalinligi.
@export_range(0.1, 4.0, 0.05, "or_greater") var tower_size: float = 0.7:
	set(v):
		tower_size = v
		_emit()
## Arqon o'rtadagi cho'kishi (minora uchidan).
@export_range(0.2, 30.0, 0.1, "or_greater") var cable_sag: float = 3.5:
	set(v):
		cable_sag = v
		_emit()
## Arqon qalinligi.
@export_range(0.02, 0.6, 0.01, "or_greater") var cable_thickness: float = 0.12:
	set(v):
		cable_thickness = v
		_emit()
## Osma sim oralig'i.
@export_range(0.5, 12.0, 0.1, "or_greater") var hanger_spacing: float = 2.5:
	set(v):
		hanger_spacing = v
		_emit()
## Orqa tortuvchi arqon uzunligi.
@export_range(0.0, 60.0, 0.5, "or_greater") var anchor_length: float = 10.0:
	set(v):
		anchor_length = v
		_emit()
@export_group("Yog'och (Wooden)")
## Tayanchlarda X shaklidagi mustahkamlagichlar.
@export var wood_bracing: bool = true:
	set(v):
		wood_bracing = v
		_emit()
## Taxtalar ostida bo'ylama to'sinlar.
@export var wood_stringers: bool = true:
	set(v):
		wood_stringers = v
		_emit()
@export_group("Material va Tekstura")
## Konstruksiya uchun tayyor material (bo'lsa, quyidagi sozlamalar e'tiborsiz qoladi).
@export var structure_material: Material = null:
	set(v):
		structure_material = v
		_emit()
## Panjara uchun tayyor material.
@export var railing_material: Material = null:
	set(v):
		railing_material = v
		_emit()
## Ko'prik usti uchun material. Bo'sh bo'lsa yo'l materiali ishlatiladi.
@export var deck_material: Material = null:
	set(v):
		deck_material = v
		_emit()
## Konstruksiya teksturalari.
@export var structure_texture_set: LiveTextureSet = null:
	set(v):
		structure_texture_set = v
		_emit()
## Panjara teksturalari.
@export var railing_texture_set: LiveTextureSet = null:
	set(v):
		railing_texture_set = v
		_emit()
## Uslubga mos standart rang (tosh/yog'och/po'lat) ishlatiladi.
@export var use_style_colors: bool = true:
	set(v):
		use_style_colors = v
		_emit()
## Konstruksiya rangi (standart rangga ko'paytiriladi).
@export var structure_tint: Color = Color(1, 1, 1):
	set(v):
		structure_tint = v
		_emit()
## Panjara rangi.
@export var railing_tint: Color = Color(1, 1, 1):
	set(v):
		railing_tint = v
		_emit()
## Teksturasiz konstruksiya g'adir-budurligi.
@export_range(0.0, 1.0, 0.01) var structure_roughness: float = 0.85:
	set(v):
		structure_roughness = v
		_emit()
## Panjara metallik darajasi.
@export_range(0.0, 1.0, 0.01) var railing_metallic: float = 0.0:
	set(v):
		railing_metallic = v
		_emit()
@export_group("O'z mesh (Custom)")
## O'z ko'prik meshingiz. Uzunlik +Z o'qi bo'ylab, markazi yo'l sathida bo'lishi kerak.
@export var custom_mesh: Mesh = null:
	set(v):
		custom_mesh = v
		_emit()
## Yoki tayyor sahna (Node3D). Mesh bilan birga ishlatilsa ikkalasi ham joylanadi.
@export var custom_scene: PackedScene = null:
	set(v):
		custom_scene = v
		_emit()
## Mesh ko'prik uzunligiga qanday moslashadi.
@export var custom_fit: CustomFit = CustomFit.STRETCH_LENGTH:
	set(v):
		custom_fit = v
		_emit()
## Mesh asl uzunligi (Z bo'yicha). 0 = AABB dan avtomatik.
@export_range(0.0, 200.0, 0.1, "or_greater") var custom_mesh_length: float = 0.0:
	set(v):
		custom_mesh_length = v
		_emit()
## Joylashuv siljishi (ko'prik lokal koordinatasida: X yon, Y yuqori, Z uzunlik).
@export var custom_offset: Vector3 = Vector3.ZERO:
	set(v):
		custom_offset = v
		_emit()
## Y o'qi bo'yicha aylantirish (gradus).
@export_range(-180.0, 180.0, 1.0) var custom_rotation_y: float = 0.0:
	set(v):
		custom_rotation_y = v
		_emit()
## Qo'shimcha masshtab.
@export var custom_scale: Vector3 = Vector3.ONE:
	set(v):
		custom_scale = v
		_emit()
## Mesh materialini almashtirish (bo'sh = mesh o'z materiali).
@export var custom_material: Material = null:
	set(v):
		custom_material = v
		_emit()
## Yo'l usti yuzasi (road materiali) saqlansin.
@export var custom_keep_road_surface: bool = true:
	set(v):
		custom_keep_road_surface = v
		_emit()
@export_group("Fizika")
## Ko'prik uchun to'qnashuv (StaticBody3D) yaratadi.
@export var generate_collision: bool = true:
	set(v):
		generate_collision = v
		_emit()
## Ko'prik soya tashlaydi.
@export var cast_shadows: bool = true:
	set(v):
		cast_shadows = v
		_emit()

@export_group("Namunalar")
@export_tool_button("Uslub namunasini qo'llash", "Reload") var _btn_preset = apply_style_defaults


func _emit() -> void:
	if not _mute:
		emit_changed()


func is_custom() -> bool:
	return custom_mesh != null or custom_scene != null


static func style_name(s: int) -> String:
	match s:
		Style.SLAB: return "Plita (Beam)"
		Style.STONE_ARCH: return "Tosh arka"
		Style.HUMPBACK: return "Bukri arka"
		Style.WOODEN: return "Yog'och"
		Style.TRUSS: return "Ferma (Truss)"
		Style.SUSPENSION: return "Osma ko'prik"
	return "?"


## Tanlangan uslub uchun tavsiya etilgan qiymatlarni o'rnatadi.
func apply_style_defaults() -> void:
	_mute = true
	# Umumiy boshlang'ich holat
	deck_surface = DeckSurface.ROAD
	deck_camber = 0.0
	pier_count = -1
	pier_shape = PierShape.WALL_ROUNDED
	pier_width = 1.2
	max_unsupported = 12.0
	width_extra = 0.6
	bank_margin = 2.0
	ramp_length = 5.0
	railing_style = RailingStyle.POSTS_AND_RAILS
	railing_height = 1.0
	post_spacing = 2.0
	post_size = 0.14
	rail_count = 2
	rail_size = 0.08
	match style:
		Style.SLAB:
			deck_thickness = 0.55
		Style.STONE_ARCH:
			deck_thickness = 0.5
			deck_camber = 0.6
			arch_count = 0
			arch_max_span = 9.0
			arch_rise_ratio = 0.38
			arch_thickness = 0.6
			pier_width = 1.5
			abutment_width = 1.6
			railing_style = RailingStyle.SOLID_PARAPET
			railing_height = 0.9
			parapet_thickness = 0.35
		Style.HUMPBACK:
			deck_thickness = 0.45
			deck_camber = 1.2
			arch_count = 1
			arch_rise_ratio = 0.3
			arch_thickness = 0.55
			width_extra = 0.4
			ramp_length = 8.0
			bank_margin = 1.5
			railing_style = RailingStyle.SOLID_PARAPET
			railing_height = 0.85
			parapet_thickness = 0.35
		Style.WOODEN:
			deck_surface = DeckSurface.PLANKS
			deck_thickness = 0.25
			deck_camber = 0.25
			width_extra = 0.3
			pier_shape = PierShape.COLUMNS_ROUND
			pier_width = 0.45
			max_unsupported = 5.0
			railing_style = RailingStyle.WOODEN_FENCE
			railing_height = 1.0
			post_spacing = 1.6
			post_size = 0.16
			rail_size = 0.1
		Style.TRUSS:
			deck_thickness = 0.45
			width_extra = 1.0
			pier_shape = PierShape.COLUMNS_SQUARE
			pier_width = 0.9
			max_unsupported = 40.0
			railing_style = RailingStyle.NONE
			truss_height = 3.8
			truss_member_size = 0.18
		Style.SUSPENSION:
			deck_thickness = 0.35
			width_extra = 0.8
			bank_margin = 3.0
			pier_count = 0
			railing_style = RailingStyle.POSTS_AND_RAILS
			railing_height = 1.1
			rail_count = 3
			tower_height = 9.0
			cable_sag = 3.5
	_mute = false
	emit_changed()
	notify_property_list_changed()
