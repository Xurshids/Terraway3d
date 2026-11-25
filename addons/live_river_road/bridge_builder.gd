@tool
extends RefCounted
## Ko'prik geometriyasini yaratuvchi statik yordamchi.
## Barcha hisob-kitob dunyo koordinatalarida bajariladi.
##
## span lug'ati (LiveRoad3D yaratadi):
##   "pts":    PackedVector3Array  - yo'l markaz chizig'i (Y = ko'prik usti balandligi)
##   "dists":  PackedFloat32Array  - yo'lning boshidan masofa (UV uchun)
##   "width":  float               - yo'l kengligi
##   "water_y": float              - suv sathi

const UV_SCALE := 0.5
const PLANK_THICKNESS := 0.08
const ROLE_DECK := &"deck"
const ROLE_STRUCT := &"structure"
const ROLE_RAIL := &"railing"
const ROLES: Array[StringName] = [&"deck", &"structure", &"railing"]

const STYLE_COLORS := {
	0: [Color(0.62, 0.62, 0.60), Color(0.34, 0.36, 0.40)],  # SLAB: beton, po'lat
	1: [Color(0.56, 0.51, 0.44), Color(0.56, 0.51, 0.44)],  # STONE_ARCH
	2: [Color(0.56, 0.51, 0.44), Color(0.56, 0.51, 0.44)],  # HUMPBACK
	3: [Color(0.46, 0.30, 0.17), Color(0.40, 0.26, 0.15)],  # WOODEN
	4: [Color(0.42, 0.47, 0.52), Color(0.30, 0.33, 0.36)],  # TRUSS
	5: [Color(0.62, 0.62, 0.60), Color(0.24, 0.26, 0.30)],  # SUSPENSION
}


# ---------------------------------------------------------------------------
#  Yo'nalish ramkasi (yo'l markaz chizig'i bo'ylab)
# ---------------------------------------------------------------------------
class Frames:
	var pts := PackedVector3Array()
	var s := PackedFloat32Array()
	var dir := PackedVector3Array()
	var side := PackedVector3Array()
	var length := 0.0

	func setup(points: PackedVector3Array) -> void:
		pts = points
		s.clear()
		dir.clear()
		side.clear()
		var acc := 0.0
		for i in range(pts.size()):
			if i > 0:
				acc += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
			s.append(acc)
		length = acc
		var last := Vector3.FORWARD
		for i in range(pts.size()):
			var a := pts[maxi(i - 1, 0)]
			var b := pts[mini(i + 1, pts.size() - 1)]
			var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
			if d.length_squared() < 0.000001:
				d = last
			d = d.normalized()
			last = d
			dir.append(d)
			side.append(Vector3(-d.z, 0.0, d.x))

	func _find(sv: float) -> int:
		var lo := 0
		var hi := s.size() - 2
		while lo < hi:
			var mid := (lo + hi + 1) >> 1
			if s[mid] <= sv:
				lo = mid
			else:
				hi = mid - 1
		return lo

	func _frac(i: int, sv: float) -> float:
		var d := s[i + 1] - s[i]
		if d < 0.000001:
			return 0.0
		return clampf((sv - s[i]) / d, 0.0, 1.0)

	func pos(sv: float) -> Vector3:
		if sv <= 0.0:
			return pts[0] + dir[0] * sv
		if sv >= length:
			return pts[pts.size() - 1] + dir[dir.size() - 1] * (sv - length)
		var i := _find(sv)
		return pts[i].lerp(pts[i + 1], _frac(i, sv))

	func dirv(sv: float) -> Vector3:
		if sv <= 0.0:
			return dir[0]
		if sv >= length:
			return dir[dir.size() - 1]
		var i := _find(sv)
		return dir[i].lerp(dir[i + 1], _frac(i, sv)).normalized()

	func sidev(sv: float) -> Vector3:
		var d := dirv(sv)
		return Vector3(-d.z, 0.0, d.x)

	## Yo'l chizig'iga nisbatan: x = yon, y = balandlik (ko'prik usti sathidan).
	func at(sv: float, x: float, y: float) -> Vector3:
		return pos(sv) + sidev(sv) * x + Vector3(0.0, y, 0.0)

	## Mutlaq Y bilan.
	func at_abs(sv: float, x: float, y_abs: float) -> Vector3:
		var q := pos(sv) + sidev(sv) * x
		q.y = y_abs
		return q


# ---------------------------------------------------------------------------
#  Mesh chiqaruvchi (roli bo'yicha SurfaceTool)
# ---------------------------------------------------------------------------
class Out:
	var tools: Dictionary = {}
	var counts: Dictionary = {}

	func _tool(role: StringName) -> SurfaceTool:
		if not tools.has(role):
			var t := SurfaceTool.new()
			t.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[role] = t
			counts[role] = 0
		return tools[role]

	static func uv_world(p: Vector3, n: Vector3) -> Vector2:
		var an := n.abs()
		if an.y >= an.x and an.y >= an.z:
			return Vector2(p.x, p.z) * 0.5
		if an.x >= an.z:
			return Vector2(p.z, -p.y) * 0.5
		return Vector2(p.x, -p.y) * 0.5

	func add(role: StringName, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, col: Color = Color.WHITE) -> void:
		var gn := (c - a).cross(b - a)
		if gn.length_squared() < 0.0000000001:
			return
		if gn.dot(na + nb + nc) < 0.0:
			var tv := b
			b = c
			c = tv
			var tn := nb
			nb = nc
			nc = tn
			var tu := uvb
			uvb = uvc
			uvc = tu
		var t := _tool(role)
		t.set_color(col)
		t.set_normal(na)
		t.set_uv(uva)
		t.add_vertex(a)
		t.set_color(col)
		t.set_normal(nb)
		t.set_uv(uvb)
		t.add_vertex(b)
		t.set_color(col)
		t.set_normal(nc)
		t.set_uv(uvc)
		t.add_vertex(c)
		counts[role] += 1

	func tri(role: StringName, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
		add(role, a, b, c, n, n, n, uv_world(a, n), uv_world(b, n), uv_world(c, n))

	func quad(role: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
		tri(role, a, b, c, n)
		tri(role, a, c, d, n)

	func quad_s(role: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
		var n := (na + nb + nc + nd).normalized()
		add(role, a, b, c, na, nb, nc, uv_world(a, n), uv_world(b, n), uv_world(c, n))
		add(role, a, c, d, na, nc, nd, uv_world(a, n), uv_world(c, n), uv_world(d, n))

	func box(role: StringName, c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, hx: float, hy: float, hz: float) -> void:
		var X := ax * hx
		var Y := ay * hy
		var Z := az * hz
		quad(role, c + X - Y - Z, c + X + Y - Z, c + X + Y + Z, c + X - Y + Z, ax)
		quad(role, c - X - Y - Z, c - X + Y - Z, c - X + Y + Z, c - X - Y + Z, -ax)
		quad(role, c - X + Y - Z, c + X + Y - Z, c + X + Y + Z, c - X + Y + Z, ay)
		quad(role, c - X - Y - Z, c + X - Y - Z, c + X - Y + Z, c - X - Y + Z, -ay)
		quad(role, c - X - Y + Z, c + X - Y + Z, c + X + Y + Z, c - X + Y + Z, az)
		quad(role, c - X - Y - Z, c + X - Y - Z, c + X + Y - Z, c - X + Y - Z, -az)

	## a dan b gacha to'sin. lat - kesimning bir o'qi yo'nalishi.
	func beam(role: StringName, a: Vector3, b: Vector3, lat: Vector3, t1: float, t2: float) -> void:
		var axis := b - a
		var l := axis.length()
		if l < 0.0001:
			return
		axis /= l
		var r := lat - axis * lat.dot(axis)
		if r.length_squared() < 0.0001:
			r = Vector3.UP - axis * Vector3.UP.dot(axis)
		r = r.normalized()
		var u := axis.cross(r).normalized()
		box(role, (a + b) * 0.5, r, u, axis, t1 * 0.5, t2 * 0.5, l * 0.5)

	func cylinder(role: StringName, p0: Vector3, p1: Vector3, r: float, sides: int = 8, caps: bool = true) -> void:
		var axis := p1 - p0
		var l := axis.length()
		if l < 0.0001:
			return
		axis /= l
		var helper := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
		var u := axis.cross(helper).normalized()
		var v := axis.cross(u).normalized()
		for i in range(sides):
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var n0 := u * cos(a0) + v * sin(a0)
			var n1 := u * cos(a1) + v * sin(a1)
			quad_s(role, p0 + n0 * r, p0 + n1 * r, p1 + n1 * r, p1 + n0 * r, n0, n1, n1, n0)
			if caps:
				tri(role, p1, p1 + n0 * r, p1 + n1 * r, axis)
				tri(role, p0, p0 + n0 * r, p0 + n1 * r, -axis)

	## Vertikal prizma. fp = [Vector2(a: yo'l bo'ylab, b: yon)] konveks ko'pburchak.
	func prism(role: StringName, origin: Vector3, d: Vector3, sd: Vector3, fp: Array, y0: float, y1: float) -> void:
		var n := fp.size()
		if n < 3:
			return
		var area := 0.0
		for i in range(n):
			var p: Vector2 = fp[i]
			var q: Vector2 = fp[(i + 1) % n]
			area += p.x * q.y - q.x * p.y
		var sgn := 1.0 if area > 0.0 else -1.0
		var top: Array = []
		var bot: Array = []
		for p in fp:
			var w: Vector3 = origin + d * p.x + sd * p.y
			top.append(Vector3(w.x, y1, w.z))
			bot.append(Vector3(w.x, y0, w.z))
		for i in range(n):
			var j := (i + 1) % n
			var e: Vector2 = (fp[j] as Vector2) - (fp[i] as Vector2)
			var n2 := Vector2(e.y, -e.x).normalized() * sgn
			var wn := d * n2.x + sd * n2.y
			quad(role, bot[i], bot[j], top[j], top[i], wn)
		for i in range(1, n - 1):
			tri(role, top[0], top[i], top[i + 1], Vector3.UP)
			tri(role, bot[0], bot[i], bot[i + 1], Vector3.DOWN)

	## Profil (yon x, balandlik y) ni s0..s1 oralig'ida yo'l bo'ylab sudraydi. Konveks profil.
	func sweep(role: StringName, F: Frames, s0: float, s1: float, step: float, profile: Array, caps: bool = true) -> void:
		var pn := profile.size()
		if pn < 3 or s1 - s0 < 0.001:
			return
		var area := 0.0
		for i in range(pn):
			var p: Vector2 = profile[i]
			var q: Vector2 = profile[(i + 1) % pn]
			area += p.x * q.y - q.x * p.y
		var sgn := 1.0 if area > 0.0 else -1.0
		var n := maxi(1, int(ceil((s1 - s0) / maxf(step, 0.05))))
		for k in range(n):
			var sa := lerpf(s0, s1, float(k) / float(n))
			var sb := lerpf(s0, s1, float(k + 1) / float(n))
			var sm := (sa + sb) * 0.5
			var sdv := F.sidev(sm)
			for e in range(pn):
				var p0: Vector2 = profile[e]
				var p1: Vector2 = profile[(e + 1) % pn]
				var ed := p1 - p0
				var n2 := Vector2(ed.y, -ed.x).normalized() * sgn
				var wn := sdv * n2.x + Vector3.UP * n2.y
				quad(role, F.at(sa, p0.x, p0.y), F.at(sa, p1.x, p1.y), F.at(sb, p1.x, p1.y), F.at(sb, p0.x, p0.y), wn)
		if caps:
			for end in [0, 1]:
				var sv := s0 if end == 0 else s1
				var dn := F.dirv(sv) * (-1.0 if end == 0 else 1.0)
				for i in range(1, pn - 1):
					tri(role, F.at(sv, (profile[0] as Vector2).x, (profile[0] as Vector2).y), F.at(sv, (profile[i] as Vector2).x, (profile[i] as Vector2).y), F.at(sv, (profile[i + 1] as Vector2).x, (profile[i + 1] as Vector2).y), dn)

	func finish() -> Dictionary:
		var mesh := ArrayMesh.new()
		var roles: Array[StringName] = []
		for role in ROLES:
			if not tools.has(role) or int(counts[role]) == 0:
				continue
			var t: SurfaceTool = tools[role]
			t.generate_tangents()
			t.commit(mesh)
			roles.append(role)
		return {"mesh": mesh, "roles": roles}


static func _rect(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]


# ---------------------------------------------------------------------------
#  Profil hisob-kitoblari (LiveRoad3D shu funksiyalardan foydalanadi)
# ---------------------------------------------------------------------------
static func is_arch_style(st: LiveBridgeSettings) -> bool:
	return st.style == LiveBridgeSettings.Style.STONE_ARCH or st.style == LiveBridgeSettings.Style.HUMPBACK


static func arch_layout(st: LiveBridgeSettings, length: float) -> Dictionary:
	var a_w: float = st.abutment_width if st.abutment_enabled else 0.0
	var pw: float = st.pier_width
	var n := 1
	if st.style != LiveBridgeSettings.Style.HUMPBACK:
		if st.arch_count > 0:
			n = st.arch_count
		else:
			n = maxi(1, int(ceil((length - 2.0 * a_w) / maxf(st.arch_max_span, 1.0))))
	var span := 0.0
	while true:
		span = (length - 2.0 * a_w - float(n - 1) * pw) / float(n)
		if span >= 2.0 or n <= 1:
			break
		n -= 1
	if span < 1.0:
		a_w = 0.0
		n = 1
		span = length
	return {"n": n, "span": span, "a_w": a_w, "pw": pw}


static func required_level(st: LiveBridgeSettings, length: float, water_y: float) -> float:
	var T: float = st.deck_thickness
	if is_arch_style(st) and not st.is_custom():
		var lay := arch_layout(st, length)
		var r_min: float = st.arch_rise_ratio * float(lay["span"])
		return water_y + st.min_clearance + r_min + st.arch_thickness + st.arch_fill + T
	return water_y + st.min_clearance + T


## Ko'prik uchun zarur bo'lgan ko'tarilish (lift) miqdori.
static func compute_lift(st: LiveBridgeSettings, ya: float, yb: float, length: float, water_y: float) -> float:
	var req := required_level(st, length, water_y)
	var worst := INF
	for i in range(8):
		var u := 0.15 + 0.7 * float(i) / 7.0
		var v := lerpf(ya, yb, u) + st.deck_camber * 4.0 * u * (1.0 - u)
		worst = minf(worst, v)
	return maxf(0.0, req - worst)


static func deck_level(st: LiveBridgeSettings, ya: float, yb: float, u: float, lift: float) -> float:
	return lerpf(ya, yb, u) + lift + st.deck_camber * 4.0 * u * (1.0 - u)


# ---------------------------------------------------------------------------
#  Materiallar
# ---------------------------------------------------------------------------
static func make_materials(st: LiveBridgeSettings, road_material: Material) -> Dictionary:
	var mats := {}
	mats[ROLE_DECK] = st.deck_material if st.deck_material != null else road_material
	var cols: Array = STYLE_COLORS.get(int(st.style), STYLE_COLORS[0])
	# Konstruksiya
	if st.structure_material != null:
		mats[ROLE_STRUCT] = st.structure_material
	else:
		var m := StandardMaterial3D.new()
		var base: Color = cols[0] if st.use_style_colors else Color.WHITE
		base *= st.structure_tint
		if st.structure_texture_set != null:
			st.structure_texture_set.apply_to_standard(m, base)
		else:
			m.albedo_color = base
			m.roughness = st.structure_roughness
		mats[ROLE_STRUCT] = m
	# Panjara / metall qismlar
	if st.railing_material != null:
		mats[ROLE_RAIL] = st.railing_material
	else:
		var m2 := StandardMaterial3D.new()
		var base2: Color = cols[1] if st.use_style_colors else Color.WHITE
		base2 *= st.railing_tint
		if st.railing_texture_set != null:
			st.railing_texture_set.apply_to_standard(m2, base2)
		else:
			m2.albedo_color = base2
			m2.roughness = 0.6
			m2.metallic = st.railing_metallic
		mats[ROLE_RAIL] = m2
	return mats


# ---------------------------------------------------------------------------
#  Asosiy yaratish funksiyasi
# ---------------------------------------------------------------------------
static func build(span: Dictionary, st: LiveBridgeSettings, ground_fn: Callable) -> Dictionary:
	var F := Frames.new()
	F.setup(span["pts"])
	var out := Out.new()
	if F.pts.size() < 2 or F.length < 0.5:
		return out.finish()

	var Wr: float = span["width"]
	var Wt: float = Wr + 2.0 * st.width_extra
	var T: float = st.deck_thickness
	var water_y: float = span["water_y"]

	if st.is_custom():
		if st.custom_keep_road_surface:
			_deck_surface(out, F, span, Wr)
		return out.finish()

	if st.deck_surface == LiveBridgeSettings.DeckSurface.ROAD:
		_deck_surface(out, F, span, Wr)
	else:
		_deck_planks(out, F, st, Wr)

	_deck_body(out, F, st, Wr, Wt, T)

	match st.style:
		LiveBridgeSettings.Style.STONE_ARCH, LiveBridgeSettings.Style.HUMPBACK:
			_arches(out, F, st, Wt, T, water_y, ground_fn)
		LiveBridgeSettings.Style.TRUSS:
			_beam_supports(out, F, st, Wt, T, water_y, ground_fn)
			_truss(out, F, st, Wt, T)
		LiveBridgeSettings.Style.SUSPENSION:
			_beam_supports(out, F, st, Wt, T, water_y, ground_fn)
			_suspension(out, F, st, Wt, T, ground_fn)
		_:
			_beam_supports(out, F, st, Wt, T, water_y, ground_fn)
	_railings(out, F, st, Wr, Wt)
	return out.finish()


# ---------------------------------------------------------------------------
#  Ko'prik usti
# ---------------------------------------------------------------------------
static func _deck_surface(out: Out, F: Frames, span: Dictionary, Wr: float) -> void:
	var dists: PackedFloat32Array = span["dists"]
	var segs := 4
	var col := Color(0.0, 1.0, 1.0, 1.0)  # R=0: shaderda chet xiralashuvi o'chiriladi
	for i in range(F.pts.size() - 1):
		var d0 := dists[i] / maxf(Wr, 0.5)
		var d1 := dists[i + 1] / maxf(Wr, 0.5)
		for c in range(segs):
			var t0 := float(c) / float(segs)
			var t1 := float(c + 1) / float(segs)
			var x0 := (t0 - 0.5) * Wr
			var x1 := (t1 - 0.5) * Wr
			var a := F.pts[i] + F.side[i] * x0
			var b := F.pts[i] + F.side[i] * x1
			var c2 := F.pts[i + 1] + F.side[i + 1] * x0
			var d := F.pts[i + 1] + F.side[i + 1] * x1
			var n := Vector3.UP
			out.add(ROLE_DECK, a, c2, b, n, n, n, Vector2(d0, t0), Vector2(d1, t0), Vector2(d0, t1), col)
			out.add(ROLE_DECK, b, c2, d, n, n, n, Vector2(d0, t1), Vector2(d1, t0), Vector2(d1, t1), col)


static func _deck_planks(out: Out, F: Frames, st: LiveBridgeSettings, Wr: float) -> void:
	var L := F.length
	var pitch := maxf(st.plank_length + st.plank_gap, 0.1)
	var count := maxi(1, int(floor(L / pitch)))
	var cell := L / float(count)
	var plen := maxf(cell - st.plank_gap, 0.05)
	for k in range(count):
		var sv := (float(k) + 0.5) * cell
		var fwd := (F.pos(sv + 0.1) - F.pos(sv - 0.1)).normalized()
		var right := F.sidev(sv)
		var up := right.cross(fwd).normalized()
		var c := F.pos(sv) - up * (PLANK_THICKNESS * 0.5)
		out.box(ROLE_STRUCT, c, right, up, fwd, Wr * 0.5 + 0.02, PLANK_THICKNESS * 0.5, plen * 0.5)


static func _deck_body(out: Out, F: Frames, st: LiveBridgeSettings, Wr: float, Wt: float, T: float) -> void:
	var L := F.length
	var step := 0.75
	var top_y := -0.02 if st.deck_surface == LiveBridgeSettings.DeckSurface.ROAD else -(PLANK_THICKNESS + 0.01)
	var wooden_stringers: bool = st.style == LiveBridgeSettings.Style.WOODEN and st.wood_stringers
	if wooden_stringers:
		var n := maxi(2, int(round(Wt / 1.1)))
		for i in range(n):
			var x := lerpf(-Wt * 0.5 + 0.2, Wt * 0.5 - 0.2, float(i) / float(n - 1))
			out.sweep(ROLE_STRUCT, F, 0.0, L, step, _rect(x - 0.14, -T - 0.1, x + 0.14, top_y))
	else:
		out.sweep(ROLE_STRUCT, F, 0.0, L, step, _rect(-Wt * 0.5, -T, Wt * 0.5, top_y))
	# Yon bordyurlar
	var extra := (Wt - Wr) * 0.5
	if extra > 0.05 and st.curb_height > 0.001:
		out.sweep(ROLE_STRUCT, F, 0.0, L, step, _rect(Wr * 0.5, top_y - 0.02, Wt * 0.5, st.curb_height))
		out.sweep(ROLE_STRUCT, F, 0.0, L, step, _rect(-Wt * 0.5, top_y - 0.02, -Wr * 0.5, st.curb_height))


static func _curb_top(st: LiveBridgeSettings, Wr: float, Wt: float) -> float:
	if (Wt - Wr) * 0.5 > 0.05 and st.curb_height > 0.001:
		return st.curb_height
	return 0.0


# ---------------------------------------------------------------------------
#  Yer balandligi yordamchisi
# ---------------------------------------------------------------------------
static func _ground(F: Frames, ground_fn: Callable, sv: float, x: float, fallback: float) -> float:
	if ground_fn.is_valid():
		var p := F.at_abs(sv, x, 0.0)
		var g = ground_fn.call(p)
		if typeof(g) == TYPE_FLOAT and is_finite(g):
			return g
	return fallback


static func _min_ground(F: Frames, ground_fn: Callable, sv: float, hw: float, fallback: float) -> float:
	var g := INF
	for x in [-hw, 0.0, hw]:
		g = minf(g, _ground(F, ground_fn, sv, x, fallback))
	return g


# ---------------------------------------------------------------------------
#  Plita / yog'och / ferma / osma ko'priklar tayanchlari
# ---------------------------------------------------------------------------
static func _pier_count(st: LiveBridgeSettings, L: float) -> int:
	if st.pier_count >= 0:
		return st.pier_count
	if st.style == LiveBridgeSettings.Style.SUSPENSION:
		return 0
	return maxi(0, int(ceil(L / maxf(st.max_unsupported, 1.0))) - 1)


static func _beam_supports(out: Out, F: Frames, st: LiveBridgeSettings, Wt: float, T: float, water_y: float, ground_fn: Callable) -> void:
	var L := F.length
	var hw := Wt * 0.5 - 0.15
	var fallback := water_y - 3.0
	# Abutmentlar (ko'prik boshi va oxiri)
	if st.abutment_enabled and st.style != LiveBridgeSettings.Style.WOODEN:
		var aw: float = st.abutment_width
		for end in [0, 1]:
			var sc := aw * 0.5 if end == 0 else L - aw * 0.5
			var top_y := F.pos(sc).y - T + 0.03
			var g := _min_ground(F, ground_fn, sc, hw, fallback)
			var base_y := minf(g - st.pier_embed, top_y - 0.6)
			out.box(ROLE_STRUCT, F.at_abs(sc, 0.0, (top_y + base_y) * 0.5), F.sidev(sc), Vector3.UP, F.dirv(sc), Wt * 0.5, (top_y - base_y) * 0.5, aw * 0.5)
	var n := _pier_count(st, L)
	for k in range(1, n + 1):
		var sc := L * float(k) / float(n + 1)
		_pier(out, F, st, sc, Wt, T, hw, fallback, ground_fn)


static func _pier(out: Out, F: Frames, st: LiveBridgeSettings, sc: float, Wt: float, T: float, hw: float, fallback: float, ground_fn: Callable) -> void:
	var pw: float = st.pier_width
	var origin := F.pos(sc)
	var d := F.dirv(sc)
	var sd := F.sidev(sc)
	var deck_bottom := origin.y - T
	var g_all := _min_ground(F, ground_fn, sc, hw, fallback)
	match st.pier_shape:
		LiveBridgeSettings.PierShape.WALL:
			var fp: Array = [Vector2(-pw * 0.5, -hw), Vector2(pw * 0.5, -hw), Vector2(pw * 0.5, hw), Vector2(-pw * 0.5, hw)]
			var base_y := minf(g_all - st.pier_embed, deck_bottom - 0.6)
			out.prism(ROLE_STRUCT, origin, d, sd, fp, base_y, deck_bottom + 0.03)
		LiveBridgeSettings.PierShape.WALL_ROUNDED:
			var r := pw * 0.5
			var fp2: Array = []
			var cb := maxf(hw - r, 0.01)
			for i in range(7):
				var th := PI * float(i) / 6.0
				fp2.append(Vector2(r * cos(th), cb + r * sin(th)))
			for i in range(7):
				var th2 := PI + PI * float(i) / 6.0
				fp2.append(Vector2(r * cos(th2), -cb + r * sin(th2)))
			var base_y2 := minf(g_all - st.pier_embed, deck_bottom - 0.6)
			out.prism(ROLE_STRUCT, origin, d, sd, fp2, base_y2, deck_bottom + 0.03)
		_:
			var cap_h := 0.35
			var ncol := maxi(2, int(round(Wt / 3.0)))
			var cols_x: Array = []
			var col_pos: Array = []
			for j in range(ncol):
				var x := lerpf(-hw + pw * 0.5 + 0.1, hw - pw * 0.5 - 0.1, float(j) / float(ncol - 1))
				cols_x.append(x)
				col_pos.append(F.at_abs(sc, x, 0.0))
			# Ustunlar
			for j in range(ncol):
				var cp: Vector3 = col_pos[j]
				var gy := _ground(F, ground_fn, sc, cols_x[j], fallback)
				var by := minf(gy - st.pier_embed, deck_bottom - cap_h - 0.5)
				var top := deck_bottom - cap_h + 0.03
				if st.pier_shape == LiveBridgeSettings.PierShape.COLUMNS_ROUND:
					out.cylinder(ROLE_STRUCT, Vector3(cp.x, by, cp.z), Vector3(cp.x, top, cp.z), pw * 0.5, 10, false)
				else:
					var fpc: Array = [Vector2(-pw * 0.5, -pw * 0.5), Vector2(pw * 0.5, -pw * 0.5), Vector2(pw * 0.5, pw * 0.5), Vector2(-pw * 0.5, pw * 0.5)]
					out.prism(ROLE_STRUCT, Vector3(cp.x, 0.0, cp.z), d, sd, fpc, by, top)
			# Qalpoq to'sin
			out.box(ROLE_STRUCT, F.at_abs(sc, 0.0, deck_bottom - cap_h * 0.5), sd, Vector3.UP, d, Wt * 0.5 - 0.05, cap_h * 0.5, maxf(pw * 0.8, 0.35))
			# Yog'och mustahkamlagichlar
			if st.style == LiveBridgeSettings.Style.WOODEN and st.wood_bracing:
				for j in range(ncol - 1):
					var gy2 := _ground(F, ground_fn, sc, cols_x[j], fallback)
					var low := minf(gy2, deck_bottom - 2.5) + 0.4
					var high := deck_bottom - cap_h - 0.2
					if high - low < 0.6:
						continue
					var xa: float = cols_x[j]
					var xb: float = cols_x[j + 1]
					out.beam(ROLE_STRUCT, F.at_abs(sc, xa, low), F.at_abs(sc, xb, high), d, 0.12, 0.12)
					out.beam(ROLE_STRUCT, F.at_abs(sc, xb, low), F.at_abs(sc, xa, high), d, 0.12, 0.12)


# ---------------------------------------------------------------------------
#  Arkali ko'priklar (tosh arka / bukri)
# ---------------------------------------------------------------------------
static func _arches(out: Out, F: Frames, st: LiveBridgeSettings, Wt: float, T: float, water_y: float, ground_fn: Callable) -> void:
	var L := F.length
	var lay := arch_layout(st, L)
	var N: int = lay["n"]
	var span: float = lay["span"]
	var a_w: float = lay["a_w"]
	var pw: float = lay["pw"]
	var hw := Wt * 0.5
	var y_sp0 := water_y + st.min_clearance
	var fallback := water_y - 3.0
	var segs: int = st.arch_segments

	for k in range(N):
		var s0 := a_w + float(k) * (span + pw)
		var s1 := s0 + span
		var sm := (s0 + s1) * 0.5
		var deck_mid := F.pos(sm).y
		var intr_crown := deck_mid - T - st.arch_fill - st.arch_thickness
		var room := intr_crown - y_sp0
		var r := clampf(room, span * 0.1, span * 0.5)
		var ysp := intr_crown - r
		var R := (span * span * 0.25 + r * r) / (2.0 * r)
		var cy := ysp + r - R
		var alpha := asin(clampf(span / (2.0 * R), 0.0, 1.0))
		var lo_s := PackedFloat32Array()
		var lo_y := PackedFloat32Array()
		for j in range(segs + 1):
			var th := lerpf(-alpha, alpha, float(j) / float(segs))
			lo_s.append(sm + R * sin(th))
			lo_y.append(cy + R * cos(th))
		# Intrados (arka ostki yuzasi) - silliq
		for j in range(segs):
			var n0 := _arch_normal(F, lo_s[j], lo_y[j], sm, cy, R)
			var n1 := _arch_normal(F, lo_s[j + 1], lo_y[j + 1], sm, cy, R)
			out.quad_s(ROLE_STRUCT, F.at_abs(lo_s[j], -hw, lo_y[j]), F.at_abs(lo_s[j], hw, lo_y[j]), F.at_abs(lo_s[j + 1], hw, lo_y[j + 1]), F.at_abs(lo_s[j + 1], -hw, lo_y[j + 1]), n0, n0, n1, n1)
		# Fasad (arka bilan ko'prik usti orasidagi devor)
		for sgn in [-1.0, 1.0]:
			for j in range(segs):
				var hi0 := F.pos(lo_s[j]).y - T
				var hi1 := F.pos(lo_s[j + 1]).y - T
				var wn: Vector3 = F.sidev((lo_s[j] + lo_s[j + 1]) * 0.5) * sgn
				out.quad(ROLE_STRUCT, F.at_abs(lo_s[j], sgn * hw, lo_y[j]), F.at_abs(lo_s[j + 1], sgn * hw, lo_y[j + 1]), F.at_abs(lo_s[j + 1], sgn * hw, hi1), F.at_abs(lo_s[j], sgn * hw, hi0), wn)

	# Tayanchlar: abutmentlar va oraliq ustunlar (to'liq kenglikdagi bloklar)
	var blocks: Array = []
	if a_w > 0.01:
		blocks.append([0.0, a_w])
		blocks.append([L - a_w, L])
	for k in range(N - 1):
		var ps := a_w + float(k + 1) * span + float(k) * pw
		blocks.append([ps, ps + pw])
	for b in blocks:
		var sa: float = b[0]
		var sb: float = b[1]
		var sc := (sa + sb) * 0.5
		var top_y := maxf(F.pos(sa).y, F.pos(sb).y) - T + 0.03
		var g := _min_ground(F, ground_fn, sc, hw - 0.2, fallback)
		var base_y := minf(g - st.pier_embed, top_y - 0.6)
		out.box(ROLE_STRUCT, F.at_abs(sc, 0.0, (top_y + base_y) * 0.5), F.sidev(sc), Vector3.UP, F.dirv(sc), hw, (top_y - base_y) * 0.5, (sb - sa) * 0.5)


static func _arch_normal(F: Frames, s_j: float, y_j: float, cs: float, cy: float, R: float) -> Vector3:
	var n2 := Vector2(cs - s_j, cy - y_j) / maxf(R, 0.001)
	return (F.dirv(s_j) * n2.x + Vector3.UP * n2.y).normalized()


# ---------------------------------------------------------------------------
#  Ferma (Warren truss)
# ---------------------------------------------------------------------------
static func _truss(out: Out, F: Frames, st: LiveBridgeSettings, Wt: float, T: float) -> void:
	var L := F.length
	var m: float = st.truss_member_size
	var H: float = st.truss_height
	var P: int = st.truss_panels if st.truss_panels > 0 else maxi(2, int(round(L / maxf(H * 0.9, 1.0))))
	var pw := L / float(P)
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * (Wt * 0.5 - m * 0.5)
		var lat := F.sidev(L * 0.5)
		for k in range(P):
			var b0 := F.at(float(k) * pw, x, m * 0.5)
			var b1 := F.at(float(k + 1) * pw, x, m * 0.5)
			var tk := F.at((float(k) + 0.5) * pw, x, H - m * 0.5)
			out.beam(ROLE_STRUCT, b0, b1, lat, m, m)                      # pastki belbog'
			out.beam(ROLE_STRUCT, b0, tk, lat, m * 0.8, m * 0.8)          # diagonal yuqoriga
			out.beam(ROLE_STRUCT, tk, b1, lat, m * 0.8, m * 0.8)          # diagonal pastga
			out.beam(ROLE_STRUCT, tk, F.at((float(k) + 0.5) * pw, x, m * 0.5), lat, m * 0.7, m * 0.7)  # vertikal
			if k < P - 1:
				out.beam(ROLE_STRUCT, tk, F.at((float(k) + 1.5) * pw, x, H - m * 0.5), lat, m, m)      # yuqori belbog'
	# Yuqori ko'ndalang bog'lovchilar va pol to'sinlari
	for k in range(P):
		var sv := (float(k) + 0.5) * pw
		if st.truss_top_bracing:
			out.beam(ROLE_STRUCT, F.at(sv, -Wt * 0.5 + m * 0.5, H - m * 0.5), F.at(sv, Wt * 0.5 - m * 0.5, H - m * 0.5), F.dirv(sv), m * 0.7, m * 0.7)
	for k in range(P + 1):
		var sv2 := float(k) * pw
		out.beam(ROLE_STRUCT, F.at(sv2, -Wt * 0.5, -T - 0.12), F.at(sv2, Wt * 0.5, -T - 0.12), F.dirv(sv2), 0.22, 0.25)


# ---------------------------------------------------------------------------
#  Osma ko'prik
# ---------------------------------------------------------------------------
static func _suspension(out: Out, F: Frames, st: LiveBridgeSettings, Wt: float, T: float, ground_fn: Callable) -> void:
	var L := F.length
	var ts: float = st.tower_size
	var Ht: float = st.tower_height
	var xc := Wt * 0.5 + 0.05
	var s_t0 := minf(ts, L * 0.15)
	var s_t1 := L - s_t0
	var y_end0 := F.pos(0.0).y
	var y_end1 := F.pos(L).y
	var fallback := minf(y_end0, y_end1) - 3.0
	# Minoralar
	for sv in [s_t0, s_t1]:
		var sd := F.sidev(sv)
		var d := F.dirv(sv)
		var deck_y := F.pos(sv).y
		for sgn in [-1.0, 1.0]:
			var g := _ground(F, ground_fn, sv, sgn * xc, fallback)
			var base_y := minf(g - st.pier_embed, deck_y - 1.0)
			var c := F.at_abs(sv, sgn * xc, (base_y + deck_y + Ht) * 0.5)
			out.box(ROLE_STRUCT, c, sd, Vector3.UP, d, ts * 0.5, (deck_y + Ht - base_y) * 0.5, ts * 0.5)
		# Ko'ndalang to'sinlar
		out.box(ROLE_STRUCT, F.at_abs(sv, 0.0, deck_y + Ht - ts * 0.6), sd, Vector3.UP, d, xc, ts * 0.5, ts * 0.4)
		out.box(ROLE_STRUCT, F.at_abs(sv, 0.0, deck_y + Ht * 0.62), sd, Vector3.UP, d, xc, ts * 0.35, ts * 0.3)
	# Arqonlar
	var top0 := F.pos(s_t0).y + Ht - ts * 0.3
	var top1 := F.pos(s_t1).y + Ht - ts * 0.3
	var cable_r: float = st.cable_thickness * 0.5
	var nseg := 28
	var mid_s := (s_t0 + s_t1) * 0.5
	var half := (s_t1 - s_t0) * 0.5
	for sgn in [-1.0, 1.0]:
		var xs: float = sgn * xc
		var prev := Vector3.ZERO
		var hangers: Array = []
		for j in range(nseg + 1):
			var sv2 := lerpf(s_t0, s_t1, float(j) / float(nseg))
			var u := (sv2 - mid_s) / maxf(half, 0.01)
			var ytop := lerpf(top0, top1, (sv2 - s_t0) / maxf(s_t1 - s_t0, 0.01))
			var y := ytop - st.cable_sag * (1.0 - u * u)
			var p := F.at_abs(sv2, xs, y)
			if j > 0:
				out.cylinder(ROLE_RAIL, prev, p, cable_r, 6, false)
			prev = p
		# Osma simlar
		var hs := maxf(st.hanger_spacing, 0.5)
		var nh := int(floor((s_t1 - s_t0) / hs))
		for h in range(1, nh):
			var shv := s_t0 + float(h) * hs
			var u2 := (shv - mid_s) / maxf(half, 0.01)
			var ytop2 := lerpf(top0, top1, (shv - s_t0) / maxf(s_t1 - s_t0, 0.01))
			var yc := ytop2 - st.cable_sag * (1.0 - u2 * u2)
			var ydeck := F.pos(shv).y + 0.1
			if yc - ydeck > 0.3:
				out.cylinder(ROLE_RAIL, F.at_abs(shv, xs, ydeck), F.at_abs(shv, xs, yc), maxf(cable_r * 0.4, 0.015), 5, false)
		# Orqa tortuvchi arqonlar
		for end in [0, 1]:
			var s_tower := s_t0 if end == 0 else s_t1
			var s_anchor := s_tower - st.anchor_length if end == 0 else s_tower + st.anchor_length
			if st.anchor_length < 0.5:
				continue
			var ytop3 := top0 if end == 0 else top1
			var g2 := _ground(F, ground_fn, s_anchor, xs, fallback)
			var ya := minf(g2 + 0.3, F.pos(s_tower).y)
			out.cylinder(ROLE_RAIL, F.at_abs(s_tower, xs, ytop3), F.at_abs(s_anchor, xs, ya), cable_r, 6, false)
			out.box(ROLE_STRUCT, F.at_abs(s_anchor, xs, ya - 0.3), F.sidev(s_anchor), Vector3.UP, F.dirv(s_anchor), 0.6, 0.6, 0.6)


# ---------------------------------------------------------------------------
#  Panjaralar
# ---------------------------------------------------------------------------
static func _railings(out: Out, F: Frames, st: LiveBridgeSettings, Wr: float, Wt: float) -> void:
	var rs: int = st.railing_style
	if rs == LiveBridgeSettings.RailingStyle.NONE:
		return
	var L := F.length
	var hw := Wt * 0.5
	var H: float = st.railing_height
	var base_y := _curb_top(st, Wr, Wt)
	if rs == LiveBridgeSettings.RailingStyle.SOLID_PARAPET:
		var t := minf(st.parapet_thickness, Wt * 0.4)
		for sgn in [-1.0, 1.0]:
			var xa: float = sgn * hw
			var xb: float = sgn * (hw - t)
			var x0 := minf(xa, xb)
			var x1 := maxf(xa, xb)
			out.sweep(ROLE_STRUCT, F, 0.0, L, 0.75, _rect(x0, base_y - 0.03, x1, base_y + H))
			out.sweep(ROLE_STRUCT, F, 0.0, L, 0.75, _rect(x0 - 0.05, base_y + H - 0.02, x1 + 0.05, base_y + H + 0.1))
		return
	var n := maxi(1, int(ceil(L / maxf(st.post_spacing, 0.3))))
	var ps: float = st.post_size
	var rsz: float = st.rail_size
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * (hw - ps * 0.5 - 0.02)
		for k in range(n + 1):
			var sv := L * float(k) / float(n)
			var sd := F.sidev(sv)
			var d := F.dirv(sv)
			match rs:
				LiveBridgeSettings.RailingStyle.POSTS_AND_RAILS:
					out.box(ROLE_RAIL, F.at(sv, x, base_y + H * 0.5), sd, Vector3.UP, d, ps * 0.5, H * 0.5, ps * 0.5)
				LiveBridgeSettings.RailingStyle.WOODEN_FENCE:
					out.cylinder(ROLE_RAIL, F.at(sv, x, base_y - 0.02), F.at(sv, x, base_y + H), ps * 0.5, 7, true)
				LiveBridgeSettings.RailingStyle.CABLE_RAILS:
					out.box(ROLE_RAIL, F.at(sv, x, base_y + H * 0.5), sd, Vector3.UP, d, ps * 0.3, H * 0.5, ps * 0.3)
		for j in range(1, st.rail_count + 1):
			var h := base_y + H * float(j) / float(st.rail_count)
			for k in range(n):
				var sa := L * float(k) / float(n)
				var sb := L * float(k + 1) / float(n)
				var a := F.at(sa, x, h)
				var b := F.at(sb, x, h)
				if rs == LiveBridgeSettings.RailingStyle.CABLE_RAILS:
					out.cylinder(ROLE_RAIL, a, b, rsz * 0.35, 5, false)
				else:
					out.beam(ROLE_RAIL, a, b, F.sidev((sa + sb) * 0.5), rsz, rsz)


# ---------------------------------------------------------------------------
#  O'z mesh / sahna joylash
# ---------------------------------------------------------------------------
## Har bir bo'lak uchun Transform3D qaytaradi. src_aabb - mesh (yoki sahna) o'lchamlari.
static func custom_transforms(span: Dictionary, st: LiveBridgeSettings, src_aabb: AABB) -> Array:
	var pts: PackedVector3Array = span["pts"]
	var a := pts[0]
	var b := pts[pts.size() - 1]
	var chord := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var L := chord.length()
	if L < 0.01:
		return []
	var d := chord / L
	var mid := (a + b) * 0.5
	var Wr: float = span["width"]
	var Wt: float = Wr + 2.0 * st.width_extra
	var X := Vector3.UP.cross(d).normalized()
	var base := Basis(X, Vector3.UP, d)
	base = base * Basis(Vector3.UP, deg_to_rad(st.custom_rotation_y))
	var src_len: float = st.custom_mesh_length if st.custom_mesh_length > 0.001 else maxf(src_aabb.size.z, 0.001)
	var src_w := maxf(src_aabb.size.x, 0.001)
	var center := src_aabb.get_center()
	var result: Array = []
	var user_scale: Vector3 = st.custom_scale
	match st.custom_fit:
		LiveBridgeSettings.CustomFit.STRETCH_LENGTH:
			var sc := Vector3(user_scale.x, user_scale.y, user_scale.z * L / src_len)
			result.append(_ct(base, mid, d, 0.0, sc, center, st))
		LiveBridgeSettings.CustomFit.STRETCH_ALL:
			var sc2 := Vector3(user_scale.x * Wt / src_w, user_scale.y, user_scale.z * L / src_len)
			result.append(_ct(base, mid, d, 0.0, sc2, center, st))
		LiveBridgeSettings.CustomFit.TILE_ALONG:
			var tile_len := src_len * user_scale.z
			var n := maxi(1, int(round(L / maxf(tile_len, 0.01))))
			var cell := L / float(n)
			var sc3 := Vector3(user_scale.x, user_scale.y, user_scale.z * cell / maxf(tile_len, 0.001))
			for i in range(n):
				result.append(_ct(base, mid, d, -L * 0.5 + (float(i) + 0.5) * cell, sc3, center, st))
		_:
			result.append(_ct(base, mid, d, 0.0, user_scale, center, st))
	return result


static func _ct(base: Basis, mid: Vector3, d: Vector3, along: float, sc: Vector3, center: Vector3, st: LiveBridgeSettings) -> Transform3D:
	var bs := base.scaled_local(sc)
	var local_off: Vector3 = st.custom_offset - Vector3(center.x * sc.x, 0.0, center.z * sc.z)
	var origin := mid + d * along + base * local_off
	return Transform3D(bs, origin)
