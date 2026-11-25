@tool
@icon("res://addons/live_river_road/icons/lamp.svg")
class_name LiveLampSettings
extends Resource
## Yoritgichlar sozlamalari. LiveRoad3D.lamp_settings ga biriktiriladi.

enum LampMode { POINTS, RANGE }
enum LampSide { LEFT, RIGHT, BOTH, ALTERNATE }


@export_group("Joylashuv")
## POINTS = faqat belgilangan nuqtalarda; RANGE = belgilangan nuqtalar juftligi orasida har N metrda.
@export var lamp_mode: LampMode = LampMode.POINTS:
	set(v):
		lamp_mode = v
		emit_changed()
## Yo'lning qaysi tomoniga.
@export var lamp_side: LampSide = LampSide.BOTH:
	set(v):
		lamp_side = v
		emit_changed()
## RANGE rejimida yoritgichlar orasidagi masofa.
@export_range(3.0, 200.0, 0.5, "or_greater") var spacing: float = 25.0:
	set(v):
		spacing = v
		emit_changed()
## Yo'l chetidan tashqariga masofa.
@export_range(-2.0, 10.0, 0.1, "or_greater") var edge_offset: float = 0.8:
	set(v):
		edge_offset = v
		emit_changed()
## Poya terrain yuzasiga tushadi.
@export var ground_snap: bool = true:
	set(v):
		ground_snap = v
		emit_changed()
## Balandlikni qo'lda siljitish.
@export_range(-2.0, 5.0, 0.05, "or_greater") var height_offset: float = 0.0:
	set(v):
		height_offset = v
		emit_changed()
@export_group("O'lcham")
## Ustun balandligi.
@export_range(1.0, 30.0, 0.1, "or_greater") var pole_height: float = 7.0:
	set(v):
		pole_height = v
		emit_changed()
## Ustun qalinligi.
@export_range(0.02, 0.6, 0.01, "or_greater") var pole_radius: float = 0.09:
	set(v):
		pole_radius = v
		emit_changed()
## Yo'l tomonga chiqib turgan qo'l uzunligi.
@export_range(0.0, 10.0, 0.1, "or_greater") var arm_length: float = 2.2:
	set(v):
		arm_length = v
		emit_changed()
## Qo'l uchining ko'tarilishi.
@export_range(-1.0, 3.0, 0.05, "or_greater") var arm_rise: float = 0.5:
	set(v):
		arm_rise = v
		emit_changed()
## Chiroq boshi uzunligi.
@export_range(0.1, 4.0, 0.05, "or_greater") var head_length: float = 0.95:
	set(v):
		head_length = v
		emit_changed()
## Chiroq boshi kengligi.
@export_range(0.05, 2.0, 0.01, "or_greater") var head_width: float = 0.38:
	set(v):
		head_width = v
		emit_changed()
## Umumiy masshtab.
@export_range(0.1, 5.0, 0.05, "or_greater") var lamp_scale: float = 1.0:
	set(v):
		lamp_scale = v
		emit_changed()
@export_group("Material")
@export var pole_color: Color = Color(0.28, 0.3, 0.33):
	set(v):
		pole_color = v
		emit_changed()
@export var head_color: Color = Color(0.9, 0.88, 0.8):
	set(v):
		head_color = v
		emit_changed()
@export var emission_color: Color = Color(1.0, 0.85, 0.55):
	set(v):
		emission_color = v
		emit_changed()
## Chiroq nuri yorqinligi (0 = o'chiq).
@export_range(0.0, 16.0, 0.1, "or_greater") var emission_energy: float = 3.0:
	set(v):
		emission_energy = v
		emit_changed()
## Ustun uchun tayyor material.
@export var pole_material: Material = null:
	set(v):
		pole_material = v
		emit_changed()
## Chiroq boshi uchun tayyor material.
@export var head_material: Material = null:
	set(v):
		head_material = v
		emit_changed()
@export_group("O'z model")
## O'z yoritgich modelingiz. Poya asosi (0,0,0), balandlik +Y, yo'l tomon +X bo'lsin.
@export var custom_mesh: Mesh = null:
	set(v):
		custom_mesh = v
		emit_changed()
## O'z model uchun material.
@export var custom_material: Material = null:
	set(v):
		custom_material = v
		emit_changed()
@export var custom_scale: Vector3 = Vector3.ONE:
	set(v):
		custom_scale = v
		emit_changed()
@export_range(-180.0, 180.0, 1.0) var custom_rotation_y: float = 0.0:
	set(v):
		custom_rotation_y = v
		emit_changed()
@export_group("Haqiqiy yorug'lik")
## Har bir yoritgichga OmniLight3D qo'shadi. DIQQAT: ko'p bo'lsa FPS tushadi.
@export var real_lights: bool = false:
	set(v):
		real_lights = v
		emit_changed()
@export var light_color: Color = Color(1.0, 0.86, 0.6):
	set(v):
		light_color = v
		emit_changed()
@export_range(2.0, 80.0, 0.5, "or_greater") var light_range: float = 16.0:
	set(v):
		light_range = v
		emit_changed()
@export_range(0.0, 16.0, 0.1, "or_greater") var light_energy: float = 1.6:
	set(v):
		light_energy = v
		emit_changed()
## Bir vaqtda ishlaydigan haqiqiy chiroqlar soni. Mobil uchun 8 dan oshmaydi.
@export_range(0, 8, 1) var max_active_lights: int = 6:
	set(v):
		max_active_lights = clampi(v, 0, 8)
		emit_changed()
## Haqiqiy yorug'lik faqat kamera shu radius ichida bo'lganda yoqiladi.
@export_range(0.0, 200.0, 1.0, "or_greater") var light_activation_range: float = 45.0:
	set(v):
		light_activation_range = v
		emit_changed()
## Kamera bo'yicha yorug'lik ro'yxatini yangilash oralig'i.
@export_range(0.1, 2.0, 0.05) var light_update_interval: float = 0.35:
	set(v):
		light_update_interval = v
		emit_changed()
## O'yin kunduz/tun tizimi bo'lmasa true; tun-kun skriptidan set_night_mode() chaqirish mumkin.
@export var night_mode_enabled: bool = true:
	set(v):
		night_mode_enabled = v
		emit_changed()
@export_group("Tezlik (MultiMesh)")
## Soya tashlash (FPS ga ta'sir qiladi).
@export var cast_shadows: bool = false:
	set(v):
		cast_shadows = v
		emit_changed()
## Shu masofadan uzoqda yoritgichlar ko'rinmaydi. 0 = cheksiz.
@export_range(0.0, 2000.0, 5.0, "or_greater") var visibility_range: float = 0.0:
	set(v):
		visibility_range = v
		emit_changed()

@export_group("LOD (Yoritgich ko'rinishi)")
## 3 ta haqiqiy 3D daraja: to'liq model, soddalashtirilgan model, uzoq 3D model.
@export var lod_enabled: bool = true:
	set(v):
		lod_enabled = v
		emit_changed()
## LOD0 dan LOD1 ga o'tish masofasi.
@export_range(5.0, 500.0, 5.0, "or_greater") var lod0_end_distance: float = 45.0:
	set(v):
		lod0_end_distance = v
		emit_changed()
## LOD1 dan LOD2 ga o'tish masofasi.
@export_range(10.0, 2000.0, 10.0, "or_greater") var lod1_end_distance: float = 160.0:
	set(v):
		lod1_end_distance = v
		emit_changed()
## O'tish chegarasidagi hysteresis; keskin oldinga-orqaga almashishni kamaytiradi.
@export_range(0.0, 30.0, 0.5) var lod_transition_margin: float = 4.0:
	set(v):
		lod_transition_margin = v
		emit_changed()
## MultiMesh bitta katta yo'l bo'ylab emas, qisqa fazoviy bo'laklarda guruhlanadi.
@export_range(20.0, 500.0, 10.0, "or_greater") var lod_chunk_length: float = 100.0:
	set(v):
		lod_chunk_length = v
		emit_changed()
## Ixtiyoriy qo'lda tayyorlangan soddalashtirilgan 3D modellar.
@export var lod1_mesh: Mesh = null:
	set(v):
		lod1_mesh = v
		emit_changed()
@export var lod2_mesh: Mesh = null:
	set(v):
		lod2_mesh = v
		emit_changed()

@export_group("LOD materiallari")
## LOD1 uchun poya/bosh materiallari va albedo teksturalari.
@export var lod1_pole_material: Material = null:
	set(v):
		lod1_pole_material = v
		emit_changed()
@export var lod1_head_material: Material = null:
	set(v):
		lod1_head_material = v
		emit_changed()
@export var lod1_pole_albedo: Texture2D = null:
	set(v):
		lod1_pole_albedo = v
		emit_changed()
@export var lod1_head_albedo: Texture2D = null:
	set(v):
		lod1_head_albedo = v
		emit_changed()
## LOD2 uchun yengil albedo materiallari. Bosh materiali emissive bo'lishi mumkin.
@export var lod2_pole_material: Material = null:
	set(v):
		lod2_pole_material = v
		emit_changed()
@export var lod2_head_material: Material = null:
	set(v):
		lod2_head_material = v
		emit_changed()
@export var lod2_pole_albedo: Texture2D = null:
	set(v):
		lod2_pole_albedo = v
		emit_changed()
@export var lod2_head_albedo: Texture2D = null:
	set(v):
		lod2_head_albedo = v
		emit_changed()

