@tool
extends RefCounted
## XZ tekisligidagi polyline uchun tezkor masofa indeksi (spatial hash).
## Daryo va yo'l kesishishini hamda terrain carve vaqtidagi "daryo yo'lagi"ni topish uchun ishlatiladi.
## Eslatma: nearest() faqat cell_size dan kichik masofalar uchun aniq natija beradi.

var _pts := PackedVector3Array()
var _cell := 8.0
var _grid: Dictionary = {}


func build(points: PackedVector3Array, cell_size: float = 8.0) -> void:
	_pts = points
	_cell = maxf(cell_size, 1.0)
	_grid.clear()
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var x0 := int(floor(minf(a.x, b.x) / _cell))
		var x1 := int(floor(maxf(a.x, b.x) / _cell))
		var z0 := int(floor(minf(a.z, b.z) / _cell))
		var z1 := int(floor(maxf(a.z, b.z) / _cell))
		for cx in range(x0, x1 + 1):
			for cz in range(z0, z1 + 1):
				var key := Vector2i(cx, cz)
				if not _grid.has(key):
					_grid[key] = []
				(_grid[key] as Array).append(i)


func is_empty() -> bool:
	return _pts.size() < 2


## [masofa, eng yaqin nuqta (Y interpolatsiya qilingan), segment indeksi, t] qaytaradi. Topilmasa [INF, Vector3.ZERO, -1, 0].
func nearest(p: Vector3) -> Array:
	var cx := int(floor(p.x / _cell))
	var cz := int(floor(p.z / _cell))
	var best := INF
	var best_pt := Vector3.ZERO
	var best_seg := -1
	var best_t := 0.0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var lst = _grid.get(Vector2i(cx + dx, cz + dz))
			if lst == null:
				continue
			for i in lst:
				var a: Vector3 = _pts[i]
				var b: Vector3 = _pts[i + 1]
				var abx := b.x - a.x
				var abz := b.z - a.z
				var l2 := abx * abx + abz * abz
				var t := 0.0
				if l2 > 0.000000001:
					t = clampf(((p.x - a.x) * abx + (p.z - a.z) * abz) / l2, 0.0, 1.0)
				var qx := a.x + abx * t
				var qz := a.z + abz * t
				var d2 := (p.x - qx) * (p.x - qx) + (p.z - qz) * (p.z - qz)
				if d2 < best:
					best = d2
					best_pt = Vector3(qx, lerpf(a.y, b.y, t), qz)
					best_seg = i
					best_t = t
	if best == INF:
		return [INF, Vector3.ZERO, -1, 0.0]
	return [sqrt(best), best_pt, best_seg, best_t]


## a-b kesma bilan bir xil katakchalardagi segmentlar indekslari (takrorlarsiz).
func candidates(a: Vector3, b: Vector3) -> Array:
	var x0 := int(floor(minf(a.x, b.x) / _cell))
	var x1 := int(floor(maxf(a.x, b.x) / _cell))
	var z0 := int(floor(minf(a.z, b.z) / _cell))
	var z1 := int(floor(maxf(a.z, b.z) / _cell))
	var seen := {}
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var lst = _grid.get(Vector2i(cx, cz))
			if lst == null:
				continue
			for i in lst:
				seen[i] = true
	return seen.keys()
