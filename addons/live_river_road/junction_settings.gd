@tool
@icon("res://addons/live_river_road/icons/junction.svg")
class_name LiveJunctionSettings
extends Resource
## Chorraha va aylana sozlamalari. LiveRoad3D.junction_settings ga biriktiriladi.

enum JunctionMode { AUTO, INTERSECTION, ROUNDABOUT, NONE }

var _mute := false

@export_group("Umumiy")
## AUTO = yo'nalishlar soniga qarab chorraha yoki aylana; boshqalari majburiy tur.
@export var junction_mode: JunctionMode = JunctionMode.AUTO:
	set(v):
		junction_mode = v
		_emit()
## AUTO rejimda shuncha yoki ko'p yo'nalish bo'lsa aylana quriladi.
@export_range(3, 12, 1, "or_greater") var roundabout_min_arms: int = 5:
	set(v):
		roundabout_min_arms = v
		_emit()
## Shundan yaqin kesishmalar bitta chorrahaga birlashtiriladi (m).
@export_range(1.0, 60.0, 0.5, "or_greater") var merge_radius: float = 12.0:
	set(v):
		merge_radius = v
		_emit()
## Yo'llar balandligi bundan ko'p farq qilsa, chorraha qurilmaydi (ko'prik/estakada).
@export_range(0.0, 20.0, 0.1, "or_greater") var max_height_diff: float = 3.0:
	set(v):
		max_height_diff = v
		_emit()
## Chorrahadan keyingi yo'l bundan qisqa bo'lsa, yo'nalish hisoblanmaydi.
@export_range(0.5, 30.0, 0.5, "or_greater") var min_arm_length: float = 3.0:
	set(v):
		min_arm_length = v
		_emit()
## Yo'l chorraha balandligiga silliq o'tadigan masofa.
@export_range(0.0, 60.0, 0.5, "or_greater") var blend_length: float = 10.0:
	set(v):
		blend_length = v
		_emit()
## Chorraha chetidagi pastga tushuvchi devorcha.
@export_range(0.0, 2.0, 0.05, "or_greater") var skirt_depth: float = 0.3:
	set(v):
		skirt_depth = v
		_emit()
## Chorraha uchun to'qnashuv (StaticBody3D).
@export var generate_collision: bool = true:
	set(v):
		generate_collision = v
		_emit()
@export_group("Chorraha (Intersection)")
## Burchaklarni yumaloqlash radiusi.
@export_range(0.0, 40.0, 0.1, "or_greater") var corner_radius: float = 5.0:
	set(v):
		corner_radius = v
		_emit()
## Yumaloq burchak silliqligi.
@export_range(2, 32, 1) var corner_segments: int = 8:
	set(v):
		corner_segments = v
		_emit()
## Chorraha markazidan yo'llar kesiladigan minimal masofa.
@export_range(2.0, 60.0, 0.5, "or_greater") var min_radius: float = 6.0:
	set(v):
		min_radius = v
		_emit()
## Maksimal masofa (o'tkir burchakli yo'llar uchun).
@export_range(4.0, 120.0, 0.5, "or_greater") var max_radius: float = 32.0:
	set(v):
		max_radius = v
		_emit()
@export_group("Aylana (Roundabout)")
## Aylana markaziy chizig'ining radiusi. 0 = avtomatik.
@export_range(0.0, 80.0, 0.5, "or_greater") var roundabout_radius: float = 0.0:
	set(v):
		roundabout_radius = v
		_emit()
## Aylana yo'li kengligi.
@export_range(2.0, 20.0, 0.1, "or_greater") var ring_width: float = 7.0:
	set(v):
		ring_width = v
		_emit()
## Aylana silliqligi.
@export_range(16, 256, 1) var ring_segments: int = 72:
	set(v):
		ring_segments = v
		_emit()
## Aylanagacha bo'lgan kirish qismi uzunligi.
@export_range(0.0, 40.0, 0.5, "or_greater") var approach_length: float = 5.0:
	set(v):
		approach_length = v
		_emit()
## Kirish qismining aylanaga yaqinlashganda kengayishi.
@export_range(0.0, 10.0, 0.1, "or_greater") var flare: float = 1.6:
	set(v):
		flare = v
		_emit()
## O'rta orolcha bordyuri balandligi.
@export_range(0.0, 1.0, 0.01, "or_greater") var island_curb_height: float = 0.18:
	set(v):
		island_curb_height = v
		_emit()
## Bordyur kengligi.
@export_range(0.05, 3.0, 0.05, "or_greater") var curb_width: float = 0.4:
	set(v):
		curb_width = v
		_emit()
## Orolcha rangi (material bo'lmasa).
@export var island_color: Color = Color(0.3, 0.42, 0.2):
	set(v):
		island_color = v
		_emit()
## Bordyur rangi (material bo'lmasa).
@export var curb_color: Color = Color(0.72, 0.72, 0.7):
	set(v):
		curb_color = v
		_emit()
## Orolcha uchun tayyor material.
@export var island_material: Material = null:
	set(v):
		island_material = v
		_emit()
## Bordyur uchun tayyor material.
@export var curb_material: Material = null:
	set(v):
		curb_material = v
		_emit()
## Orolcha markaziga qo'yiladigan sahna (daraxt, haykal, ...).
@export var island_scene: PackedScene = null:
	set(v):
		island_scene = v
		_emit()


func _emit() -> void:
	if not _mute:
		emit_changed()


static func mode_name(m: int) -> String:
	match m:
		JunctionMode.AUTO: return "Avtomatik"
		JunctionMode.INTERSECTION: return "Chorraha"
		JunctionMode.ROUNDABOUT: return "Aylana"
		JunctionMode.NONE: return "Yo'q"
	return "?"
