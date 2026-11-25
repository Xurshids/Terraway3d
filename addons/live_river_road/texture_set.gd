@tool
@icon("res://addons/live_river_road/icons/texture_set.svg")
class_name LiveTextureSet
extends Resource
## Yo'l, ko'prik va panjara uchun almashtiriladigan PBR tekstura to'plami.
## Uni .tres sifatida saqlab, bir nechta yo'l/ko'prikka ulashish mumkin.

@export_group("Teksturalar")
@export var albedo_texture: Texture2D:
	set(v):
		albedo_texture = v
		emit_changed()
@export var normal_texture: Texture2D:
	set(v):
		normal_texture = v
		emit_changed()
@export var roughness_texture: Texture2D:
	set(v):
		roughness_texture = v
		emit_changed()
@export var ao_texture: Texture2D:
	set(v):
		ao_texture = v
		emit_changed()

@export_group("Parametrlar")
@export var tint: Color = Color.WHITE:
	set(v):
		tint = v
		emit_changed()
## Tekstura takrorlanishi (1 = bitta takror yo'l kengligiga teng).
@export var uv_tiling: Vector2 = Vector2.ONE:
	set(v):
		uv_tiling = v
		emit_changed()
@export var uv_offset: Vector2 = Vector2.ZERO:
	set(v):
		uv_offset = v
		emit_changed()
@export_range(0.0, 4.0, 0.05, "or_greater") var normal_strength: float = 1.0:
	set(v):
		normal_strength = v
		emit_changed()
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.85:
	set(v):
		roughness = v
		emit_changed()
@export_range(0.0, 1.0, 0.01) var metallic: float = 0.0:
	set(v):
		metallic = v
		emit_changed()
## Ko'prik kabi murakkab geometriya uchun dunyo koordinatalarida triplanar mapping.
@export var triplanar: bool = false:
	set(v):
		triplanar = v
		emit_changed()


func has_any_texture() -> bool:
	return albedo_texture != null or normal_texture != null or roughness_texture != null or ao_texture != null


## StandardMaterial3D ga qo'llaydi (ko'prik/panjara uchun).
func apply_to_standard(mat: StandardMaterial3D, base_color: Color) -> void:
	mat.albedo_color = base_color * tint
	mat.albedo_texture = albedo_texture
	mat.normal_enabled = normal_texture != null
	mat.normal_texture = normal_texture
	mat.normal_scale = normal_strength
	mat.roughness = roughness
	mat.roughness_texture = roughness_texture
	mat.metallic = metallic
	mat.ao_enabled = ao_texture != null
	mat.ao_texture = ao_texture
	mat.uv1_scale = Vector3(uv_tiling.x, uv_tiling.y, 1.0)
	mat.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0.0)
	mat.uv1_triplanar = triplanar
	mat.uv1_world_triplanar = triplanar
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if triplanar:
		mat.uv1_scale = Vector3(uv_tiling.x, uv_tiling.x, uv_tiling.x) * 0.25


## Yo'l shaderiga (live_road.gdshader) qo'llaydi.
func apply_to_road_shader(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("use_textures", albedo_texture != null)
	mat.set_shader_parameter("albedo_texture", albedo_texture)
	mat.set_shader_parameter("use_normal_texture", normal_texture != null)
	mat.set_shader_parameter("normal_texture", normal_texture)
	mat.set_shader_parameter("use_roughness_texture", roughness_texture != null)
	mat.set_shader_parameter("roughness_texture", roughness_texture)
	mat.set_shader_parameter("use_ao_texture", ao_texture != null)
	mat.set_shader_parameter("ao_texture", ao_texture)
	mat.set_shader_parameter("texture_tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("texture_tiling", uv_tiling)
	mat.set_shader_parameter("texture_offset", uv_offset)
	mat.set_shader_parameter("texture_normal_strength", normal_strength)
	mat.set_shader_parameter("texture_roughness", roughness)
