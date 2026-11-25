extends SceneTree

const LampLightController := preload("res://addons/live_river_road/lamp_light_controller.gd")
const LampSettingsScript := preload("res://addons/live_river_road/lamp_settings.gd")
const LampBuilder := preload("res://addons/live_river_road/lamp_builder.gd")
const LivePathScript := preload("res://addons/live_river_road/live_path_3d.gd")
const LiveRoadScript := preload("res://addons/live_river_road/live_road_3d.gd")
const LiveRiverScript := preload("res://addons/live_river_road/live_river_3d.gd")


func _initialize() -> void:
	_test_script_resources_load()
	_test_lamp_resource_and_lod_meshes()
	_test_nearest_selection()
	_test_range_filter()
	_test_zero_and_unbounded_limits()
	_test_tie_order_and_mobile_cap()
	print("Lamp LOD contract tests: PASS")
	quit()


func _test_script_resources_load() -> void:
	assert(LivePathScript.can_instantiate(), "LivePath3D script must load")
	assert(LiveRoadScript.can_instantiate(), "LiveRoad3D script must load")
	assert(LiveRiverScript.can_instantiate(), "LiveRiver3D script must load")


func _test_lamp_resource_and_lod_meshes() -> void:
	var settings: LampSettingsScript = LampSettingsScript.new()
	assert(settings.max_active_lights == 6, "Default mobile light cap must be six")
	settings.max_active_lights = 12
	assert(settings.max_active_lights == 8, "The exported setter must clamp the mobile cap to eight")

	for level in range(3):
		var mesh: ArrayMesh = LampBuilder.build_mesh(settings, level)
		assert(mesh != null, "Every lamp LOD must produce a mesh")
		assert(mesh.get_surface_count() == 2, "Every lamp LOD must preserve pole and lamp-head surfaces")
		var materials: Array = LampBuilder.make_materials(settings, level)
		assert(materials.size() == 2, "Every lamp LOD must provide pole and lamp-head materials")


func _test_nearest_selection() -> void:
	var points: Array[Vector3] = [
		Vector3(20, 0, 0),
		Vector3(3, 0, 0),
		Vector3(9, 0, 0),
		Vector3(1, 0, 0)
	]
	var got := LampLightController.select_nearest_indices(points, Vector3.ZERO, 50.0, 2)
	assert(got == [3, 1], "Nearest K selection must return ascending distance")


func _test_range_filter() -> void:
	var points: Array[Vector3] = [
		Vector3(4, 0, 0),
		Vector3(12, 0, 0),
		Vector3(30, 0, 0)
	]
	var got := LampLightController.select_nearest_indices(points, Vector3.ZERO, 15.0, 8)
	assert(got == [0, 1], "Lights outside activation radius must be excluded")


func _test_zero_and_unbounded_limits() -> void:
	var points: Array[Vector3] = [Vector3.ZERO, Vector3(1000, 0, 0)]
	assert(LampLightController.select_nearest_indices(points, Vector3.ZERO, 0.0, 0).is_empty())
	var all_near := LampLightController.select_nearest_indices(points, Vector3.ZERO, 0.0, 8)
	assert(all_near == [0, 1], "Non-positive range means no distance culling")


func _test_tie_order_and_mobile_cap() -> void:
	var points: Array[Vector3] = []
	for i in range(20):
		var x := 1.0 if i % 2 == 0 else -1.0
		points.append(Vector3(x, 0.0, 0.0))
	var got := LampLightController.select_nearest_indices(points, Vector3.ZERO, 0.0, 20)
	assert(got.size() == 8, "Mobile light cap must never exceed eight")
	assert(got == [0, 1, 2, 3, 4, 5, 6, 7], "Equal-distance ordering must preserve stable source order")
