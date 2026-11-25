@tool
extends Node3D
## Kamera yaqinidagi haqiqiy yoritgichlarni cheklangan miqdorda faollashtiradi.
## Emissive MultiMesh modellari uzoq masofada ham ko'rinadi; OmniLight3D faqat yaqin masofada ishlaydi.

var _lights: Array[OmniLight3D] = []
var _max_active: int = 6
var _activation_range: float = 45.0
var _update_interval: float = 0.35
var _night_mode: bool = true
var _elapsed: float = 0.0


func configure(
	lights: Array[OmniLight3D],
	max_active: int,
	activation_range: float,
	update_interval: float,
	night_mode: bool = true
) -> void:
	_lights = lights.duplicate()
	_max_active = clampi(max_active, 0, 8)
	_activation_range = maxf(activation_range, 0.0)
	_update_interval = maxf(update_interval, 0.1)
	_night_mode = night_mode
	set_process(not _lights.is_empty())
	_refresh()


## Kun/tun tizimidan chaqiriladi. false bo'lsa haqiqiy nurlar o'chadi,
## emissive chiroq boshlari esa ko'rinishda qoladi.
func set_night_mode(enabled: bool) -> void:
	if _night_mode == enabled:
		return
	_night_mode = enabled
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _update_interval:
		return
	_elapsed = 0.0
	_refresh()


func _refresh() -> void:
	var valid_lights: Array[OmniLight3D] = []
	var positions: Array[Vector3] = []
	for light in _lights:
		if not is_instance_valid(light) or not light.is_inside_tree():
			continue
		valid_lights.append(light)
		positions.append(light.global_position)

	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var selected: Array[int] = []
	if _night_mode and _max_active > 0 and camera != null:
		selected = select_nearest_indices(
			positions,
			camera.global_position,
			_activation_range,
			_max_active
		)

	var active := {}
	for index in selected:
		active[index] = true
	for i in range(valid_lights.size()):
		valid_lights[i].visible = active.has(i)


## Eng yaqin K ta yoritgich indeksini qaytaradi.
## O(n*K) bounded insertion: katta ro'yxatni har safar to'liq sort qilmaydi.
## max_distance <= 0 bo'lsa masofa filtri o'chadi.
static func select_nearest_indices(
	positions: Array[Vector3],
	camera_position: Vector3,
	max_distance: float,
	max_count: int
) -> Array[int]:
	var result: Array[int] = []
	var best_distances: Array[float] = []
	var limit := clampi(max_count, 0, 8)
	if limit == 0:
		return result

	var max_distance_sq := INF
	if max_distance > 0.0:
		max_distance_sq = max_distance * max_distance

	for i in range(positions.size()):
		var distance_sq := positions[i].distance_squared_to(camera_position)
		if distance_sq > max_distance_sq:
			continue

		var insert_at := best_distances.size()
		for j in range(best_distances.size()):
			if distance_sq < best_distances[j] - 0.000001:
				insert_at = j
				break

		if insert_at >= limit:
			continue

		result.insert(insert_at, i)
		best_distances.insert(insert_at, distance_sq)
		if result.size() > limit:
			result.pop_back()
			best_distances.pop_back()

	return result
