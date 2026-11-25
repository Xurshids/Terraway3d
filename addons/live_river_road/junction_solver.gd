@tool
extends RefCounted
## Yo'llar o'zaro kesishganda chorraha/aylana joylarini topadi.
##
## Kirish (entries): har bir yo'l uchun
##   {"id": int, "pts": PackedVector3Array (xom, dunyo koordinatalari), "hw": float,
##    "settings": LiveJunctionSettings, "y_off": float}
## Chiqish:
##   "roads":    {id: {"pts": kesilgan nuqtalar, "hidden": PackedByteArray, "raw_hash": int}}
##   "clusters": [{center, y, owner, ring, R_cut, R_c, R_i, R_o, arms:[...], settings, y_off, key}]

const PathIndex := preload("res://addons/live_river_road/path_index.gd")
const PathMath := preload("res://addons/live_river_road/path_math.gd")

static var _cache_epoch: int = -1
static var _cache_key: int = 0
static var _cache: Dictionary = {}


static func peek(epoch: int, key: int) -> Dictionary:
	if epoch == _cache_epoch and key == _cache_key:
		return _cache
	return {}


static func store(epoch: int, key: int, result: Dictionary) -> void:
	_cache_epoch = epoch
	_cache_key = key
	_cache = result


static func invalidate() -> void:
	_cache_epoch = -1
	_cache = {}


# ---------------------------------------------------------------------------
static func solve(entries: Array) -> Dictionary:
	var result := {"clusters": [], "roads": {}}
	var n := entries.size()
	if n < 2:
		return result

	for e in entries:
		var pts: PackedVector3Array = e["pts"]
		e["s"] = PathMath.arc_lengths(pts)
		e["total"] = (e["s"] as PackedFloat32Array)[pts.size() - 1] if pts.size() > 0 else 0.0
		var idx := PathIndex.new()
		idx.build(pts, 8.0)
		e["index"] = idx
		var rect := Rect2()
		for k in range(pts.size()):
			if k == 0:
				rect = Rect2(Vector2(pts[k].x, pts[k].z), Vector2.ZERO)
			else:
				rect = rect.expand(Vector2(pts[k].x, pts[k].z))
		e["rect"] = rect

	var hits: Array = []
	for i in range(n):
		for j in range(i + 1, n):
			_find_hits(entries, i, j, hits)
	if hits.is_empty():
		return result

	var groups := _cluster_hits(entries, hits)
	var insertions: Dictionary = {}   # entry idx -> Array of {seg, t, tag}
	var clusters: Array = []

	for g in groups:
		var cl := _build_cluster(entries, g, insertions, clusters.size())
		if not cl.is_empty():
			clusters.append(cl)

	if clusters.is_empty():
		return result

	_build_roads(entries, clusters, insertions, result)
	_finish_clusters(entries, clusters, result)
	result["clusters"] = clusters
	return result


# ---------------------------------------------------------------------------
#  Kesishmalarni topish
# ---------------------------------------------------------------------------
static func _find_hits(entries: Array, i: int, j: int, hits: Array) -> void:
	var ea: Dictionary = entries[i]
	var eb: Dictionary = entries[j]
	var margin: float = float(ea["hw"]) + float(eb["hw"]) + 6.0
	if not (ea["rect"] as Rect2).grow(margin).intersects(eb["rect"] as Rect2):
		return
	var pa: PackedVector3Array = ea["pts"]
	var pb: PackedVector3Array = eb["pts"]
	var sa: PackedFloat32Array = ea["s"]
	var sb: PackedFloat32Array = eb["s"]
	var idx_b: RefCounted = eb["index"]
	var found: Array = []

	for k in range(pa.size() - 1):
		var a := pa[k]
		var b := pa[k + 1]
		for m in idx_b.call("candidates", a, b):
			var r := PathMath.seg_intersect_xz(a, b, pb[m], pb[m + 1])
			if r.is_empty():
				continue
			var t: float = r[0]
			var u: float = r[1]
			var p := a.lerp(b, t)
			var dup := false
			for h in found:
				if PathMath.dist_xz(h["p"], p) < 0.75:
					dup = true
					break
			if dup:
				continue
			var pj := pb[m].lerp(pb[m + 1], u)
			found.append({
				"i": i, "j": j, "p": Vector3(p.x, 0.5 * (p.y + pj.y), p.z),
				"si": lerpf(sa[k], sa[k + 1], t), "sj": lerpf(sb[m], sb[m + 1], u),
			})

	# Yo'l uchi boshqa yo'lga tegib turgan holat (T-chorraha)
	_touch_hits(entries, i, j, found)
	_touch_hits(entries, j, i, found)
	hits.append_array(found)


static func _touch_hits(entries: Array, a_idx: int, b_idx: int, found: Array) -> void:
	var ea: Dictionary = entries[a_idx]
	var eb: Dictionary = entries[b_idx]
	var pa: PackedVector3Array = ea["pts"]
	var pb: PackedVector3Array = eb["pts"]
	if pa.size() < 2 or pb.size() < 2:
		return
	var snap: float = float(eb["hw"]) + float(ea["hw"]) * 0.5 + 2.0
	for end in [0, 1]:
		var k := 0 if end == 0 else pa.size() - 1
		var ep := pa[k]
		var r: Array = (eb["index"] as RefCounted).call("nearest", ep)
		if float(r[0]) > snap:
			continue
		var skip := false
		for h in found:
			if PathMath.dist_xz(h["p"], ep) < float(ea["hw"]) + float(eb["hw"]) + 4.0:
				skip = true
				break
		if skip:
			continue
		var seg: int = r[2]
		if seg < 0:
			continue
		var sbv := lerpf((eb["s"] as PackedFloat32Array)[seg], (eb["s"] as PackedFloat32Array)[seg + 1], float(r[3]))
		var sav: float = 0.0 if end == 0 else float(ea["total"])
		var pt: Vector3 = r[1]
		var i_idx := a_idx
		var j_idx := b_idx
		var si := sav
		var sj := sbv
		if a_idx > b_idx:
			i_idx = b_idx
			j_idx = a_idx
			si = sbv
			sj = sav
		found.append({"i": i_idx, "j": j_idx, "p": Vector3(pt.x, 0.5 * (pt.y + ep.y), pt.z), "si": si, "sj": sj})


static func _cluster_hits(entries: Array, hits: Array) -> Array:
	var h := hits.size()
	var parent := PackedInt32Array()
	for k in range(h):
		parent.append(k)
	for a in range(h):
		for b in range(a + 1, h):
			var ra := _merge_radius(entries, hits[a])
			var rb := _merge_radius(entries, hits[b])
			if PathMath.dist_xz(hits[a]["p"], hits[b]["p"]) < maxf(ra, rb):
				var pa := _find_root(parent, a)
				var pb := _find_root(parent, b)
				if pa != pb:
					parent[pb] = pa
	var groups := {}
	for k in range(h):
		var r := _find_root(parent, k)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(hits[k])
	return groups.values()


static func _find_root(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


static func _merge_radius(entries: Array, hit: Dictionary) -> float:
	var s1 = entries[hit["i"]]["settings"]
	var s2 = entries[hit["j"]]["settings"]
	return maxf(float(s1.merge_radius), float(s2.merge_radius))


# ---------------------------------------------------------------------------
#  Klaster
# ---------------------------------------------------------------------------
static func _wrap_pos(a: float) -> float:
	return fposmod(a, TAU)


static func _build_cluster(entries: Array, group: Array, insertions: Dictionary, cluster_no: int) -> Dictionary:
	var parts: Dictionary = {}     # entry idx -> Array[s]
	var center := Vector3.ZERO
	for h in group:
		center += h["p"]
		for pair in [[h["i"], h["si"]], [h["j"], h["sj"]]]:
			if not parts.has(pair[0]):
				parts[pair[0]] = []
			(parts[pair[0]] as Array).append(float(pair[1]))
	center /= float(group.size())

	var owner_idx := -1
	for ei in parts.keys():
		if owner_idx < 0 or int(entries[ei]["id"]) < int(entries[owner_idx]["id"]):
			owner_idx = ei
	var st = entries[owner_idx]["settings"]
	if st == null or int(st.junction_mode) == LiveJunctionSettings.JunctionMode.NONE:
		return {}

	# Balandlik farqi
	var ys: Array = []
	var jy := 0.0
	for ei in parts.keys():
		var e: Dictionary = entries[ei]
		var sc := _mean(parts[ei])
		var y := PathMath.point_at(e["pts"], e["s"], sc).y
		ys.append(y)
		jy += y
	jy /= float(ys.size())
	if (ys.max() as float) - (ys.min() as float) > float(st.max_height_diff):
		return {}
	center.y = jy

	# Yo'nalishlar (arms)
	var arms: Array = []
	for ei in parts.keys():
		var e2: Dictionary = entries[ei]
		var pts: PackedVector3Array = e2["pts"]
		var s: PackedFloat32Array = e2["s"]
		var total: float = e2["total"]
		var sc2 := clampf(_mean(parts[ei]), 0.0, total)
		var p0 := PathMath.point_at(pts, s, sc2)
		for sgn in [1, -1]:
			var avail := (total - sc2) if sgn > 0 else sc2
			if avail < float(st.min_arm_length):
				continue
			var look := minf(avail, float(e2["hw"]) * 2.0 + 2.0)
			var p1 := PathMath.point_at(pts, s, sc2 + float(sgn) * look)
			var d := Vector2(p1.x - p0.x, p1.z - p0.z)
			if d.length_squared() < 0.0001:
				continue
			d = d.normalized()
			arms.append({"entry": ei, "sgn": sgn, "d": d, "hw": float(e2["hw"]), "sc": sc2})
	if arms.size() < 2:
		return {}
	var distinct := {}
	for a in arms:
		distinct[a["entry"]] = true
	if distinct.size() < 2 and arms.size() <= 2:
		return {}

	for a in arms:
		a["angle"] = _wrap_pos(atan2(float(a["d"].y), float(a["d"].x)))
	arms.sort_custom(func(x, y): return float(x["angle"]) < float(y["angle"]))

	var mode: int = int(st.junction_mode)
	var is_ring: bool = mode == LiveJunctionSettings.JunctionMode.ROUNDABOUT or (mode == LiveJunctionSettings.JunctionMode.AUTO and arms.size() >= int(st.roundabout_min_arms))
	if is_ring and arms.size() < 3:
		is_ring = false

	var r_cut := 0.0
	var ring := {}
	if is_ring:
		var W: float = float(st.ring_width)
		var need_o := 0.0
		for k in range(arms.size()):
			var a: Dictionary = arms[k]
			var b: Dictionary = arms[(k + 1) % arms.size()]
			var gap := _wrap_pos(float(b["angle"]) - float(a["angle"]))
			if arms.size() == 1:
				gap = TAU
			gap = maxf(gap, 0.12)
			need_o = maxf(need_o, (float(a["hw"]) + float(b["hw"]) + 2.0 * float(st.flare)) / gap)
		var R_c := float(st.roundabout_radius) if float(st.roundabout_radius) > 0.01 else (W + 4.0)
		R_c = maxf(R_c, need_o - W * 0.5)
		R_c = maxf(R_c, W * 0.5 + 1.5)
		R_c = minf(R_c, 90.0)
		ring = {"R_c": R_c, "R_i": R_c - W * 0.5, "R_o": R_c + W * 0.5, "W": W}
		r_cut = ring["R_o"] + float(st.approach_length)
	else:
		var need := 0.0
		for k in range(arms.size()):
			var a2: Dictionary = arms[k]
			var b2: Dictionary = arms[(k + 1) % arms.size()]
			var gap2 := _wrap_pos(float(b2["angle"]) - float(a2["angle"]))
			if gap2 > PI - 0.05 or gap2 < 0.0001:
				continue
			var d1: Vector2 = a2["d"]
			var d2: Vector2 = b2["d"]
			var n1 := Vector2(-d1.y, d1.x)
			var n2 := Vector2(-d2.y, d2.x)
			var r := PathMath.line_intersect_2d(n1 * float(a2["hw"]), d1, -n2 * float(b2["hw"]), d2)
			if r.is_empty():
				continue
			if float(r[0]) > 0.0 and float(r[1]) > 0.0:
				need = maxf(need, maxf(float(r[0]), float(r[1])) + float(st.corner_radius) + 0.4)
		var hwmax := 0.0
		for a3 in arms:
			hwmax = maxf(hwmax, float(a3["hw"]))
		need = maxf(need, hwmax * 1.3 + 1.0)
		r_cut = clampf(need, float(st.min_radius), float(st.max_radius))

	# Yo'llarni aylana bo'ylab kesish
	var kept: Array = []
	for a4 in arms:
		var e3: Dictionary = entries[a4["entry"]]
		var tag := "c%d_e%d_s%d" % [cluster_no, a4["entry"], a4["sgn"]]
		var cut := _find_cut(e3, float(a4["sc"]), int(a4["sgn"]), center, r_cut)
		if cut.is_empty():
			continue
		a4["tag"] = tag
		if not insertions.has(a4["entry"]):
			insertions[a4["entry"]] = []
		(insertions[a4["entry"]] as Array).append({"seg": cut["seg"], "t": cut["t"], "tag": tag})
		kept.append(a4)
	if kept.size() < 2:
		for a5 in arms:
			if a5.has("tag"):
				pass
		return {}

	var ids: Array = []
	for ei in parts.keys():
		ids.append(int(entries[ei]["id"]))
	ids.sort()
	return {
		"center": center, "y": jy, "owner": int(entries[owner_idx]["id"]),
		"ring": is_ring, "R_cut": r_cut, "R_c": ring.get("R_c", 0.0), "R_i": ring.get("R_i", 0.0),
		"R_o": ring.get("R_o", 0.0), "W": ring.get("W", 0.0),
		"arms": kept, "settings": st, "y_off": float(entries[owner_idx]["y_off"]),
		"key": hash([ids, snappedf(center.x, 1.0), snappedf(center.z, 1.0)]),
		"participants": parts.keys(),
	}


static func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)


## sc dan sgn yo'nalishida yo'l aylana (markaz, radius) dan chiqqan joyni topadi.
static func _find_cut(e: Dictionary, sc: float, sgn: int, center: Vector3, radius: float) -> Dictionary:
	var pts: PackedVector3Array = e["pts"]
	var s: PackedFloat32Array = e["s"]
	var seg := PathMath.seg_of(s, sc)
	if sgn > 0:
		for k in range(seg, pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			if PathMath.dist_xz(a, center) <= radius and PathMath.dist_xz(b, center) > radius:
				var t := PathMath.circle_exit_t(center, radius, a, b)
				if t >= 0.0:
					return {"seg": k, "t": t}
	else:
		for k in range(seg, -1, -1):
			var a2 := pts[k + 1]
			var b2 := pts[k]
			if PathMath.dist_xz(a2, center) <= radius and PathMath.dist_xz(b2, center) > radius:
				var t2 := PathMath.circle_exit_t(center, radius, a2, b2)
				if t2 >= 0.0:
					return {"seg": k, "t": 1.0 - t2}
	return {}


# ---------------------------------------------------------------------------
#  Yo'l nuqtalarini qayta qurish (kesish, balandlik, yashirin segmentlar)
# ---------------------------------------------------------------------------
static func _build_roads(entries: Array, clusters: Array, insertions: Dictionary, result: Dictionary) -> void:
	var tag_index: Dictionary = {}   # tag -> {entry, idx}
	var touched := {}
	for cl in clusters:
		for ei in cl["participants"]:
			touched[ei] = true
	for ei in touched.keys():
		var e: Dictionary = entries[ei]
		var pts: PackedVector3Array = e["pts"]
		var ins: Array = insertions.get(ei, [])
		ins.sort_custom(func(a, b): return float(a["seg"]) + float(a["t"]) < float(b["seg"]) + float(b["t"]))
		var by_seg := {}
		for it in ins:
			if not by_seg.has(it["seg"]):
				by_seg[it["seg"]] = []
			(by_seg[it["seg"]] as Array).append(it)

		var new_pts := PackedVector3Array()
		var orig_to_new := PackedInt32Array()
		orig_to_new.resize(pts.size())
		var pending: Array = []
		for k in range(pts.size()):
			new_pts.append(pts[k])
			orig_to_new[k] = new_pts.size() - 1
			if k < pts.size() - 1 and by_seg.has(k):
				for it2 in by_seg[k]:
					var t: float = it2["t"]
					if t <= 0.001:
						tag_index[it2["tag"]] = {"entry": ei, "idx": orig_to_new[k]}
					elif t >= 0.999:
						pending.append(it2)
					else:
						new_pts.append(pts[k].lerp(pts[k + 1], t))
						tag_index[it2["tag"]] = {"entry": ei, "idx": new_pts.size() - 1}
		for it3 in pending:
			tag_index[it3["tag"]] = {"entry": ei, "idx": orig_to_new[int(it3["seg"]) + 1]}

		# Balandlikni chorraha balandligiga silliq o'tkazish
		for cl in clusters:
			if not (ei in cl["participants"]):
				continue
			var c: Vector3 = cl["center"]
			var rc: float = cl["R_cut"]
			var blend: float = maxf(float(cl["settings"].blend_length), 0.01)
			var jy: float = cl["y"]
			for k in range(new_pts.size()):
				var d := PathMath.dist_xz(new_pts[k], c)
				var w := 0.0
				if d <= rc + 0.02:
					w = 1.0
				elif d < rc + blend:
					w = 1.0 - smoothstep(0.0, 1.0, (d - rc) / blend)
				if w > 0.0:
					new_pts[k].y = lerpf(new_pts[k].y, jy, w)

		# Yashirin segmentlar
		var hidden := PackedByteArray()
		hidden.resize(maxi(new_pts.size() - 1, 0))
		hidden.fill(0)
		for cl in clusters:
			if not (ei in cl["participants"]):
				continue
			var c2: Vector3 = cl["center"]
			var r2: float = cl["R_cut"] + 0.02
			for k in range(new_pts.size() - 1):
				if PathMath.dist_xz(new_pts[k], c2) <= r2 and PathMath.dist_xz(new_pts[k + 1], c2) <= r2:
					hidden[k] = 1
		result["roads"][e["id"]] = {"pts": new_pts, "hidden": hidden, "raw_hash": hash(pts)}

	# Yo'nalishlarni yakuniy indekslarga bog'lash
	for cl in clusters:
		for a in cl["arms"]:
			if tag_index.has(a["tag"]):
				a["idx"] = tag_index[a["tag"]]["idx"]
			else:
				a["idx"] = -1


## Yo'nalishlarning chekka nuqtalarini hisoblaydi va burchak bo'yicha tartiblaydi.
static func _finish_clusters(entries: Array, clusters: Array, result: Dictionary) -> void:
	for cl in clusters:
		var c: Vector3 = cl["center"]
		var yy: float = float(cl["y"]) + float(cl["y_off"])
		var out_arms: Array = []
		for a in cl["arms"]:
			if int(a["idx"]) < 0:
				continue
			var e: Dictionary = entries[a["entry"]]
			var road: Dictionary = result["roads"][e["id"]]
			var pts: PackedVector3Array = road["pts"]
			var fr := PathMath.row_frame(pts, int(a["idx"]), float(e["hw"]))
			var t: Vector3 = fr[0]
			var side := Vector3(-t.z, 0.0, t.x)
			var P := pts[int(a["idx"])]
			var L: Vector3 = P - side * float(fr[1])
			var R: Vector3 = P + side * float(fr[2])
			var sgn: int = a["sgn"]
			var d_out: Vector3 = t * float(sgn)
			var ccw: Vector3 = R if sgn > 0 else L
			var cw: Vector3 = L if sgn > 0 else R
			P.y = yy
			ccw.y = yy
			cw.y = yy
			out_arms.append({
				"road": e["id"], "P": P, "d_out": d_out, "ccw": ccw, "cw": cw,
				"angle": _wrap_pos(atan2(P.z - c.z, P.x - c.x)),
			})
		out_arms.sort_custom(func(x, y): return float(x["angle"]) < float(y["angle"]))
		cl["arms"] = out_arms
		cl["center"] = Vector3(c.x, yy, c.z)
