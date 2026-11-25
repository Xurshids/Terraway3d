@tool
extends RefCounted
## Yoritgich mesh'i va materiallari. Har bir LOD uchun alohida 3D mesh yaratadi.

const BridgeBuilder := preload("res://addons/live_river_road/bridge_builder.gd")


## Poya asosi (0,0,0), balandlik +Y, yo'l tomon +X.
## Sirt 0 = ustun, sirt 1 = chiroq boshi.
static func build_mesh(st: LiveLampSettings, lod_level: int = 0) -> ArrayMesh:
	var out := BridgeBuilder.Out.new()
	var H := st.pole_height
	var r := st.pole_radius
	var S := BridgeBuilder.ROLE_STRUCT
	var R := BridgeBuilder.ROLE_RAIL
	var level := clampi(lod_level, 0, 2)
	var pole_sides := 8 if level == 0 else (6 if level == 1 else 5)

	if level < 2:
		out.cylinder(S, Vector3(0, 0, 0), Vector3(0, 0.3, 0), r * 1.9, pole_sides + 2, true)
	out.cylinder(S, Vector3(0, 0.25, 0), Vector3(0, H, 0), r, pole_sides, true)

	var arm_end := Vector3(st.arm_length, H + st.arm_rise, 0.0)
	if st.arm_length > 0.05:
		out.beam(S, Vector3(0, H - 0.05, 0), arm_end, Vector3(0, 0, 1), r * 1.4, r * 1.4)
	out.box(
		R,
		arm_end + Vector3(0, -0.02, 0),
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.BACK,
		st.head_length * 0.5,
		0.07,
		st.head_width * 0.5
	)

	var res: Dictionary = out.finish()
	var mesh: ArrayMesh = res["mesh"]
	var materials := make_materials(st, level)
	for i in range(mesh.get_surface_count()):
		if i < materials.size():
			mesh.surface_set_material(i, materials[i])
	return mesh


static func make_materials(st: LiveLampSettings, lod_level: int = 0) -> Array:
	var level := clampi(lod_level, 0, 2)
	var pole: Material = st.pole_material if level == 0 else null
	var head: Material = st.head_material if level == 0 else null
	var pole_albedo: Texture2D = null
	var head_albedo: Texture2D = null

	if level == 1:
		pole = st.lod1_pole_material
		head = st.lod1_head_material
		pole_albedo = st.lod1_pole_albedo
		head_albedo = st.lod1_head_albedo
	elif level == 2:
		pole = st.lod2_pole_material
		head = st.lod2_head_material
		pole_albedo = st.lod2_pole_albedo
		head_albedo = st.lod2_head_albedo

	if pole == null:
		var pm := StandardMaterial3D.new()
		pm.albedo_color = st.pole_color
		pm.roughness = 0.55 if level == 0 else (0.78 if level == 1 else 1.0)
		pm.metallic = 0.4 if level == 0 else (0.12 if level == 1 else 0.0)
		pm.albedo_texture = pole_albedo
		pole = pm

	if head == null:
		var hm := StandardMaterial3D.new()
		hm.albedo_color = st.head_color
		hm.roughness = 0.4 if level == 0 else (0.65 if level == 1 else 0.85)
		hm.albedo_texture = head_albedo
		if st.emission_energy > 0.001:
			hm.emission_enabled = true
			hm.emission = st.emission_color
			hm.emission_energy_multiplier = st.emission_energy
		head = hm

	return [pole, head]
