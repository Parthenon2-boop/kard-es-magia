class_name Cv
extends RefCounted
## A böngészős <canvas> 2D rajzoló (ctx) utánzata Godot RenderingServer hívásokkal.
## Így az eredeti rajzoló függvények (útvonalak, ívek, görbék, átlátszóság, színátmenetek)
## szinte sorról sorra átírhatók: bp/mt/lt/qt/bt/arc/ellipse/cp, fill/stroke, save/restore...
## Az útvonal pontjai a megadás pillanatában transzformálódnak (mint a canvasban).

var ci: RID
var xf := Transform2D.IDENTITY
var alpha := 1.0
var fill_v: Variant = Color.WHITE     # Color vagy Grad
var stroke_v: Variant = Color.WHITE
var line_width := 1.0
var _stack: Array = []
var _subs: Array = []          # lezárt/elhagyott részutak (eszköz-koordináták)
var _subs_closed: Array = []
var _cur := PackedVector2Array()
var _start := Vector2.ZERO

static var font_serif: Font
static var font_mono: Font
static var _col_cache := {}


## Színátmenet (lineáris vagy sugaras). A koordináták a kitöltés pillanatának transzformációjában értendők.
class Grad:
	var radial := false
	var p0 := Vector2.ZERO
	var p1 := Vector2.ZERO
	var r0 := 0.0
	var r1 := 1.0
	var offs: Array[float] = []
	var cols: Array[Color] = []
	var seg := 22.0   # a háló finomsága (eszköz-pixel)

	func stop(t: float, c: Variant) -> Grad:
		var col: Color = Cv.col(c)
		# az átlátszó színpont a szomszéd színét kapja: a GPU egyenes keverése így nem sötétít
		if col.a <= 0.0 and not cols.is_empty():
			col = Color(cols[cols.size() - 1], 0.0)
		elif not cols.is_empty() and cols[cols.size() - 1].a <= 0.0:
			for i in cols.size():
				if cols[i].a <= 0.0:
					cols[i] = Color(col, 0.0)
		offs.append(t)
		cols.append(col)
		return self

	func at(p: Vector2) -> Color:
		var t := 0.0
		if radial:
			t = ((p - p0).length() - r0) / maxf(0.0001, r1 - r0)
		else:
			var d := p1 - p0
			var l2 := d.length_squared()
			t = (p - p0).dot(d) / l2 if l2 > 0.0 else 0.0
		if offs.is_empty():
			return Color(0, 0, 0, 0)
		if t <= offs[0]:
			return cols[0]
		var n := offs.size()
		for i in range(1, n):
			if t <= offs[i]:
				var u := (t - offs[i - 1]) / maxf(0.00001, offs[i] - offs[i - 1])
				return cols[i - 1].lerp(cols[i], u)
		return cols[n - 1]

static func linear(x0: float, y0: float, x1: float, y1: float) -> Grad:
	var g := Grad.new()
	g.p0 = Vector2(x0, y0)
	g.p1 = Vector2(x1, y1)
	return g


static func radial(x: float, y: float, r0: float, r1: float) -> Grad:
	var g := Grad.new()
	g.radial = true
	g.p0 = Vector2(x, y)
	g.r0 = r0
	g.r1 = r1
	return g


static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clampf(a, 0.0, 1.0))


static func col(c: Variant) -> Variant:
	if c is Color or c is Grad:
		return c
	if c is String:
		if _col_cache.has(c):
			return _col_cache[c]
		var v := Color(0, 0, 0, 0) if c == "transparent" else Color(c)
		_col_cache[c] = v
		return v
	return Color.WHITE


# ══════════ ÁLLAPOT ══════════
func begin(rid: RID) -> void:
	flush()
	ci = rid
	xf = Transform2D.IDENTITY
	alpha = 1.0
	fill_v = Color.WHITE
	stroke_v = Color.WHITE
	line_width = 1.0
	_stack.clear()
	bp()


func save() -> void:
	_stack.append([xf, alpha, fill_v, stroke_v, line_width])


func restore() -> void:
	if _stack.is_empty():
		return
	var s: Array = _stack.pop_back()
	xf = s[0]
	alpha = s[1]
	fill_v = s[2]
	stroke_v = s[3]
	line_width = s[4]


func translate(x: float, y: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(x, y))


func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)


func scale(sx: float, sy: float) -> void:
	xf = xf * Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO)


func fs(c: Variant) -> void:
	fill_v = col(c)


func ss(c: Variant) -> void:
	stroke_v = col(c)


func lw(w: float) -> void:
	line_width = w


func ga(a: float) -> void:
	alpha = a


func _scl() -> float:
	return sqrt(absf(xf.determinant()))


# ══════════ ÚTVONAL ══════════
func bp() -> void:
	_subs.clear()
	_subs_closed.clear()
	_cur = PackedVector2Array()


func _flush() -> void:
	if _cur.size() > 0:
		_subs.append(_cur)
		_subs_closed.append(false)
	_cur = PackedVector2Array()


func mt(x: float, y: float) -> void:
	_flush()
	var p := xf * Vector2(x, y)
	_cur.append(p)
	_start = p


func lt(x: float, y: float) -> void:
	var p := xf * Vector2(x, y)
	if _cur.is_empty():
		_start = p
	_cur.append(p)


func _add_dev(p: Vector2) -> void:
	if _cur.is_empty():
		_start = p
	_cur.append(p)


func cp() -> void:
	if _cur.size() > 0:
		_subs.append(_cur)
		_subs_closed.append(true)
	_cur = PackedVector2Array()
	_cur.append(_start)


func qt(cx: float, cy: float, x: float, y: float) -> void:
	var c := xf * Vector2(cx, cy)
	var e := xf * Vector2(x, y)
	if _cur.is_empty():
		_add_dev(c)
	var s := _cur[_cur.size() - 1]
	var n := clampi(int((s.distance_to(c) + c.distance_to(e)) / 4.0), 4, 24)
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		_cur.append(s * (u * u) + c * (2.0 * u * t) + e * (t * t))


func bt(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> void:
	var c1 := xf * Vector2(c1x, c1y)
	var c2 := xf * Vector2(c2x, c2y)
	var e := xf * Vector2(x, y)
	if _cur.is_empty():
		_add_dev(c1)
	var s := _cur[_cur.size() - 1]
	var n := clampi(int((s.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(e)) / 4.0), 5, 30)
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		_cur.append(s * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + e * (t * t * t))


static func _sweep(a0: float, a1: float, ccw: bool) -> float:
	if not ccw:
		if a1 - a0 >= TAU:
			return TAU
		var s := fposmod(a1 - a0, TAU)
		return s
	else:
		if a0 - a1 >= TAU:
			return -TAU
		return -fposmod(a0 - a1, TAU)


func arc(x: float, y: float, r: float, a0: float, a1: float, ccw := false) -> void:
	ellipse(x, y, r, r, 0.0, a0, a1, ccw)


func ellipse(x: float, y: float, rx: float, ry: float, rot: float, a0: float, a1: float, ccw := false) -> void:
	var sw := _sweep(a0, a1, ccw)
	var rdev := maxf(absf(rx), absf(ry)) * _scl()
	var n := clampi(int(ceilf(absf(sw) * rdev / 3.0)), 6, 96)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n + 1:
		var a := a0 + sw * float(i) / n
		var lx := rx * cos(a)
		var ly := ry * sin(a)
		_add_dev(xf * Vector2(x + lx * cr - ly * sr, y + lx * sr + ly * cr))


func rect(x: float, y: float, w: float, h: float) -> void:
	mt(x, y)
	lt(x + w, y)
	lt(x + w, y + h)
	lt(x, y + h)
	cp()


## Lekerekített téglalap (új útvonalat kezd, mint az eredeti rrect)
func rrect(x: float, y: float, w: float, h: float, r: float) -> void:
	bp()
	r = minf(r, minf(absf(w) / 2.0, absf(h) / 2.0))
	if r <= 0.05:
		rect(x, y, w, h)
		return
	mt(x + r, y)
	lt(x + w - r, y)
	arc(x + w - r, y + r, r, -PI / 2.0, 0.0)
	lt(x + w, y + h - r)
	arc(x + w - r, y + h - r, r, 0.0, PI / 2.0)
	lt(x + r, y + h)
	arc(x + r, y + h - r, r, PI / 2.0, PI)
	lt(x, y + r)
	arc(x + r, y + r, r, PI, PI * 1.5)
	cp()


func _all_subs() -> Array:
	var out: Array = []
	for i in _subs.size():
		out.append([_subs[i], _subs_closed[i]])
	if _cur.size() > 1:
		out.append([_cur, false])
	return out


static func _clean(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.size() == 0 or out[out.size() - 1].distance_squared_to(p) > 0.0025:
			out.append(p)
	while out.size() > 2 and out[0].distance_squared_to(out[out.size() - 1]) <= 0.0025:
		out.remove_at(out.size() - 1)
	return out


# ══════════ KITÖLTÉS / KÖRVONAL (kötegelve) ══════════
# Minden kitöltés és körvonal egyetlen háromszög-tömbbe gyűlik, és csak szöveg/textúra előtt,
# illetve a réteg végén kerül a RenderingServerhez: így képkockánként csak néhány rajzhívás lesz.
# Az élek lágyítása (antialias): 1 pixeles, kifelé átlátszóvá halványuló "tollazat".
var _bp := PackedVector2Array()
var _bc := PackedColorArray()
var _bi := PackedInt32Array()
var aa := true
const FEATHER := 1.0


var recording := false


static var stat_polys := 0


func flush() -> void:
	if recording:
		return
	if _bi.size() > 0:
		stat_polys += 1
		RenderingServer.canvas_item_add_triangle_array(ci, _bi, _bp, _bc)
	_bp = PackedVector2Array()
	_bc = PackedColorArray()
	_bi = PackedInt32Array()


func _tri(a: int, b: int, c: int) -> void:
	_bi.append(a)
	_bi.append(b)
	_bi.append(c)


func fill() -> void:
	for s in _all_subs():
		var pts := _clean(s[0])
		if pts.size() >= 3:
			_fill_poly(pts)


func fill_rect(x: float, y: float, w: float, h: float) -> void:
	var pts := PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)])
	var axis := absf(xf.x.y) < 0.0001 and absf(xf.y.x) < 0.0001
	if fill_v is Color and axis:
		# tengelyirányú téglalap: nincs szükség élsimításra
		var cc: Color = fill_v
		cc.a *= alpha
		if cc.a <= 0.003:
			return
		var b := _bp.size()
		_bp.append_array(pts)
		_bc.append(cc)
		_bc.append(cc)
		_bc.append(cc)
		_bc.append(cc)
		_tri(b, b + 1, b + 2)
		_tri(b, b + 2, b + 3)
		return
	_fill_poly(pts)


func stroke_rect(x: float, y: float, w: float, h: float) -> void:
	var keep_s := _subs
	var keep_c := _subs_closed
	var keep_cur := _cur
	_subs = []
	_subs_closed = []
	_cur = PackedVector2Array()
	rect(x, y, w, h)
	stroke()
	_subs = keep_s
	_subs_closed = keep_c
	_cur = keep_cur


static func _signed_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	var n := pts.size()
	for i in n:
		var p := pts[i]
		var q := pts[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func _fill_poly(pts: PackedVector2Array) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if fill_v is Color:
		var cc: Color = fill_v
		cc.a *= alpha
		if cc.a <= 0.003:
			return
		var b := _bp.size()
		_bp.append_array(pts)
		for i in pts.size():
			_bc.append(cc)
		if idx.is_empty():
			# önmetsző alakzat: legyező háromszögelés a súlypontból
			var c := Vector2.ZERO
			for p in pts: c += p
			var n := pts.size()
			var ci2 := _bp.size()
			_bp.append(c / n)
			_bc.append(cc)
			for i in n:
				_tri(ci2, b + i, b + (i + 1) % n)
		else:
			for i in idx.size():
				_bi.append(b + idx[i])
		if aa:
			_feather(pts, b)
	else:
		_grad_fill(pts, idx, fill_v)


## élsimító tollazat a sokszög köré: a belső pontok színe marad, a külső 1 px-en átlátszóvá halványul.
## base: a sokszög pontjainak kezdőindexe a kötegben (ott már megvannak a színek)
func _feather(pts: PackedVector2Array, base: int) -> void:
	var n := pts.size()
	if n < 3:
		return
	var out_sign := 1.0 if _signed_area(pts) > 0.0 else -1.0
	var ob := _bp.size()
	for i in n:
		var prev := pts[(i + n - 1) % n]
		var cur := pts[i]
		var nxt := pts[(i + 1) % n]
		var e1 := (cur - prev).normalized()
		var e2 := (nxt - cur).normalized()
		var n1 := Vector2(e1.y, -e1.x) * out_sign
		var n2 := Vector2(e2.y, -e2.x) * out_sign
		var nv := n1 + n2
		var l := nv.length()
		if l < 0.001:
			nv = n1
		else:
			nv /= l
		var dd := nv.dot(n1)
		var sc := 1.0 / maxf(0.4, dd)
		_bp.append(cur + nv * FEATHER * minf(sc, 2.5))
		var col := _bc[base + i]
		col.a = 0.0
		_bc.append(col)
	for i in n:
		var j := (i + 1) % n
		_tri(base + i, base + j, ob + j)
		_tri(base + i, ob + j, ob + i)


func stroke() -> void:
	var c: Color = stroke_v if stroke_v is Color else (stroke_v as Grad).cols[0]
	c.a *= alpha
	var w := line_width * _scl()
	if w < 1.0:
		c.a *= maxf(w, 0.3)
		w = 1.0
	if c.a <= 0.003:
		return
	var hw := maxf(0.0, w / 2.0 - 0.5)   # a tömör rész fele
	var fe := 1.0                         # lágy szél
	var c0 := c
	c0.a = 0.0
	for s in _all_subs():
		var pts: PackedVector2Array = s[0]
		if pts.size() < 2:
			continue
		if s[1]:
			pts = pts.duplicate()
			pts.append(pts[0])
		var prev_n := Vector2.ZERO
		for i in pts.size() - 1:
			var a := pts[i]
			var bb := pts[i + 1]
			var d := bb - a
			var ln := d.length()
			if ln < 0.0001:
				continue
			var nn := Vector2(-d.y, d.x) / ln
			var b0 := _bp.size()
			# 4-4 pont a szakasz két végén: külső-bal, bal, jobb, külső-jobb
			_bp.append(a + nn * (hw + fe)); _bc.append(c0)
			_bp.append(a + nn * hw); _bc.append(c)
			_bp.append(a - nn * hw); _bc.append(c)
			_bp.append(a - nn * (hw + fe)); _bc.append(c0)
			_bp.append(bb + nn * (hw + fe)); _bc.append(c0)
			_bp.append(bb + nn * hw); _bc.append(c)
			_bp.append(bb - nn * hw); _bc.append(c)
			_bp.append(bb - nn * (hw + fe)); _bc.append(c0)
			for k in 3:
				_tri(b0 + k, b0 + k + 1, b0 + 5 + k)
				_tri(b0 + k, b0 + 5 + k, b0 + 4 + k)
			# vastag vonalnál a töréspontok hézagát kitöltjük
			if hw >= 1.0 and prev_n != Vector2.ZERO:
				var j := _bp.size()
				_bp.append(a); _bc.append(c)
				_bp.append(a + prev_n * hw); _bc.append(c)
				_bp.append(a + nn * hw); _bc.append(c)
				_bp.append(a - prev_n * hw); _bc.append(c)
				_bp.append(a - nn * hw); _bc.append(c)
				_tri(j, j + 1, j + 2)
				_tri(j, j + 3, j + 4)
			prev_n = nn


# ── színátmenetes kitöltés ──
func _grad_fill(pts: PackedVector2Array, idx: PackedInt32Array, g: Grad) -> void:
	var inv := xf.affine_inverse()
	if g.radial:
		var c := xf * g.p0
		if Geometry2D.is_point_in_polygon(c, pts):
			_radial_fan(pts, g, inv, c)
		else:
			_radial_soup(pts, idx, g, inv)
	else:
		_linear_bands(pts, g, inv)
	# élsimítás a határ mentén, a határ színeivel
	if aa:
		var b := _bp.size()
		_bp.append_array(pts)
		for p in pts:
			_bc.append(_gcol(g, inv, p))
		_feather(pts, b)


func _gcol(g: Grad, inv: Transform2D, p: Vector2) -> Color:
	var col := g.at(inv * p)
	col.a *= alpha
	return col


## lineáris átmenet: a sokszöget a színpontok mentén sávokra vágjuk; egy sávon belül a csúcsszínek
## lineáris keverése pontos
func _linear_bands(pts: PackedVector2Array, g: Grad, inv: Transform2D) -> void:
	var d := g.p1 - g.p0
	var L := d.length()
	if L < 0.00001:
		var idx := Geometry2D.triangulate_polygon(pts)
		var b := _bp.size()
		_bp.append_array(pts)
		for p in pts: _bc.append(_gcol(g, inv, p))
		for i in idx: _bi.append(b + i)
		return
	var u := d / L
	var nrm := Vector2(-u.y, u.x)
	var big := 1.0e5 / maxf(0.0001, _scl())
	var cuts: Array[float] = [-big / L]
	for o in g.offs:
		cuts.append(o)
	cuts.append(big / L)
	for k in cuts.size() - 1:
		var t0 := cuts[k]
		var t1 := cuts[k + 1]
		if t1 - t0 <= 0.000001:
			continue
		var a0 := g.p0 + u * (L * t0)
		var a1 := g.p0 + u * (L * t1)
		var band := PackedVector2Array([xf * (a0 + nrm * big), xf * (a1 + nrm * big), xf * (a1 - nrm * big), xf * (a0 - nrm * big)])
		for piece in Geometry2D.intersect_polygons(pts, band):
			var pp: PackedVector2Array = piece
			if pp.size() < 3:
				continue
			var idx := Geometry2D.triangulate_polygon(pp)
			if idx.is_empty():
				continue
			var b := _bp.size()
			_bp.append_array(pp)
			for p in pp: _bc.append(_gcol(g, inv, p))
			for i in idx: _bi.append(b + i)


## sugaras átmenet: legyező a középpontból, gyűrűkkel a színpontoknál és egyenletes sugaraknál
func _radial_fan(pts: PackedVector2Array, g: Grad, inv: Transform2D, c: Vector2) -> void:
	var sc := _scl()
	var r0 := g.r0 * sc
	var r1 := g.r1 * sc
	# a határ sűrítése (hosszú egyenes éleken is legyen elég pont)
	var maxseg := clampf(r1 / 7.0, 3.0, 26.0)
	var bd := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var bb := pts[(i + 1) % n]
		var k := maxi(1, int(ceilf(a.distance_to(bb) / maxseg)))
		for j in k:
			bd.append(a.lerp(bb, float(j) / k))
	# gyűrűk: egy sugár mentén a távolság lineáris, így elég a színpontok sugarán gyűrűt tenni
	var rings: Array[float] = []
	if r0 > 0.5:
		rings.append(r0)
	rings.append(r1)
	for o in g.offs:
		var rr := r0 + (r1 - r0) * o
		if rr > 0.5:
			rings.append(rr)
	rings.sort()
	var m := bd.size()
	var base := _bp.size()
	_bp.append(c)
	_bc.append(_gcol(g, inv, c))
	for i in m:
		var p := bd[i]
		var dv := p - c
		var D := dv.length()
		var dir := dv / D if D > 0.0001 else Vector2.RIGHT
		for rk in rings:
			var q := c + dir * minf(rk, D)
			_bp.append(q)
			_bc.append(_gcol(g, inv, q))
		_bp.append(p)
		_bc.append(_gcol(g, inv, p))
	var S := rings.size() + 1   # pontok sugaranként
	for i in m:
		var j := (i + 1) % m
		var ri := base + 1 + i * S
		var rj := base + 1 + j * S
		_tri(base, ri, rj)
		for k in S - 1:
			_tri(ri + k, ri + k + 1, rj + k + 1)
			_tri(ri + k, rj + k + 1, rj + k)


## tartalék: ha a középpont kívül esik, csúcsonkénti színezés, mérsékelt felosztással
func _radial_soup(pts: PackedVector2Array, idx: PackedInt32Array, g: Grad, inv: Transform2D) -> void:
	if idx.is_empty():
		return
	var out := PackedVector2Array()
	var seg := clampf(g.r1 * _scl() / 5.0, 3.0, 30.0)
	for t in range(0, idx.size(), 3):
		_subdiv(pts[idx[t]], pts[idx[t + 1]], pts[idx[t + 2]], seg * seg, 0, out)
	var b := _bp.size()
	_bp.append_array(out)
	for i in out.size():
		_bc.append(_gcol(g, inv, out[i]))
		_bi.append(b + i)


static func _subdiv(a: Vector2, b: Vector2, c: Vector2, ml2: float, depth: int, out: PackedVector2Array) -> void:
	var m := maxf(a.distance_squared_to(b), maxf(b.distance_squared_to(c), c.distance_squared_to(a)))
	if m <= ml2 or depth >= 4:
		out.append(a)
		out.append(b)
		out.append(c)
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var ca := (c + a) * 0.5
	_subdiv(a, ab, ca, ml2, depth + 1, out)
	_subdiv(ab, b, bc, ml2, depth + 1, out)
	_subdiv(ca, bc, c, ml2, depth + 1, out)
	_subdiv(ab, bc, ca, ml2, depth + 1, out)


# ══════════ SZÖVEG ══════════
static func font_for(mono: bool) -> Font:
	var f: Font = font_mono if mono else font_serif
	if f == null:
		f = ThemeDB.fallback_font
	return f


## A szövegszélesség lekérdezése drága (betűkészlet-keresés, tartalékbetűk), ezért gyorsítótárazzuk:
## ugyanaz a szöveg ugyanakkora mérettel képkockánként sokszor is előfordul (ftxt_fit, wrap, ls_text).
static var _m_cache := {}


static func measure(s: String, sz: float, mono := false) -> float:
	var size := maxi(1, int(roundf(sz)))
	var bucket: Dictionary = _m_cache.get(size * 2 + (1 if mono else 0), {})
	var v: Variant = bucket.get(s)
	if v != null:
		return v
	var f := font_for(mono)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if bucket.is_empty():
		_m_cache[size * 2 + (1 if mono else 0)] = bucket
	elif bucket.size() > 3000:
		bucket.clear()
	bucket[s] = w
	return w


## a betűkészlet cseréjekor (indítás) a gyorsítótár érvénytelen
static func clear_font_cache() -> void:
	_m_cache.clear()


## Az eredeti ftxt(str,x,y,col,sz,align,font): félkövér szöveg az alapvonalra.
func ftxt(s: String, x: float, y: float, c: Variant, sz: float, align := "left", mono := false) -> void:
	if s == "":
		return
	var f := font_for(mono)
	var size := maxi(1, int(roundf(sz)))
	var cv: Variant = col(c)
	var cc: Color = (cv as Grad).cols[0] if cv is Grad else cv
	cc.a *= alpha
	if cc.a <= 0.003:
		return
	var ox := x
	if align != "left":
		var wd := measure(s, sz, mono)
		ox -= wd / 2.0 if align == "center" else wd
	flush()
	if xf != Transform2D.IDENTITY:
		RenderingServer.canvas_item_add_set_transform(ci, xf)
		f.draw_string(ci, Vector2(ox, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, cc)
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
	else:
		f.draw_string(ci, Vector2(ox, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, cc)


## Szöveg, amely nem lóghat ki: ha szélesebb, mint maxw, kisebb betűvel, végső esetben "…"-vel rövidítve.
func ftxt_fit(s: String, x: float, y: float, c: Variant, sz: float, maxw: float, align := "left", mono := false) -> void:
	var size := sz
	while size > 7.0 and measure(s, size, mono) > maxw:
		size -= 0.5
	var t := s
	if measure(t, size, mono) > maxw:
		while t.length() > 1 and measure(t + "…", size, mono) > maxw:
			t = t.substr(0, t.length() - 1)
		t += "…"
	ftxt(t, x, y, c, size, align, mono)


## Tördelt szöveg (wrapText); visszaadja a sorok számát
func wrap_text(text: String, x: float, y: float, maxw: float, sz: float, c: Variant, align := "left") -> int:
	var lines := wrap_lines(text, maxw, sz)
	var ly := y
	for l in lines:
		ftxt(l, x, ly, c, sz, align)
		ly += sz + 5
	return lines.size()


static func wrap_lines(text: String, maxw: float, sz: float) -> Array[String]:
	var words := text.split(" ")
	var line := ""
	var lines: Array[String] = []
	for w in words:
		var t2 := (line + " " + w) if line != "" else w
		if measure(t2, sz) > maxw and line != "":
			lines.append(line)
			line = w
		else:
			line = t2
	if line != "":
		lines.append(line)
	return lines


# ══════════ TEXTÚRÁK ══════════
func tex(t: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	var m := mod
	m.a *= alpha
	if m.a <= 0.003:
		return
	flush()
	if xf != Transform2D.IDENTITY:
		RenderingServer.canvas_item_add_set_transform(ci, xf)
		RenderingServer.canvas_item_add_texture_rect(ci, r, t.get_rid(), false, m)
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
	else:
		RenderingServer.canvas_item_add_texture_rect(ci, r, t.get_rid(), false, m)


func tex_region(t: Texture2D, r: Rect2, src: Rect2, mod: Color = Color.WHITE) -> void:
	var m := mod
	m.a *= alpha
	if m.a <= 0.003:
		return
	flush()
	RenderingServer.canvas_item_add_texture_rect_region(ci, r, t.get_rid(), src, m)


func tex_tiled(t: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	var m := mod
	m.a *= alpha
	flush()
	RenderingServer.canvas_item_add_texture_rect(ci, r, t.get_rid(), true, m)


# ══════════ RÖVIDÍTÉSEK ══════════
static var _unit_cache := {}


static func _unit(n: int) -> PackedVector2Array:
	if _unit_cache.has(n):
		return _unit_cache[n]
	var u := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		u.append(Vector2(cos(a), sin(a)))
	_unit_cache[n] = u
	return u


## bp + arc(0..2π) + fill — egyszínű kitöltésnél gyors, domború (legyező) út
func circ(x: float, y: float, r: float) -> void:
	ell(x, y, r, r, 0.0)


## bp + ellipse + fill
func ell(x: float, y: float, rx: float, ry: float, rot := 0.0) -> void:
	bp()
	if not (fill_v is Color):
		ellipse(x, y, rx, ry, rot, 0, 7)
		fill()
		return
	var cc: Color = fill_v
	cc.a *= alpha
	if cc.a <= 0.003 or rx <= 0.0 or ry <= 0.0:
		return
	var m := xf * Transform2D(rot, Vector2(rx, ry), 0.0, Vector2(x, y))
	var rdev := maxf(m.x.length(), m.y.length())
	var n := clampi(int(ceilf(TAU * rdev / 4.0)), 8, 72)
	var unit := _unit(n)
	var pts: PackedVector2Array = m * unit
	var c := m.origin
	var b := _bp.size()
	_bp.append(c)
	_bp.append_array(pts)
	var cols := PackedColorArray()
	cols.resize(n + 1)
	cols.fill(cc)
	_bc.append_array(cols)
	for i in n:
		_tri(b, b + 1 + i, b + 1 + (i + 1) % n)
	if aa:
		# tollazat: a határpontokat 1 px-lel kifelé toljuk
		var ob := _bp.size()
		for i in n:
			var p := pts[i]
			var d := p - c
			var l := d.length()
			_bp.append(p + (d / l if l > 0.0001 else Vector2.ZERO) * FEATHER)
		var c0 := cc
		c0.a = 0.0
		cols.resize(n)
		cols.fill(c0)
		_bc.append_array(cols)
		for i in n:
			var j := (i + 1) % n
			_tri(b + 1 + i, b + 1 + j, ob + j)
			_tri(b + 1 + i, ob + j, ob + i)


# ══════════ FELVÉTEL / VISSZAJÁTSZÁS (gyorsítótár a bonyolult, ritkán változó rajzokhoz) ══════════
## A felvétel a helyi (0,0) körüli koordinátákban készül; visszajátszáskor egy transzformációval kerül a helyére.
var _rec_stash: Array = []


## A felvétel nem üríti a folyamatban lévő köteget, csak félreteszi: így egy gyorsítótár-hiány
## sem szakítja szét a képkocka kötegeit.
## FIGYELEM: felvétel közben csak rajzolt alakzat készülhet — a szöveg (ftxt) és a textúra (tex)
## közvetlenül a vászonra megy, így azok nem gyorsítótárazhatók.
func rec_begin() -> void:
	_rec_stash.append([_bp, _bc, _bi])
	_bp = PackedVector2Array()
	_bc = PackedColorArray()
	_bi = PackedInt32Array()
	recording = true
	save()
	xf = Transform2D.IDENTITY
	alpha = 1.0


## A felvételt "háromszög-levessé" alakítjuk (minden háromszögnek saját három csúcsa lesz).
## Így visszajátszáskor nem kell indexeket eltolni — az kockánkénti GDScript-ciklust jelentene.
func rec_end() -> Array:
	var n := _bi.size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(n)
	cols.resize(n)
	for i in n:
		var k := _bi[i]
		pts[i] = _bp[k]
		cols[i] = _bc[k]
	var r := [pts, cols]
	var s: Array = _rec_stash.pop_back()
	_bp = s[0]
	_bc = s[1]
	_bi = s[2]
	recording = not _rec_stash.is_empty()
	restore()
	return r


# ── általános rajz-gyorsítótár: kulcs -> felvett háló ──
static var _rec_cache := {}


func rec_cached(key: Variant, builder: Callable) -> Array:
	var r: Variant = _rec_cache.get(key)
	if r == null:
		if _rec_cache.size() > 2000:
			_rec_cache.clear()
		rec_begin()
		builder.call()
		r = rec_end()
		_rec_cache[key] = r
	return r


## gyorsítótárazott rajz kirakása: a (0,0) körül felvett háló a megadott pontra tolva
func blit(key: Variant, builder: Callable, x: float, y: float) -> void:
	replay(rec_cached(key, builder), Transform2D(0.0, Vector2(x, y)))


## Ugyanaz, de megadott erősséggel. Olyan (lüktető) színátmenetekhez való, amelyeknek MINDEN
## színpontja arányosan halványul: ilyenkor elég teljes erővel felvenni a hálót, és a
## pillanatnyi erősséget alfaként ráadni — a kép pontosan ugyanaz, de nem kell képkockánként
## újraszámolni a színátmenet több száz csúcsát.
func blit_a(key: Variant, builder: Callable, x: float, y: float, a: float) -> void:
	if a <= 0.003:
		return
	var keep := alpha
	alpha = a
	replay(rec_cached(key, builder), Transform2D(0.0, Vector2(x, y)))
	alpha = keep


## Növekvő számsor (0,1,2,...): egy darabja pont a "base, base+1, base+2, ..." indexlistát adja,
## így a visszajátszáshoz egyetlen GDScript-ciklus sem kell.
static var _seq := PackedInt32Array()


static func _seq_at_least(n: int) -> void:
	var o := _seq.size()
	if o >= n:
		return
	_seq.resize(maxi(n, o * 2))
	for i in range(o, _seq.size()):
		_seq[i] = i


## A felvett háló a MOSTANI kötegbe kerül, nem külön rajzhívásként: egy köteg átadása a
## grafikus meghajtónak (ANGLE/D3D11) nagyságrendekkel drágább, mint néhány ezer csúcs hozzáfűzése.
## A felvétel háromszög-levesként (index nélkül) áll, ezért az összefűzés csak tömbmásolás.
func replay(r: Array, t: Transform2D) -> void:
	var pts: PackedVector2Array = r[0]
	var n := pts.size()
	if n == 0:
		return
	var base := _bp.size()
	_bp.append_array((xf * t) * pts)
	if alpha >= 0.999:
		_bc.append_array(r[1])
	else:
		for cc in (r[1] as PackedColorArray):
			_bc.append(Color(cc.r, cc.g, cc.b, cc.a * alpha))
	_seq_at_least(base + n)
	_bi.append_array(_seq.slice(base, base + n))


## bp + moveTo + lineTo + stroke
func line(x0: float, y0: float, x1: float, y1: float) -> void:
	bp()
	mt(x0, y0)
	lt(x1, y1)
	stroke()


## zárt sokszög kitöltése (bp, mt, lt..., cp, fill)
func poly(coords: Array) -> void:
	bp()
	mt(coords[0], coords[1])
	var i := 2
	while i < coords.size():
		lt(coords[i], coords[i + 1])
		i += 2
	cp()
	fill()


# ══════════ GYORSÍTÓTÁRAZOTT ALAPFORMÁK ══════════
## Egy lekerekített téglalap kirajzolása (útvonal, háromszögelés, élsimítás) sok apró lépés.
## A listákban ugyanaz a forma sokszor ismétlődik, ezért egyszer vesszük fel, utána csak eltoljuk.
func rrect_fill_c(x: float, y: float, w: float, h: float, r: float, colr: Variant) -> void:
	var cc: Variant = col(colr)
	if cc is Grad:   # színátmenetet nem gyorsítótárazunk (minden hívásnál új objektum)
		fs(colr)
		rrect(x, y, w, h, r)
		fill()
		return
	blit("rf|%d|%d|%d|%s" % [int(roundf(w * 2)), int(roundf(h * 2)), int(roundf(r * 2)), cc],
		func() -> void:
			fs(colr)
			rrect(0, 0, w, h, r)
			fill(), x, y)


func rrect_stroke_c(x: float, y: float, w: float, h: float, r: float, lwv: float, colr: Variant) -> void:
	var cc: Variant = col(colr)
	if cc is Grad:
		ss(colr)
		lw(lwv)
		rrect(x, y, w, h, r)
		stroke()
		return
	blit("rs|%d|%d|%d|%d|%s" % [int(roundf(w * 2)), int(roundf(h * 2)), int(roundf(r * 2)), int(roundf(lwv * 4)), cc],
		func() -> void:
			ss(colr)
			lw(lwv)
			rrect(0, 0, w, h, r)
			stroke(), x, y)


## panel (háttér + keret) gyorsítótárból
func panel_c(x: float, y: float, w: float, h: float, bg: Variant, border: Variant, bw := 2.0, r := 8.0) -> void:
	rrect_fill_c(x, y, w, h, r, bg)
	rrect_stroke_c(x, y, w, h, r, bw, border)


# ══════════ SEGÉDEK (panel, bar, orna) ══════════
func panel(x: float, y: float, w: float, h: float, bg: Variant, border: Variant, bw := 2.0, r := 8.0) -> void:
	fs(bg)
	rrect(x, y, w, h, r)
	fill()
	ss(border)
	lw(bw)
	stroke()


func bar(x: float, y: float, w: float, h: float, pct: float, full: Variant, empty: Variant, r := 3.0) -> void:
	fs(empty)
	rrect(x, y, w, h, r)
	fill()
	if pct > 0.0:
		fs(full)
		rrect(x, y, maxf(2.0, w * pct), h, r)
		fill()


func orna(x: float, y: float, w: float, c: Variant) -> void:
	ss(c)
	lw(1)
	bp()
	mt(x, y)
	lt(x + w, y)
	stroke()
	fs(c)
	bp()
	arc(x, y, 2.5, 0, 7)
	fill()
	bp()
	arc(x + w, y, 2.5, 0, 7)
	fill()


## Egyszerű elmosott "árnyék" / ragyogás (canvas shadowBlur helyett): táguló, halvány lekerekített téglalapok
func soft_shadow(x: float, y: float, w: float, h: float, r: float, c: Color, blur: float, oy := 0.0) -> void:
	var steps := 6
	for i in steps:
		var e := blur * (float(steps - i) / steps)
		var cc := c
		cc.a = c.a * 0.22
		fs(cc)
		rrect(x - e * 0.5, y - e * 0.5 + oy, w + e, h + e, r + e * 0.5)
		fill()
