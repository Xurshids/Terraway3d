@tool
extends RefCounted
## Chorraha (yumaloq burchakli) va aylana (roundabout) mesh'ini quradi.
## Rollar: deck = yo'l materiali, structure = bordyur, railing = orolcha.

const BridgeBuilder := preload("res://addons/live_river_road/bridge_builder.gd")
const PathMath := preload("res://addons/live_river_road/path_math.gd")

const JCOL := Color(0.0, 0.0, 0.0, 1.0)   # shaderda "chorraha rejimi" (R=0, G=0)


static func build(cl: Dictionary, uv_w: float) -> Dictionary:
	var out := BridgeBuilder.Out.new()
	if cl["ring"]:
		_ring(out, cl, uv_w)
	else:
		_patch(out, cl, uv_w)
	return out.finish()


static func _uv(p: Vector3, w: float) -> Vector2:
	return Vector2(p.x, p.z) / maxf(w, 0.5)


static func _flat(out, a: Vector3, b: Vector3, c: Vector3, w: float) -> void:
	out.add(BridgeBuilder.ROLE_DECK, a, b, c, Vector3.UP, Vector3.UP, Vector3.UP, _uv(a, w), _uv(b, w), _uv(c, w), JCOL)


static func _skirt(out, pts: Array, center: Vector3, depth: float, w: float) -> void:
	if depth < 0.01:
		return
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) * 0.5
		var n := Vector3(mid.x - center.x, 0.0, mid.z - center.z)
		if n.length_squared() < 0.0001:
			continue
		n = n.normalized()
		var a2 := a - Vector3(0, depth, 0)
		var b2 := b - Vector3(0, depth, 0)
		var ua := Vector2(a.x + a.z, a.y) / w
		var ub := Vector2(b.x + b.z, b.y) / w
		var ua2 := Vector2(a.x + a.z, a2.y) / w
		var ub2 := Vector2(b.x + b.z, b2.y) / w
		out.add(BridgeBuilder.ROLE_DECK, a, b, b2, n, n, n, ua, ub, ub2, JCOL)
		out.add(BridgeBuilder.ROLE_DECK, a, b2, a2, n, n, n, ua, ub2, ua2, JCOL)


# ---------------------------------------------------------------------------
#  Oddiy chorraha (yumaloq burchaklar bilan)
# ---------------------------------------------------------------------------
static func _patch(out, cl: Dictionary, w: float) -> void:
	var arms: Array = cl["arms"]
	var c: Vector3 = cl["center"]
	var st = cl["settings"]
	var n := arms.size()
	if n < 2:
		return
	var poly: Array = []
	var lines: Array = []
	for k in range(n):
		var a: Dictionary = arms[k]
		var b: Dictionary = arms[(k + 1) % n]
		poly.append(a["cw"])
		poly.append(a["ccw"])
		var conn := _connector(a, b, c, st, float(cl["R_cut"]))
		for q in range(1, conn.size() - 1):
			poly.append(conn[q])
		lines.append(conn)
	var m := poly.size()
	for i in range(m):
		_flat(out, c, poly[i], poly[(i + 1) % m], w)
	for conn in lines:
		_skirt(out, conn, c, float(st.skirt_depth), w)


static func _connector(a: Dictionary, b: Dictionary, c: Vector3, st, r_cut: float) -> Array:
	var y: float = (a["ccw"] as Vector3).y
	var g := fposmod(float(b["angle"]) - float(a["angle"]), TAU)
	var e1: Vector3 = a["ccw"]
	var e2: Vector3 = b["cw"]
	var p1 := Vector2(e1.x, e1.z)
	var p2 := Vector2(e2.x, e2.z)
	var d1 := Vector2(a["d_out"].x, a["d_out"].z).normalized()
	var d2 := Vector2(b["d_out"].x, b["d_out"].z).normalized()
	var cc := Vector2(c.x, c.z)

	if g > PI + 0.02:
		# Yo'nalishlar orasi 180° dan katta: markaz atrofida yumaloq yopilish
		var q1 := p1 + d1 * (cc - p1).dot(d1)
		var q2 := p2 + d2 * (cc - p2).dot(d2)
		var res: Array = [e1, Vector3(q1.x, y, q1.y)]
		var a1 := atan2(q1.y - cc.y, q1.x - cc.x)
		var a2 := atan2(q2.y - cc.y, q2.x - cc.x)
		var da := fposmod(a2 - a1, TAU)
		var r1 := (q1 - cc).length()
		var r2 := (q2 - cc).length()
		var steps := 8
		for s in range(1, steps):
			var f := float(s) / float(steps)
			var ang := a1 + da * f
			var rr := lerpf(r1, r2, f)
			res.append(Vector3(cc.x + cos(ang) * rr, y, cc.y + sin(ang) * rr))
		res.append(Vector3(q2.x, y, q2.y))
		res.append(e2)
		return res

	var r := PathMath.line_intersect_2d(p1, d1, p2, d2)
	if r.is_empty() or float(r[0]) > -0.05 or float(r[1]) > -0.05 or -float(r[0]) > 1.6 * r_cut or -float(r[1]) > 1.6 * r_cut:
		return [e1, e2]
	var X := p1 + d1 * float(r[0])
	var tl := minf(float(st.corner_radius), minf(-float(r[0]) - 0.05, -float(r[1]) - 0.05))
	if tl < 0.2:
		return [e1, Vector3(X.x, y, X.y), e2]
	var A := X + d1 * tl
	var B := X + d2 * tl
	var res2: Array = [e1, Vector3(A.x, y, A.y)]
	var segs := int(st.corner_segments)
	for s in range(1, segs):
		var f2 := float(s) / float(segs)
		var q := A * (1.0 - f2) * (1.0 - f2) + X * (2.0 * (1.0 - f2) * f2) + B * (f2 * f2)
		res2.append(Vector3(q.x, y, q.y))
	res2.append(Vector3(B.x, y, B.y))
	res2.append(e2)
	return res2


# ---------------------------------------------------------------------------
#  Aylana (roundabout)
# ---------------------------------------------------------------------------
static func _ring_pt(c: Vector3, ang: float, r: float, y: float) -> Vector3:
	return Vector3(c.x + cos(ang) * r, y, c.z + sin(ang) * r)


static func _ring(out, cl: Dictionary, w: float) -> void:
	var c: Vector3 = cl["center"]
	var y := c.y
	var st = cl["settings"]
	var R_i: float = cl["R_i"]
	var R_o: float = cl["R_o"]
	var M := int(st.ring_segments)

	# Halqa
	for i in range(M):
		var t0 := TAU * float(i) / float(M)
		var t1 := TAU * float(i + 1) / float(M)
		for j in range(2):
			var r0 := lerpf(R_i, R_o, float(j) / 2.0)
			var r1 := lerpf(R_i, R_o, float(j + 1) / 2.0)
			var a := _ring_pt(c, t0, r0, y)
			var b := _ring_pt(c, t1, r0, y)
			var d := _ring_pt(c, t0, r1, y)
			var e := _ring_pt(c, t1, r1, y)
			_flat(out, a, b, d, w)
			_flat(out, b, e, d, w)
	var outer: Array = []
	for i in range(M + 1):
		outer.append(_ring_pt(c, TAU * float(i) / float(M), R_o, y))
	_skirt(out, outer, c, float(st.skirt_depth), w)

	# Kirish yo'llari (kengayuvchi ulagichlar)
	var delta := float(st.flare) / maxf(R_o, 1.0)
	for a in cl["arms"]:
		var cw: Vector3 = a["cw"]
		var ccw: Vector3 = a["ccw"]
		var th_cw := atan2(cw.z - c.z, cw.x - c.x)
		var th_ccw := atan2(ccw.z - c.z, ccw.x - c.x)
		var lo := th_cw
		var span := fposmod(th_ccw - th_cw, TAU)
		if span > PI:
			lo = th_ccw
			span = fposmod(th_cw - th_ccw, TAU)
		var a0 := lo - delta
		var a1 := lo + span + delta
		var steps := maxi(4, int(ceil((a1 - a0) / 0.12)))
		var poly: Array = [cw, ccw]
		for s in range(steps + 1):
			var ang := lerpf(a1, a0, float(s) / float(steps))
			poly.append(_ring_pt(c, ang, R_o, y))
		var cen := Vector3.ZERO
		for p in poly:
			cen += p
		cen /= float(poly.size())
		for i in range(poly.size()):
			_flat(out, cen, poly[i], poly[(i + 1) % poly.size()], w)
		_skirt(out, [ccw, _ring_pt(c, a1, R_o, y)], c, float(st.skirt_depth), w)
		_skirt(out, [_ring_pt(c, a0, R_o, y), cw], c, float(st.skirt_depth), w)

	# O'rta orolcha
	var ch := maxf(float(st.island_curb_height), 0.02)
	var cwid := minf(float(st.curb_width), R_i * 0.4)
	var top_y := y + ch
	var R_t := R_i - cwid
	for i in range(M):
		var t0b := TAU * float(i) / float(M)
		var t1b := TAU * float(i + 1) / float(M)
		var nrm := Vector3(cos((t0b + t1b) * 0.5), 0.0, sin((t0b + t1b) * 0.5))
		# devor (bordyur yon tomoni)
		out.quad(BridgeBuilder.ROLE_STRUCT, _ring_pt(c, t0b, R_i, y), _ring_pt(c, t1b, R_i, y), _ring_pt(c, t1b, R_i, top_y), _ring_pt(c, t0b, R_i, top_y), -nrm)
		# bordyur usti
		out.quad(BridgeBuilder.ROLE_STRUCT, _ring_pt(c, t0b, R_t, top_y), _ring_pt(c, t1b, R_t, top_y), _ring_pt(c, t1b, R_i, top_y), _ring_pt(c, t0b, R_i, top_y), Vector3.UP)
		# orolcha yuzasi
		out.tri(BridgeBuilder.ROLE_RAIL, Vector3(c.x, top_y, c.z), _ring_pt(c, t0b, R_t, top_y), _ring_pt(c, t1b, R_t, top_y), Vector3.UP)
