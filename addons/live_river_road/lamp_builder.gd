@tool
extends RefCounted
## Yoritgich mesh'i va materiallari (MultiMesh uchun bitta mesh).

const BridgeBuilder := preload("res://addons/live_river_road/bridge_builder.gd")


## Poya asosi (0,0,0), balandlik +Y, yo'l tomon +X. Sirt 0 = ustun, sirt 1 = chiroq boshi.
static func build_mesh(st: LiveLampSettings) -> ArrayMesh:
	var out := BridgeBuilder.Out.new()
	var H := st.pole_height
	var r := st.pole_radius
	var S := BridgeBuilder.ROLE_STRUCT
	var R := BridgeBuilder.ROLE_RAIL
	out.cylinder(S, Vector3(0, 0, 0), Vector3(0, 0.3, 0), r * 1.9, 10, true)
	out.cylinder(S, Vector3(0, 0.25, 0), Vector3(0, H, 0), r, 8, true)
	var arm_end := Vector3(st.arm_length, H + st.arm_rise, 0.0)
	if st.arm_length > 0.05:
		out.beam(S, Vector3(0, H - 0.05, 0), arm_end, Vector3(0, 0, 1), r * 1.4, r * 1.4)
	out.box(R, arm_end + Vector3(0, -0.02, 0), Vector3.RIGHT, Vector3.UP, Vector3.BACK, st.head_length * 0.5, 0.07, st.head_width * 0.5)
	var res: Dictionary = out.finish()
	var mesh: ArrayMesh = res["mesh"]
	var mats := make_materials(st)
	for i in range(mesh.get_surface_count()):
		mesh.surface_set_material(i, mats[i])
	return mesh


static func make_materials(st: LiveLampSettings) -> Array:
	var pole: Material = st.pole_material
	if pole == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = st.pole_color
		m.roughness = 0.55
		m.metallic = 0.4
		pole = m
	var head: Material = st.head_material
	if head == null:
		var h := StandardMaterial3D.new()
		h.albedo_color = st.head_color
		h.roughness = 0.4
		if st.emission_energy > 0.001:
			h.emission_enabled = true
			h.emission = st.emission_color
			h.emission_energy_multiplier = st.emission_energy
		head = h
	return [pole, head]
