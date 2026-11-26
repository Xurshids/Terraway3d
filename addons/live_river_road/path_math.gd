@tool
extends RefCounted
## Yo'l geometriyasi uchun umumiy matematika (mesh quruvchi, chorraha yechuvchi va boshqalar ishlatadi).


static func cross2(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


## XZ tekislikdagi kumulyativ yoy uzunligi.
static func arc_lengths(pts: PackedVector3Array) -> PackedFloat32Array:
	var res := PackedFloat32Array()
	var acc := 0.0
	for i in range(pts.size()):
		if i > 0:
			acc += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		res.append(acc)
	return res


## i-nuqta uchun [yo'nalish (bissektrisa), chap chekka masofasi, o'ng chekka masofasi].
## Keskin burilishda ichki chekka burilish radiusidan oshmaydi (o'zini kesib o'tmaydi),
## tashqi chekka miter bilan cheklangan holda uzayadi.
static func row_frame(pts: PackedVector3Array, i: int, hw: float) -> Array:
	var n := pts.size()
	var cur := pts[i]
	var d_prev := Vector3.ZERO
	var d_next := Vector3.ZERO
	var len_prev := 0.0
	var len_next := 0.0
	if i > 0:
		var v := cur - pts[i - 1]
		v.y = 0.0
		len_prev = v.length()
		if len_prev > 0.00001:
			d_prev = v / len_prev
	if i < n - 1:
		var v2 := pts[i + 1] - cur
		v2.y = 0.0
		len_next = v2.length()
		if len_next > 0.00001:
			d_next = v2 / len_next
	if len_prev <= 0.00001 and len_next <= 0.00001:
		return [Vector3.FORWARD, hw, hw]
	if len_prev <= 0.00001:
		return [d_next, hw, hw]
	if len_next <= 0.00001:
		return [d_prev, hw, hw]

	var t := d_prev + d_next
	if t.length_squared() < 0.000001:
		t = d_next
	t = t.normalized()
	var cos_half := clampf(t.dot(d_next), 0.0, 1.0)
	var off := hw * minf(1.0 / maxf(cos_half, 0.4), 2.5)
	var off_l := off
	var off_r := off

	var side := Vector3(-t.z, 0.0, t.x)
	var inner_sign := (d_next - d_prev).dot(side)
	var ang := acos(clampf(d_prev.dot(d_next), -1.0, 1.0))
	if ang > 0.01:
		var radius := (0.5 * (len_prev + len_next)) / ang
		var limit := maxf(radius * 0.9, hw * 0.12)
		if inner_sign > 0.0:
			off_r = minf(off_r, limit)
		else:
			off_l = minf(off_l, limit)
	return [t, off_l, off_r]


## Ikki kesma (XZ) kesishuvi. [t, u] yoki bo'sh massiv.
static func seg_intersect_xz(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> Array:
	var r := Vector2(b.x - a.x, b.z - a.z)
	var s := Vector2(d.x - c.x, d.z - c.z)
	var den := cross2(r, s)
	if absf(den) < 0.000000001:
		return []
	var qp := Vector2(c.x - a.x, c.z - a.z)
	var t := cross2(qp, s) / den
	var u := cross2(qp, r) / den
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return []
	return [t, u]


## p1 + d1*t1 = p2 + d2*t2 ni yechadi. [t1, t2] yoki bo'sh massiv (parallel).
static func line_intersect_2d(p1: Vector2, d1: Vector2, p2: Vector2, d2: Vector2) -> Array:
	var det := cross2(d1, d2)
	if absf(det) < 0.0001:
		return []
	var w := p2 - p1
	return [cross2(w, d2) / det, cross2(w, d1) / det]


## p0 (aylana ichida) dan p1 (tashqarida) ga ketayotgan kesmaning aylanadan chiqish parametri.
static func circle_exit_t(c: Vector3, radius: float, p0: Vector3, p1: Vector3) -> float:
	var d := Vector2(p1.x - p0.x, p1.z - p0.z)
	var f := Vector2(p0.x - c.x, p0.z - c.z)
	var a := d.dot(d)
	if a < 0.0000001:
		return -1.0
	var b := 2.0 * f.dot(d)
	var cc := f.dot(f) - radius * radius
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return -1.0
	return clampf((-b + sqrt(disc)) / (2.0 * a), 0.0, 1.0)


static func dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Yoy uzunligi s dagi segment indeksi.
static func seg_of(s: PackedFloat32Array, sv: float) -> int:
	var lo := 0
	var hi := s.size() - 2
	if hi < 0:
		return 0
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if s[mid] <= sv:
			lo = mid
		else:
			hi = mid - 1
	return lo


static func point_at(pts: PackedVector3Array, s: PackedFloat32Array, sv: float) -> Vector3:
	if pts.size() == 0:
		return Vector3.ZERO
	if sv <= 0.0:
		return pts[0]
	if sv >= s[s.size() - 1]:
		return pts[pts.size() - 1]
	var k := seg_of(s, sv)
	var d := s[k + 1] - s[k]
	var t := 0.0 if d < 0.000001 else (sv - s[k]) / d
	return pts[k].lerp(pts[k + 1], t)
