class_name Sprites2
extends RefCounted
## Gorgona rajzai: a négy zóna ura (két fázissal), a város saját lényei, a Műtőterem lakói
## (Nora és a Megnyúzott Próféta), a feljegyzés-lap, és a bevezető / befejezés háttérképei.
## Ugyanaz a rajzoló (Cv) és ugyanaz a lépték, mint a sprites.gd-ben: s = méret / 30.

const KEYS := ["rat", "nurse", "scalpel", "spore", "rust_worm", "dr_karel", "symbiote", "weaver"]
const REZ := "#c8843a"      # réz
const ROZSDA := "#8a4a22"
const HUS := "#b8424e"
const ARANY := "#e0b050"


static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Cv.rgba(r, g, b, a)


static func vil(cc: Variant, f: float) -> Color:
	return Skins.vil(cc, f)


static func sot(cc: Variant, f: float) -> Color:
	return Skins.sot(cc, f)


## "rust_worm#2" → a Rozsdaféreg második fázisa
static func has(key: String) -> bool:
	return key.get_slice("#", 0) in KEYS


static func draw(c: Cv, key: String, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var k := key.get_slice("#", 0)
	var p2 := key.ends_with("#2")
	match k:
		"rat": rat(c, cx, cy, sz, t, sd)
		"nurse": nurse(c, cx, cy, sz, t, sd)
		"scalpel": scalpel(c, cx, cy, sz, t, sd)
		"spore": spore(c, cx, cy, sz, t, sd)
		"rust_worm": rust_worm(c, cx, cy, sz, t, sd, p2)
		"dr_karel": dr_karel(c, cx, cy, sz, t, sd, p2)
		"symbiote": symbiote(c, cx, cy, sz, t, sd, p2)
		"weaver": weaver(c, cx, cy, sz, t, sd, p2)


static func _bob(t: float, sd: float) -> float:
	return sin(t * 0.08 + sd) * 1.5


static func _rivet(c: Cv, x: float, y: float, r: float) -> void:
	c.fs("#3a2410"); c.circ(x, y, r)
	c.fs("#f0c080"); c.circ(x - r * 0.25, y - r * 0.3, r * 0.45)


# ══════════ GŐZPATKÁNY ══════════
static func rat(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	const SZ := "#6a5a50"
	c.save(); c.translate(cx, cy + _bob(t, sd) * 0.6)
	# farok
	c.ss("#c08a80"); c.lw(1.3 * s)
	c.bp(); c.mt(-7.0 * s, 6.0 * s); c.qt(-13.0 * s, 9.0 * s + sin(t * 0.12 + sd) * 2 * s, -12.0 * s, 1.0 * s); c.stroke()
	# lábak
	c.fs(sot(SZ, 0.4))
	c.ell(-4.0 * s, 10.4 * s, 2.2 * s, 1.3 * s); c.ell(4.6 * s, 10.4 * s, 2.2 * s, 1.3 * s)
	# test
	c.fs(sot(SZ, 0.3)); c.ell(-0.6 * s, 5.2 * s, 8.4 * s, 5.6 * s)
	c.fs(SZ); c.ell(0, 4.6 * s, 7.6 * s, 4.8 * s)
	c.fs(vil(SZ, 0.2)); c.ell(1.6 * s, 3.0 * s, 4.2 * s, 2.2 * s)
	# réz kazán a hátán + kémény
	c.fs(sot(REZ, 0.35)); c.rrect(-6.4 * s, -3.6 * s, 8.4 * s, 6.4 * s, 2.4 * s); c.fill()
	c.fs(REZ); c.rrect(-6.0 * s, -3.8 * s, 7.6 * s, 5.6 * s, 2.2 * s); c.fill()
	c.fs(vil(REZ, 0.35)); c.rrect(-5.2 * s, -3.2 * s, 2.0 * s, 4.2 * s, 0.9 * s); c.fill()
	c.fs("#5a3a1a"); c.fill_rect(-3.4 * s, -6.8 * s, 2.0 * s, 3.4 * s)
	_rivet(c, -0.2 * s, -2.4 * s, 0.55 * s); _rivet(c, -0.2 * s, 0.6 * s, 0.55 * s)
	# gőzpamacs
	var g := fmod(t * 0.03 + sd, 1.0)
	c.fs(rgba(230, 230, 220, 0.5 * (1.0 - g))); c.circ(-2.4 * s, (-8.0 - g * 6.0) * s, (1.4 + g * 2.2) * s)
	# fej
	c.fs(sot(SZ, 0.2)); c.poly([4.0 * s, 0.6 * s, 12.6 * s, 4.8 * s, 5.0 * s, 8.4 * s])
	c.fs(SZ); c.ell(5.4 * s, 3.8 * s, 3.8 * s, 3.6 * s)
	c.fs("#e0a0a0"); c.circ(12.4 * s, 4.9 * s, 0.9 * s)
	c.fs(sot(SZ, 0.1)); c.circ(3.8 * s, 0.2 * s, 2.2 * s)
	c.fs("#d09090"); c.circ(3.9 * s, 0.4 * s, 1.2 * s)
	c.fs(rgba(255, 90, 40, 0.35)); c.circ(7.6 * s, 3.2 * s, 2.0 * s)
	c.fs("#ff7030"); c.circ(7.6 * s, 3.2 * s, 0.95 * s)
	c.fs("#fff0c0"); c.circ(7.9 * s, 2.9 * s, 0.35 * s)
	# metszőfogak
	c.fs("#f0e8d0"); c.poly([10.2 * s, 6.0 * s, 11.2 * s, 6.0 * s, 10.7 * s, 7.8 * s])
	c.restore()


# ══════════ AUTOMATA-ÁPOLÓ ══════════
static func nurse(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	const BR := "#b89048"
	c.save(); c.translate(cx, cy + _bob(t, sd))
	# kúpos sárgaréz szoknya (kerekeken gurul)
	c.fs("#2a2018"); c.ell(-4.0 * s, 12.0 * s, 1.8 * s, 1.4 * s); c.ell(4.0 * s, 12.0 * s, 1.8 * s, 1.4 * s)
	c.fs(sot(BR, 0.4)); c.poly([-4.4 * s, 1.0 * s, 4.4 * s, 1.0 * s, 8.0 * s, 11.6 * s, -8.0 * s, 11.6 * s])
	c.fs(BR); c.poly([-3.6 * s, 1.0 * s, 4.0 * s, 1.0 * s, 6.6 * s, 11.0 * s, -6.2 * s, 11.0 * s])
	c.fs(vil(BR, 0.3)); c.poly([0.6 * s, 1.4 * s, 3.4 * s, 1.4 * s, 5.4 * s, 10.6 * s, 2.6 * s, 10.6 * s])
	c.ss(sot(BR, 0.5)); c.lw(0.6 * s)
	c.line(-5.6 * s, 7.4 * s, 6.0 * s, 7.4 * s); c.line(-4.8 * s, 4.2 * s, 5.0 * s, 4.2 * s)
	# fehér kötény piros kereszttel
	c.fs("#e8e4d8"); c.rrect(-2.8 * s, -4.0 * s, 5.6 * s, 6.4 * s, 1.0 * s); c.fill()
	c.fs("#c03030"); c.fill_rect(-0.6 * s, -2.8 * s, 1.2 * s, 4.0 * s); c.fill_rect(-2.0 * s, -1.4 * s, 4.0 * s, 1.2 * s)
	# karok: balról csipesz, jobbról fecskendő
	c.ss(sot(BR, 0.25)); c.lw(1.5 * s)
	c.line(-3.0 * s, -3.0 * s, -8.0 * s, 1.6 * s)
	var sw := sin(t * 0.1 + sd) * 1.2 * s
	c.line(3.0 * s, -3.0 * s, 8.6 * s, -1.0 * s + sw)
	c.fs("#d8e8f0"); c.rrect(8.0 * s, -2.4 * s + sw, 5.6 * s, 2.4 * s, 0.6 * s); c.fill()
	c.fs(rgba(120, 230, 150, 0.9)); c.fill_rect(8.6 * s, -1.9 * s + sw, 3.0 * s, 1.4 * s)
	c.ss("#f0f4f8"); c.lw(0.6 * s); c.line(13.6 * s, -1.2 * s + sw, 16.6 * s, -1.2 * s + sw)
	c.fs("#8a8a90"); c.poly([-8.0 * s, 1.0 * s, -10.6 * s, 3.4 * s, -8.6 * s, 3.0 * s])
	# fej: sárgaréz búra egyetlen lencsével
	c.fs(sot(BR, 0.35)); c.ell(0, -8.6 * s, 4.8 * s, 4.6 * s)
	c.fs(BR); c.ell(0.4 * s, -9.0 * s, 4.2 * s, 4.0 * s)
	c.fs("#1a1410"); c.circ(0.6 * s, -8.8 * s, 2.3 * s)
	var gl := 0.6 + 0.4 * sin(t * 0.14 + sd)
	c.fs(rgba(255, 70, 50, 0.35 * gl)); c.circ(0.6 * s, -8.8 * s, 3.2 * s)
	c.fs(rgba(255, 90, 60, gl)); c.circ(0.6 * s, -8.8 * s, 1.3 * s)
	c.fs("#fff0e0"); c.circ(1.0 * s, -9.2 * s, 0.45 * s)
	# ápolói fityula
	c.fs("#f4f0e6"); c.poly([-4.4 * s, -11.6 * s, 4.8 * s, -11.6 * s, 3.6 * s, -15.0 * s, -3.2 * s, -15.0 * s])
	c.fs("#c03030"); c.fill_rect(-0.4 * s, -14.4 * s, 1.0 * s, 2.4 * s); c.fill_rect(-1.1 * s, -13.7 * s, 2.4 * s, 1.0 * s)
	c.restore()


# ══════════ LEBEGŐ SZIKE ══════════
static func scalpel(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	c.save(); c.translate(cx, cy - 2.0 * s + sin(t * 0.11 + sd) * 2.4 * s)
	c.rotate(-0.5 + sin(t * 0.07 + sd) * 0.18)
	var gl := 0.5 + 0.5 * sin(t * 0.13 + sd)
	c.fs(rgba(190, 240, 235, 0.14 + 0.08 * gl)); c.ell(0, 0, 5.4 * s, 13.6 * s)
	# sárgaréz nyél
	c.fs(sot(REZ, 0.4)); c.rrect(-1.6 * s, 1.0 * s, 3.2 * s, 11.0 * s, 1.2 * s); c.fill()
	c.fs(REZ); c.rrect(-1.2 * s, 1.0 * s, 2.2 * s, 10.6 * s, 1.0 * s); c.fill()
	c.ss(sot(REZ, 0.5)); c.lw(0.5 * s)
	for i in 4:
		c.line(-1.2 * s, (3.4 + i * 2.0) * s, 1.0 * s, (3.4 + i * 2.0) * s)
	# penge
	c.fs("#8a98a8"); c.poly([-1.6 * s, 1.0 * s, 1.6 * s, 1.0 * s, 2.6 * s, -6.0 * s, 0.2 * s, -13.0 * s, -1.6 * s, -4.0 * s])
	c.fs("#e4ecf4"); c.poly([0.0, 0.6 * s, 1.4 * s, 0.6 * s, 2.2 * s, -6.0 * s, 0.3 * s, -12.2 * s])
	c.fs(rgba(255, 255, 255, 0.9)); c.poly([1.6 * s, -3.0 * s, 2.3 * s, -6.2 * s, 1.2 * s, -9.0 * s])
	# a "szeme": vörös kristály a markolat tövében
	c.fs(rgba(255, 60, 60, 0.4 * gl)); c.circ(0, 1.2 * s, 2.4 * s)
	c.fs("#ff5050"); c.circ(0, 1.2 * s, 1.1 * s)
	c.restore()


# ══════════ TÜDŐSPÓRA ══════════
static func spore(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var br := 1.0 + 0.07 * sin(t * 0.09 + sd)
	c.save(); c.translate(cx, cy + _bob(t, sd) * 0.5)
	# gyökérlábak
	c.ss("#5a3a40"); c.lw(1.4 * s)
	for i in 4:
		var xx := (-6.0 + i * 4.0) * s
		c.bp(); c.mt(xx * 0.6, 5.0 * s); c.qt(xx, 8.0 * s, xx * 1.25, 12.0 * s); c.stroke()
	# két lélegző tüdőlebeny
	c.save(); c.scale(br, br)
	c.fs(sot(HUS, 0.4)); c.ell(-4.4 * s, 0.4 * s, 6.2 * s, 8.2 * s, 0.25); c.ell(4.4 * s, 0.4 * s, 6.2 * s, 8.2 * s, -0.25)
	c.fs("#d06a78"); c.ell(-4.0 * s, -0.2 * s, 5.2 * s, 7.2 * s, 0.25); c.ell(4.6 * s, -0.2 * s, 5.2 * s, 7.2 * s, -0.25)
	c.fs("#f09aa4"); c.ell(-5.2 * s, -2.4 * s, 2.2 * s, 3.4 * s, 0.25); c.ell(6.0 * s, -2.6 * s, 2.0 * s, 3.2 * s, -0.25)
	c.ss(rgba(110, 30, 50, 0.7)); c.lw(0.6 * s)
	c.bp(); c.mt(-1.2 * s, -4.0 * s); c.qt(-5.0 * s, 0, -4.0 * s, 5.0 * s); c.stroke()
	c.bp(); c.mt(1.2 * s, -4.0 * s); c.qt(5.0 * s, 0, 4.0 * s, 5.0 * s); c.stroke()
	c.restore()
	# légcső + réz bilincs
	c.fs("#e8c8b8"); c.rrect(-1.3 * s, -11.6 * s, 2.6 * s, 6.4 * s, 1.0 * s); c.fill()
	c.fs(REZ); c.fill_rect(-1.8 * s, -8.6 * s, 3.6 * s, 1.4 * s)
	# világító spórák
	for i in 6:
		var a := i * 1.05 + t * 0.02 + sd
		var rr := (5.0 + 2.5 * sin(a * 1.7)) * s
		var gl := 0.5 + 0.5 * sin(t * 0.1 + i)
		c.fs(rgba(210, 240, 90, 0.35 + 0.5 * gl)); c.circ(cos(a) * rr, sin(a) * rr * 0.9, (0.6 + 0.4 * gl) * s)
	c.restore()


# ══════════ I. A ROZSDAFÉREG ══════════
## Óriási féreg kazánlemez- és csontszelvényekből. A 2. fázisban leszakad a páncélja:
## lüktető belső szervek látszanak, és savas vér csorog belőle.
static func rust_worm(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float, p2 := false) -> void:
	var s := sz * 1.5 / 30.0
	c.save(); c.translate(cx, cy)
	# a test: öt szelvény hullámzó ívben, hátulról előre
	for i in range(5, 0, -1):
		var ph := t * 0.07 + i * 0.9
		var x := (-3.5 + i * -2.6 + 9.0) * s + cos(ph) * 1.6 * s - 6.0 * s
		var y := (9.0 - i * 0.4) * s + sin(ph) * 1.8 * s
		var r := (7.6 - i * 0.75) * s
		if p2:
			var pu := 1.0 + 0.08 * sin(t * 0.2 + i)
			c.fs(sot(HUS, 0.45)); c.circ(x, y, r)
			c.fs(HUS); c.circ(x + 0.4 * s, y - 0.4 * s, r * 0.86 * pu)
			c.fs("#e87a80"); c.ell(x + r * 0.3, y - r * 0.35, r * 0.3, r * 0.22)
			c.ss(rgba(90, 16, 30, 0.8)); c.lw(0.7 * s)
			c.bp(); c.arc(x, y, r * 0.55, 0.4, 2.6); c.stroke()
			# megmaradt lemezfoszlány
			c.fs(ROZSDA); c.poly([x - r, y - r * 0.2, x - r * 0.5, y - r * 0.9, x - r * 0.1, y - r * 0.5])
		else:
			c.fs(sot(ROZSDA, 0.5)); c.circ(x, y, r)
			c.fs(ROZSDA); c.circ(x + 0.3 * s, y - 0.4 * s, r * 0.9)
			c.fs(vil(ROZSDA, 0.28)); c.ell(x + r * 0.3, y - r * 0.4, r * 0.38, r * 0.26)
			# csontbordák + szegecsek
			c.ss("#d8cfb4"); c.lw(1.1 * s)
			c.bp(); c.arc(x, y, r * 0.92, PI * 1.05, PI * 1.95); c.stroke()
			_rivet(c, x - r * 0.5, y + r * 0.2, 0.6 * s); _rivet(c, x + r * 0.5, y + r * 0.2, 0.6 * s)
	# fej: kerek, fogas száj kazánajtóval
	var hb := sin(t * 0.07) * 1.4 * s
	var hx := 4.6 * s
	var hy := -3.0 * s + hb
	var hc := HUS if p2 else ROZSDA
	c.fs(sot(hc, 0.5)); c.circ(hx, hy, 9.4 * s)
	c.fs(hc); c.circ(hx + 0.4 * s, hy - 0.5 * s, 8.6 * s)
	c.fs(vil(hc, 0.25)); c.ell(hx + 3.4 * s, hy - 4.4 * s, 3.4 * s, 2.2 * s)
	if not p2:
		c.ss("#d8cfb4"); c.lw(1.3 * s)
		c.bp(); c.arc(hx, hy, 8.4 * s, PI * 1.1, PI * 1.9); c.stroke()
		for i in 5:
			var a := PI * 1.15 + i * PI * 0.175
			_rivet(c, hx + cos(a) * 7.0 * s, hy + sin(a) * 7.0 * s, 0.6 * s)
	# torok + izzás
	var gl := 0.6 + 0.4 * sin(t * 0.12)
	c.fs("#1a0a06"); c.circ(hx + 0.6 * s, hy + 1.0 * s, 5.2 * s)
	c.fs(rgba(255, 120, 30, 0.55 * gl) if not p2 else rgba(180, 230, 50, 0.6 * gl)); c.circ(hx + 0.6 * s, hy + 1.4 * s, 3.4 * s)
	c.fs(rgba(255, 220, 140, 0.8 * gl) if not p2 else rgba(230, 255, 150, 0.8 * gl)); c.circ(hx + 0.6 * s, hy + 1.6 * s, 1.5 * s)
	# fogkoszorú
	c.fs("#efe6cc")
	for i in 10:
		var a := i / 10.0 * TAU + t * 0.01
		var ox := hx + 0.6 * s + cos(a) * 5.2 * s
		var oy := hy + 1.0 * s + sin(a) * 5.2 * s
		c.poly([ox + cos(a + 1.57) * 0.9 * s, oy + sin(a + 1.57) * 0.9 * s, ox - cos(a + 1.57) * 0.9 * s, oy - sin(a + 1.57) * 0.9 * s,
			ox - cos(a) * 2.6 * s, oy - sin(a) * 2.6 * s])
	# szellőzők: gőz (1. fázis) / sav (2. fázis)
	for i in 2:
		var vx := hx + (-6.5 + i * 13.0) * s
		c.fs("#3a2a1a"); c.rrect(vx - 1.2 * s, hy - 9.6 * s, 2.4 * s, 3.4 * s, 0.6 * s); c.fill()
		var g := fmod(t * 0.025 + i * 0.5, 1.0)
		if p2:
			c.fs(rgba(170, 230, 40, 0.8 * (1.0 - g))); c.circ(vx, hy - 6.0 * s + g * 9.0 * s, (1.0 + g * 0.6) * s)
		else:
			c.fs(rgba(240, 235, 220, 0.55 * (1.0 - g))); c.circ(vx, hy - 10.0 * s - g * 7.0 * s, (1.6 + g * 3.0) * s)
	c.restore()


# ══════════ II. KAREL DOKTOR, A SELYEMMASZKOS ══════════
## Aranyozott selyemruhában lebegő orvos hat mechanikus karral. A 2. fázisban
## vértranszfúziós csövek kötik a mennyezethez.
static func dr_karel(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float, p2 := false) -> void:
	var s := sz * 1.3 / 30.0
	const SELYEM := "#c9a040"
	c.save(); c.translate(cx, cy - 2.0 * s + sin(t * 0.06 + sd) * 2.0 * s)
	if p2:
		# transzfúziós csövek felfelé, bennük lüktető vér
		for i in 3:
			var tx := (-6.0 + i * 6.0) * s
			c.ss("#5a1018"); c.lw(1.6 * s)
			c.bp(); c.mt(tx * 0.5, -6.0 * s); c.qt(tx * 1.6, -14.0 * s, tx * 1.2, -24.0 * s); c.stroke()
			var g := fmod(t * 0.03 + i * 0.33, 1.0)
			c.fs(rgba(255, 60, 60, 0.9)); c.circ(tx * (0.5 + g * 0.8), (-6.0 - g * 18.0) * s, 1.1 * s)
	# hat mechanikus kar (háromszög-ívben a hát mögül)
	for side in [-1, 1]:
		for i in 3:
			var a := -0.5 + i * 0.62 + sin(t * 0.08 + i + sd) * 0.14
			var ex: float = side * (9.0 + i * 2.6) * s * cos(a * 0.6)
			var ey := (-9.0 + i * 7.4) * s + sin(t * 0.09 + i * 2.0) * 1.2 * s
			var mx: float = side * 7.4 * s
			var my := (-7.0 + i * 3.4) * s
			c.ss(sot(REZ, 0.35)); c.lw(1.5 * s)
			c.bp(); c.mt(side * 2.4 * s, -4.0 * s); c.lt(mx, my); c.lt(ex, ey); c.stroke()
			c.fs(REZ); c.circ(mx, my, 1.1 * s)
			# szike a kar végén
			c.fs("#dfe8f0"); c.poly([ex, ey, ex + side * 4.6 * s, ey + 0.9 * s, ex + side * 0.6 * s, ey + 1.8 * s])
			c.fs("#ffffff"); c.poly([ex + side * 1.0 * s, ey + 0.4 * s, ex + side * 4.4 * s, ey + 0.9 * s, ex + side * 1.4 * s, ey + 1.0 * s])
	# lefelé keskenyedő selyemruha (láb nélkül lebeg)
	c.fs(sot(SELYEM, 0.5)); c.poly([-6.4 * s, -5.0 * s, 6.4 * s, -5.0 * s, 4.6 * s, 8.0 * s, 0, 16.0 * s, -4.6 * s, 8.0 * s])
	c.fs(SELYEM); c.poly([-5.4 * s, -5.0 * s, 5.8 * s, -5.0 * s, 4.0 * s, 7.6 * s, 0.4 * s, 14.6 * s, -3.8 * s, 7.6 * s])
	c.fs(vil(SELYEM, 0.35)); c.poly([1.0 * s, -4.6 * s, 4.8 * s, -4.6 * s, 3.4 * s, 7.0 * s, 1.0 * s, 12.0 * s])
	# arany hímzés + gombsor
	c.ss(rgba(255, 236, 170, 0.85)); c.lw(0.6 * s)
	c.bp(); c.mt(-4.6 * s, 0); c.qt(0, 3.0 * s, 4.8 * s, 0); c.stroke()
	c.bp(); c.mt(-3.6 * s, 6.0 * s); c.qt(0, 8.6 * s, 3.8 * s, 6.0 * s); c.stroke()
	c.fs("#fff0c0")
	for i in 3:
		c.circ(0, (-2.6 + i * 2.6) * s, 0.55 * s)
	# magas gallér
	c.fs(sot(SELYEM, 0.3)); c.poly([-6.0 * s, -5.0 * s, -3.0 * s, -10.6 * s, 0, -5.6 * s, 3.0 * s, -10.6 * s, 6.0 * s, -5.0 * s])
	# selyemmaszk: sima, fehér arc keskeny szemréssel
	c.fs("#b8b0a0"); c.ell(0, -11.6 * s, 4.4 * s, 5.4 * s)
	c.fs("#f4f0e8"); c.ell(0.3 * s, -11.8 * s, 3.9 * s, 4.9 * s)
	c.fs("#ffffff"); c.ell(1.4 * s, -13.6 * s, 1.6 * s, 2.0 * s)
	var gl := 0.6 + 0.4 * sin(t * 0.1)
	var ec := rgba(255, 50, 50, gl) if p2 else rgba(40, 20, 20, 1.0)
	c.fs(ec)
	c.poly([-2.8 * s, -12.4 * s, -0.8 * s, -11.8 * s, -2.6 * s, -11.4 * s])
	c.poly([3.0 * s, -12.4 * s, 1.0 * s, -11.8 * s, 2.8 * s, -11.4 * s])
	c.ss("#8a1a20"); c.lw(0.5 * s)
	c.bp(); c.mt(-1.2 * s, -8.8 * s); c.qt(0, -8.2 * s, 1.4 * s, -8.8 * s); c.stroke()
	# aranyszalag a maszk tetején
	c.fs(ARANY); c.poly([-3.6 * s, -15.2 * s, 3.8 * s, -15.2 * s, 2.6 * s, -17.0 * s, -2.4 * s, -17.0 * s])
	c.restore()


# ══════════ III. A SZIMBIÓTA ANYA ══════════
## Fába, csontba és fémbe zárt női alak, gyökérszerű erekkel a mennyezethez nőve.
static func symbiote(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float, p2 := false) -> void:
	var s := sz * 1.45 / 30.0
	const FA := "#5a3a2a"
	c.save(); c.translate(cx, cy)
	var br := sin(t * 0.06 + sd)
	# erek a mennyezet felé
	for i in 7:
		var tx := (-13.0 + i * 4.4) * s
		c.ss(rgba(150, 40, 60, 0.85) if i % 2 == 0 else rgba(110, 150, 60, 0.85)); c.lw((1.8 - absf(3 - i) * 0.2) * s)
		c.bp(); c.mt(tx * 0.35, -9.0 * s); c.bt(tx * 0.6, -15.0 * s, tx * 1.3 + br * s, -17.0 * s, tx * 1.15, -26.0 * s); c.stroke()
	# fakéreg-burok (szoknyaszerű gyökértörzs)
	c.fs(sot(FA, 0.5)); c.poly([-7.0 * s, -4.0 * s, 7.0 * s, -4.0 * s, 12.0 * s, 13.0 * s, -12.0 * s, 13.0 * s])
	c.fs(FA); c.poly([-6.0 * s, -4.0 * s, 6.4 * s, -4.0 * s, 10.4 * s, 12.4 * s, -10.0 * s, 12.4 * s])
	c.fs(vil(FA, 0.2)); c.poly([1.6 * s, -3.6 * s, 5.6 * s, -3.6 * s, 9.0 * s, 12.0 * s, 4.6 * s, 12.0 * s])
	c.ss(sot(FA, 0.6)); c.lw(0.7 * s)
	for i in 4:
		var xx := (-6.0 + i * 4.0) * s
		c.bp(); c.mt(xx * 0.6, -2.0 * s); c.qt(xx * 0.9, 5.0 * s, xx * 1.4, 12.0 * s); c.stroke()
	# gyökérlábak a padlón
	c.fs(sot(FA, 0.3))
	for i in 5:
		var xx := (-11.0 + i * 5.5) * s
		c.poly([xx - 1.4 * s, 12.0 * s, xx + 1.4 * s, 12.0 * s, xx + (i - 2) * 1.4 * s, 15.6 * s])
	# torzó: hús + fémbordák
	c.fs(sot(HUS, 0.4)); c.ell(0, -5.0 * s, 5.8 * s, 7.0 * s)
	c.fs("#d48a90"); c.ell(0.4 * s, -5.4 * s, 5.0 * s, 6.2 * s)
	c.ss("#c8ccd4"); c.lw(1.0 * s)
	for i in 3:
		var yy := (-7.6 + i * 2.6) * s
		c.bp(); c.mt(-4.6 * s, yy); c.qt(0, yy + 1.6 * s, 4.8 * s, yy); c.stroke()
	# a szív: zölden lüktet (2. fázisban vörösen, gyorsabban)
	var pu := 0.5 + 0.5 * sin(t * (0.22 if p2 else 0.11))
	var hc := rgba(255, 70, 60, 0.4 + 0.4 * pu) if p2 else rgba(140, 240, 110, 0.35 + 0.4 * pu)
	c.fs(hc); c.circ(0.2 * s, -4.6 * s, (3.0 + pu * 1.2) * s)
	c.fs(rgba(255, 240, 220, 0.9)); c.circ(0.2 * s, -4.6 * s, 1.0 * s)
	# karok: csontos ágak széttárva
	c.ss("#d8cfb4"); c.lw(1.5 * s)
	c.bp(); c.mt(-4.6 * s, -8.0 * s); c.qt(-10.0 * s, -9.0 * s + br * s, -13.0 * s, -3.0 * s + br * 1.6 * s); c.stroke()
	c.bp(); c.mt(4.8 * s, -8.0 * s); c.qt(10.0 * s, -9.0 * s - br * s, 13.0 * s, -3.0 * s - br * 1.6 * s); c.stroke()
	c.lw(0.8 * s)
	for side in [-1, 1]:
		var hx: float = side * 13.0 * s
		var hy: float = -3.0 * s + side * -br * 1.6 * s
		for i in 3:
			c.line(hx, hy, hx + side * (1.6 + i * 0.6) * s, hy + (-1.6 + i * 1.8) * s)
	# fej: sápadt arc fémkoronával, hajként lecsüngő erekkel
	c.ss(rgba(140, 40, 60, 0.9)); c.lw(1.0 * s)
	for i in 5:
		var hx2 := (-4.0 + i * 2.0) * s
		c.bp(); c.mt(hx2 * 0.8, -15.0 * s); c.qt(hx2 * 1.5, -11.0 * s, hx2 * 1.2 + br * 0.5 * s, -6.0 * s); c.stroke()
	c.fs("#b4a898"); c.ell(0, -14.0 * s, 3.6 * s, 4.4 * s)
	c.fs("#efe6da"); c.ell(0.3 * s, -14.2 * s, 3.1 * s, 3.9 * s)
	if p2:
		c.fs(rgba(255, 60, 50, 0.5)); c.ell(-1.3 * s, -14.4 * s, 1.6 * s, 1.2 * s); c.ell(1.6 * s, -14.4 * s, 1.6 * s, 1.2 * s)
		c.fs("#ff5040"); c.ell(-1.3 * s, -14.4 * s, 0.8 * s, 0.6 * s); c.ell(1.6 * s, -14.4 * s, 0.8 * s, 0.6 * s)
	else:
		c.ss("#5a4038"); c.lw(0.55 * s)
		c.bp(); c.mt(-2.1 * s, -14.4 * s); c.qt(-1.3 * s, -13.8 * s, -0.5 * s, -14.4 * s); c.stroke()
		c.bp(); c.mt(0.8 * s, -14.4 * s); c.qt(1.6 * s, -13.8 * s, 2.4 * s, -14.4 * s); c.stroke()
	c.fs("#8a3a40"); c.ell(0.2 * s, -11.8 * s, 0.9 * s, 0.4 * s)
	c.fs("#9aa0aa"); c.poly([-3.6 * s, -16.6 * s, -2.4 * s, -19.6 * s, -1.2 * s, -17.2 * s, 0.2 * s, -20.4 * s, 1.6 * s, -17.2 * s, 2.8 * s, -19.6 * s, 4.0 * s, -16.6 * s])
	c.restore()


# ══════════ IV. AZ ELSŐ KÁRPIT ══════════
## Arc nélküli fém-organikus lény: csápjai és hidraulikus karjai átszövik a termet.
## A Tükör-fázisban az arclemeze tükörré válik.
static func weaver(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float, p2 := false) -> void:
	var s := sz * 1.6 / 30.0
	const ACEL := "#5a5868"
	c.save(); c.translate(cx, cy - 1.0 * s + sin(t * 0.05 + sd) * 1.8 * s)
	# fényudvar
	var gl := 0.6 + 0.4 * sin(t * 0.08)
	c.fs(rgba(160, 220, 255, 0.10 * gl) if p2 else rgba(255, 200, 80, 0.10 * gl)); c.circ(0, 0, 17.0 * s)
	# csápok (szerves) és hidraulikus karok (gépi) felváltva, körben
	for i in 8:
		var a := i / 8.0 * TAU + sin(t * 0.04 + i) * 0.22
		var l := (15.0 + 2.5 * sin(t * 0.07 + i * 1.3)) * s
		var mx := cos(a + 0.35) * l * 0.55
		var my := sin(a + 0.35) * l * 0.55
		var ex := cos(a) * l
		var ey := sin(a) * l
		if i % 2 == 0:
			c.ss(sot(HUS, 0.2)); c.lw(2.2 * s)
			c.bp(); c.mt(cos(a) * 5.0 * s, sin(a) * 5.0 * s); c.qt(mx, my, ex, ey); c.stroke()
			c.ss("#e88a90"); c.lw(0.8 * s)
			c.bp(); c.mt(cos(a) * 5.0 * s, sin(a) * 5.0 * s); c.qt(mx, my, ex, ey); c.stroke()
		else:
			c.ss(sot(ACEL, 0.3)); c.lw(1.8 * s)
			c.bp(); c.mt(cos(a) * 5.0 * s, sin(a) * 5.0 * s); c.lt(mx, my); c.lt(ex, ey); c.stroke()
			c.fs(ARANY); c.circ(mx, my, 1.2 * s)
			c.fs("#dfe8f0"); c.poly([ex, ey, ex + cos(a) * 3.4 * s, ey + sin(a) * 3.4 * s, ex + cos(a + 1.5) * 1.0 * s, ey + sin(a + 1.5) * 1.0 * s])
	# törzs: acél tojás aranyszegéllyel
	c.fs(sot(ACEL, 0.5)); c.ell(0, 0.6 * s, 7.6 * s, 10.0 * s)
	c.fs(ACEL); c.ell(0.4 * s, 0, 6.8 * s, 9.2 * s)
	c.fs(vil(ACEL, 0.3)); c.ell(2.6 * s, -3.4 * s, 2.6 * s, 4.6 * s)
	c.ss(ARANY); c.lw(0.8 * s)
	c.bp(); c.ellipse(0.4 * s, 0, 6.8 * s, 9.2 * s, 0, 0, TAU); c.stroke()
	# a mag: szövőszék-szálak között izzó szív
	c.fs(rgba(255, 190, 70, 0.35 * gl)); c.circ(0.2 * s, 3.4 * s, 4.0 * s)
	c.fs(rgba(255, 150, 40, 0.95)); c.circ(0.2 * s, 3.4 * s, 1.9 * s)
	c.fs("#fff4d0"); c.circ(-0.2 * s, 3.0 * s, 0.8 * s)
	c.ss(rgba(255, 210, 120, 0.7)); c.lw(0.45 * s)
	for i in 5:
		var xx := (-3.6 + i * 1.8) * s
		c.line(xx, -0.4 * s, xx * 0.4 + 0.2 * s, 6.6 * s)
	# arc nélküli lemez (a Tükör-fázisban ezüst tükör, benne a hős színe villan)
	if p2:
		c.fs("#aab8c8"); c.ell(0.2 * s, -4.6 * s, 4.4 * s, 4.0 * s)
		c.fs("#e6f0fa"); c.ell(0.5 * s, -4.9 * s, 3.8 * s, 3.4 * s)
		var sh := sin(t * 0.09) * 2.0 * s
		c.fs(rgba(255, 255, 255, 0.9)); c.poly([-2.4 * s + sh, -7.4 * s, -1.0 * s + sh, -7.6 * s, -0.2 * s + sh, -2.0 * s, -1.6 * s + sh, -1.8 * s])
		c.fs(rgba(140, 200, 255, 0.5)); c.ell(1.4 * s, -4.0 * s, 1.6 * s, 2.0 * s)
	else:
		c.fs(sot(ARANY, 0.35)); c.ell(0.2 * s, -4.6 * s, 4.4 * s, 4.0 * s)
		c.fs(ARANY); c.ell(0.5 * s, -4.9 * s, 3.8 * s, 3.4 * s)
		c.fs(vil(ARANY, 0.4)); c.ell(1.8 * s, -6.2 * s, 1.4 * s, 1.5 * s)
	c.restore()


# ══════════ A MŰTŐTEREM LAKÓI (mellképek) ══════════
## Nora, a Csontkovács: vörös konty, hegesztőszemüveg, bőrkötény, gépi kar franciakulccsal.
static func nora(c: Cv, cx: float, cy: float, sz: float, t: float) -> void:
	var s := sz / 30.0
	const BOR := "#d8a888"
	const HAJ := "#b8402a"
	c.save(); c.translate(cx, cy + sin(t * 0.05) * 0.6 * s)
	# váll + bőrkötény
	c.fs("#3a4a5a"); c.poly([-11.0 * s, 15.0 * s, -9.0 * s, 3.0 * s, -3.0 * s, 0.6 * s, 3.0 * s, 0.6 * s, 9.0 * s, 3.0 * s, 11.0 * s, 15.0 * s])
	c.fs("#6a4426"); c.poly([-5.4 * s, 15.0 * s, -4.4 * s, 3.4 * s, 4.4 * s, 3.4 * s, 5.4 * s, 15.0 * s])
	c.fs("#8a5a32"); c.poly([0.6 * s, 3.8 * s, 4.0 * s, 3.8 * s, 4.8 * s, 15.0 * s, 1.6 * s, 15.0 * s])
	c.fs(REZ); c.circ(-4.0 * s, 4.4 * s, 0.9 * s); c.circ(4.0 * s, 4.4 * s, 0.9 * s)
	# gépi jobb kar + franciakulcs
	c.ss(sot(REZ, 0.3)); c.lw(2.6 * s)
	c.bp(); c.mt(9.0 * s, 4.0 * s); c.lt(13.0 * s, 9.0 * s); c.lt(11.0 * s, 1.0 * s + sin(t * 0.06) * s); c.stroke()
	c.fs(REZ); c.circ(13.0 * s, 9.0 * s, 1.7 * s)
	c.ss("#aab4c0"); c.lw(1.5 * s); c.line(11.0 * s, 1.0 * s, 12.4 * s, -8.0 * s)
	c.fs("#aab4c0"); c.poly([10.4 * s, -8.0 * s, 14.6 * s, -8.0 * s, 14.6 * s, -11.6 * s, 13.4 * s, -11.6 * s, 13.4 * s, -9.6 * s, 11.6 * s, -9.6 * s, 11.6 * s, -11.6 * s, 10.4 * s, -11.6 * s])
	# nyak + fej
	c.fs(sot(BOR, 0.2)); c.fill_rect(-1.8 * s, -3.0 * s, 3.6 * s, 4.6 * s)
	c.fs(sot(HAJ, 0.35)); c.ell(0, -8.4 * s, 6.4 * s, 6.8 * s)
	c.fs(BOR); c.ell(0.2 * s, -7.2 * s, 5.0 * s, 5.8 * s)
	c.fs(vil(BOR, 0.2)); c.ell(1.8 * s, -8.6 * s, 2.0 * s, 2.6 * s)
	# haj + konty
	c.fs(HAJ); c.poly([-5.6 * s, -7.0 * s, -5.0 * s, -13.0 * s, 0, -14.6 * s, 5.4 * s, -12.6 * s, 5.6 * s, -8.0 * s, 3.0 * s, -11.0 * s, -2.0 * s, -11.4 * s])
	c.fs(HAJ); c.circ(-1.0 * s, -15.6 * s, 2.8 * s)
	c.fs(vil(HAJ, 0.3)); c.circ(-0.2 * s, -16.4 * s, 1.2 * s)
	# hegesztőszemüveg a homlokon
	c.fs("#3a2a1a"); c.fill_rect(-5.4 * s, -11.6 * s, 10.8 * s, 1.6 * s)
	for xx in [-2.6, 2.6]:
		c.fs(REZ); c.circ(xx * s, -10.8 * s, 2.1 * s)
		c.fs("#4a6a70"); c.circ(xx * s, -10.8 * s, 1.4 * s)
		c.fs("#b0e0e0"); c.circ(xx * s + 0.4 * s, -11.2 * s, 0.5 * s)
	# arc: szem, szeplő, félmosoly, olajfolt
	c.fs("#2a1a12"); c.ell(-2.0 * s, -6.8 * s, 0.7 * s, 0.9 * s); c.ell(2.4 * s, -6.8 * s, 0.7 * s, 0.9 * s)
	c.fs(rgba(140, 80, 50, 0.6)); c.circ(-3.0 * s, -5.0 * s, 0.3 * s); c.circ(-2.0 * s, -4.6 * s, 0.3 * s); c.circ(3.0 * s, -5.0 * s, 0.3 * s)
	c.ss("#8a3a2a"); c.lw(0.6 * s)
	c.bp(); c.mt(-1.2 * s, -3.4 * s); c.qt(0.6 * s, -2.4 * s, 2.4 * s, -3.8 * s); c.stroke()
	c.fs(rgba(30, 24, 20, 0.5)); c.ell(3.4 * s, -3.6 * s, 1.2 * s, 0.6 * s, 0.5)
	c.restore()


## A Megnyúzott Próféta: bőr nélküli, csupasz izom, csuklya, a hátából csövek nőnek.
static func prophet(c: Cv, cx: float, cy: float, sz: float, t: float) -> void:
	var s := sz / 30.0
	const IZOM := "#a83038"
	c.save(); c.translate(cx, cy + sin(t * 0.04 + 1.3) * 0.6 * s)
	# csövek a háta mögött (a "dallam", amit hallgat)
	for i in 4:
		var px := (-11.0 + i * 7.4) * s
		c.fs(sot(REZ, 0.45)); c.fill_rect(px - 1.2 * s, -17.0 * s + absf(1.5 - i) * 3.0 * s, 2.4 * s, 26.0 * s)
		c.fs(REZ); c.fill_rect(px - 0.6 * s, -17.0 * s + absf(1.5 - i) * 3.0 * s, 1.0 * s, 26.0 * s)
	# rongyos csuha
	c.fs("#2a2228"); c.poly([-12.0 * s, 15.0 * s, -9.0 * s, 1.0 * s, -3.0 * s, -3.0 * s, 3.0 * s, -3.0 * s, 9.0 * s, 1.0 * s, 12.0 * s, 15.0 * s])
	c.fs("#3c3038"); c.poly([0.6 * s, -2.6 * s, 3.0 * s, -2.8 * s, 8.4 * s, 1.4 * s, 10.6 * s, 15.0 * s, 4.0 * s, 15.0 * s])
	# csupasz mellkas a csuha nyílásában: izomrostok
	c.fs(sot(IZOM, 0.3)); c.poly([-3.4 * s, -2.0 * s, 3.4 * s, -2.0 * s, 2.0 * s, 15.0 * s, -2.0 * s, 15.0 * s])
	c.ss(rgba(240, 150, 140, 0.55)); c.lw(0.5 * s)
	for i in 5:
		c.line((-2.6 + i * 1.3) * s, -1.0 * s, (-1.6 + i * 0.8) * s, 14.0 * s)
	# csuklya
	c.fs("#1e181e"); c.poly([-7.4 * s, -1.0 * s, -6.6 * s, -12.0 * s, 0, -17.6 * s, 6.6 * s, -12.0 * s, 7.4 * s, -1.0 * s, 0, -3.4 * s])
	c.fs("#33282f"); c.poly([0.6 * s, -16.8 * s, 6.0 * s, -11.6 * s, 6.6 * s, -1.8 * s, 3.0 * s, -3.0 * s])
	# megnyúzott arc
	c.fs(sot(IZOM, 0.35)); c.ell(0, -8.4 * s, 4.6 * s, 5.8 * s)
	c.fs(IZOM); c.ell(0.2 * s, -8.6 * s, 4.0 * s, 5.2 * s)
	c.ss(rgba(250, 170, 160, 0.6)); c.lw(0.45 * s)
	for i in 4:
		var yy := (-11.6 + i * 1.5) * s
		c.bp(); c.mt(-3.4 * s, yy); c.qt(0, yy - 0.9 * s, 3.6 * s, yy); c.stroke()
	c.bp(); c.mt(-2.6 * s, -6.0 * s); c.qt(-3.2 * s, -4.4 * s, -1.6 * s, -3.6 * s); c.stroke()
	c.bp(); c.mt(2.8 * s, -6.0 * s); c.qt(3.4 * s, -4.4 * s, 1.8 * s, -3.6 * s); c.stroke()
	# szemhéj nélküli, halvány szemek
	var gl := 0.7 + 0.3 * sin(t * 0.07)
	c.fs("#f4f0e0"); c.circ(-1.7 * s, -9.0 * s, 1.25 * s); c.circ(2.0 * s, -9.0 * s, 1.25 * s)
	c.fs(rgba(120, 210, 190, gl)); c.circ(-1.6 * s, -9.0 * s, 0.6 * s); c.circ(2.1 * s, -9.0 * s, 0.6 * s)
	# ajak nélküli fogsor
	c.fs("#efe6cc"); c.rrect(-1.9 * s, -5.6 * s, 4.0 * s, 1.5 * s, 0.4 * s); c.fill()
	c.ss("#5a1a20"); c.lw(0.3 * s)
	for i in 4:
		c.line((-1.1 + i * 0.8) * s, -5.6 * s, (-1.1 + i * 0.8) * s, -4.1 * s)
	c.restore()


# ══════════ FELJEGYZÉS A PADLÓN ══════════
static func note(c: Cv, px: float, py: float, s: float, t: float) -> void:
	var gl := 0.5 + 0.5 * sin(t * 0.09)
	if Sprites.glow_tex != null:
		c.tex(Sprites.glow_tex, Rect2(px - s * 0.2, py - s * 0.2, s * 1.4, s * 1.4), rgba(255, 230, 150, 0.22 + 0.16 * gl))
	c.save(); c.translate(px + s * 0.5, py + s * 0.52 - gl * s * 0.04); c.rotate(-0.16)
	c.fs("#8a7a58"); c.fill_rect(-s * 0.20, -s * 0.24, s * 0.44, s * 0.54)
	c.fs("#efe4c4"); c.fill_rect(-s * 0.23, -s * 0.28, s * 0.44, s * 0.54)
	c.ss("#7a6a4a"); c.lw(1.0)
	for i in 4:
		c.line(-s * 0.17, -s * 0.16 + i * s * 0.10, s * (0.15 - (0.10 if i == 3 else 0.0)), -s * 0.16 + i * s * 0.10)
	c.fs(REZ); c.fill_rect(-s * 0.06, -s * 0.33, s * 0.12, s * 0.09)
	c.restore()


# ══════════ HÁTTÉRKÉPEK (bevezető, befejezés, Műtőterem, Napló) ══════════
## art: gorgona | gorgona_tiszta | mag | sargulas | lombik | sziv
static func scene(c: Cv, art: String, x: float, y: float, w: float, h: float, t: float) -> void:
	match art:
		"gorgona": gorgona(c, x, y, w, h, t, false)
		"gorgona_tiszta": gorgona(c, x, y, w, h, t, true)
		"mag": core(c, x, y, w, h, t, false)
		"sziv": core(c, x, y, w, h, t, true)
		"sargulas": sargulas(c, x, y, w, h, t)
		"lombik": lombik(c, x, y, w, h, t)


## A lebegő henger-város a felhők felett. `tiszta`: a befejezés után — a méreg eloszlott.
static func gorgona(c: Cv, x: float, y: float, w: float, h: float, t: float, tiszta: bool) -> void:
	var g := Cv.linear(0, y, 0, y + h)
	if tiszta:
		g.stop(0.0, "#1a2a4a").stop(0.55, "#8a6a70").stop(1.0, "#f0b070")
	else:
		g.stop(0.0, "#0c0e08").stop(0.55, "#3a3a14").stop(1.0, "#8a7420")
	c.fs(g); c.fill_rect(x, y, w, h)
	var cx := x + w * 0.5
	var k := h / 400.0
	# távoli felhők
	for i in 6:
		var fx := x + fmod(i * 0.19 * w + t * (0.10 + i * 0.02) * k, w + 200 * k) - 100 * k
		var fy := y + h * (0.62 + 0.06 * sin(i * 1.7))
		c.fs(rgba(255, 220, 190, 0.10) if tiszta else rgba(190, 180, 80, 0.10))
		c.ell(fx, fy, 110 * k, 18 * k)
	# a város: egymásra rakott gyűrűk, fent keskenyebb
	var bob := sin(t * 0.02) * 4 * k
	var ty := y + h * 0.10 + bob
	var by := y + h * 0.80 + bob
	var tiers := 7
	for i in tiers:
		var u := float(i) / (tiers - 1)
		var yy := lerpf(ty, by, u)
		var rw := (46 + 62 * sin(u * PI * 0.92 + 0.25)) * k
		var th := (by - ty) / tiers + 2
		var base := "#241c14" if not tiszta else "#2a2430"
		c.fs(base); c.fill_rect(cx - rw, yy, rw * 2, th)
		c.fs(Skins.vil(base, 0.14)); c.fill_rect(cx - rw, yy, rw * 0.5, th)
		c.fs(Skins.sot(base, 0.4)); c.fill_rect(cx + rw * 0.55, yy, rw * 0.45, th)
		c.fs(Skins.vil(base, 0.3)); c.fill_rect(cx - rw - 4 * k, yy, rw * 2 + 8 * k, 3 * k)
		# ablakok
		for j in 9:
			var wx := cx - rw + (j + 0.5) * rw * 2 / 9.0
			var on := Data.rnd_seed(i * 13.0 + j * 7.0) > 0.35
			if on:
				var fl := 0.6 + 0.4 * sin(t * 0.05 + i * 2.0 + j)
				c.fs(rgba(255, 210, 120, 0.75 * fl) if tiszta else rgba(210, 230, 80, 0.7 * fl))
				c.fill_rect(wx - 2 * k, yy + th * 0.4, 4 * k, th * 0.3)
	# tornyok a tetején + gőz
	for i in 5:
		var tx := cx + (-44 + i * 22) * k
		var thh := (26 + 16 * Data.rnd_seed(i * 3.3)) * k
		c.fs("#1a140e" if not tiszta else "#221c28"); c.fill_rect(tx - 5 * k, ty - thh, 10 * k, thh + 2)
		c.poly([tx - 7 * k, ty - thh, tx + 7 * k, ty - thh, tx, ty - thh - 12 * k])
		for j in 3:
			var gg := fmod(t * 0.008 + j * 0.33 + i * 0.2, 1.0)
			c.fs(rgba(255, 245, 230, 0.20 * (1.0 - gg)) if tiszta else rgba(200, 210, 90, 0.26 * (1.0 - gg)))
			c.circ(tx + sin(gg * 5.0 + i) * 6 * k, ty - thh - 14 * k - gg * 50 * k, (5 + gg * 16) * k)
	# az alja: a Mag kürtője izzik
	c.fs("#120e0a"); c.poly([cx - 60 * k, by, cx + 60 * k, by, cx + 22 * k, by + 46 * k, cx - 22 * k, by + 46 * k])
	var gl := 0.6 + 0.4 * sin(t * 0.06)
	c.fs(rgba(255, 190, 90, 0.5 * gl) if tiszta else rgba(190, 255, 90, 0.4 * gl)); c.ell(cx, by + 46 * k, 22 * k, 6 * k)
	c.fs(rgba(255, 200, 100, 0.12 * gl) if tiszta else rgba(180, 240, 80, 0.12 * gl))
	c.poly([cx - 20 * k, by + 46 * k, cx + 20 * k, by + 46 * k, cx + 60 * k, y + h, cx - 60 * k, y + h])
	# előtér-felhők
	for i in 5:
		var fx2 := x + fmod(i * 0.23 * w + t * (0.22 + i * 0.04) * k, w + 300 * k) - 150 * k
		c.fs(rgba(255, 210, 170, 0.22) if tiszta else rgba(70, 70, 26, 0.5))
		c.ell(fx2, y + h * 0.94 + sin(i * 2.1) * 10 * k, 170 * k, 28 * k)


## Az Isten-Gép: fogaskerék-gyűrűk között lüktető mag. `sziv`: egy emberi szív ritmusára ver.
static func core(c: Cv, x: float, y: float, w: float, h: float, t: float, sziv: bool) -> void:
	c.fs("#0e0a08"); c.fill_rect(x, y, w, h)
	var cx := x + w * 0.5
	var cy := y + h * 0.5
	var k := h / 400.0
	var beat := 0.5 + 0.5 * sin(t * (0.11 if sziv else 0.04))
	if sziv:
		beat = pow(beat, 3.0)
	var col := rgba(255, 110, 80) if sziv else rgba(255, 190, 70)
	# gótikus acélbordák
	for i in 9:
		var bx := x + (i + 0.5) * w / 9.0
		c.fs(rgba(40, 36, 46, 0.9)); c.poly([bx - 5 * k, y + h, bx + 5 * k, y + h, cx + (bx - cx) * 0.2, y])
	# fényudvar
	for i in 5:
		c.fs(Color(col, 0.05 + 0.03 * beat)); c.circ(cx, cy, (170 - i * 26 + beat * 12) * k)
	# fogaskerék-gyűrűk
	for ring in 3:
		var rr := (120 - ring * 34) * k
		var n := 16 - ring * 4
		var rot := t * 0.004 * (1 if ring % 2 == 0 else -1) * (ring + 1)
		c.ss(rgba(110, 84, 40, 0.95)); c.lw((9 - ring * 2) * k)
		c.bp(); c.arc(cx, cy, rr, 0, TAU); c.stroke()
		c.fs(rgba(150, 112, 50, 0.95))
		for i in n:
			var a := rot + i / float(n) * TAU
			var px := cx + cos(a) * rr
			var py := cy + sin(a) * rr
			c.poly([px + cos(a + 1.57) * 6 * k, py + sin(a + 1.57) * 6 * k, px - cos(a + 1.57) * 6 * k, py - sin(a + 1.57) * 6 * k,
				px + cos(a) * 12 * k - cos(a + 1.57) * 3 * k, py + sin(a) * 12 * k - sin(a + 1.57) * 3 * k,
				px + cos(a) * 12 * k + cos(a + 1.57) * 3 * k, py + sin(a) * 12 * k + sin(a + 1.57) * 3 * k])
	# a mag (vagy a behelyezett szív)
	var r0 := (30 + beat * 6) * k
	c.fs(Color(col, 0.35)); c.circ(cx, cy, r0 * 1.5)
	if sziv:
		c.fs("#8a1a24"); c.circ(cx - r0 * 0.42, cy - r0 * 0.2, r0 * 0.62); c.circ(cx + r0 * 0.42, cy - r0 * 0.2, r0 * 0.62)
		c.poly([cx - r0 * 0.98, cy + r0 * 0.06, cx + r0 * 0.98, cy + r0 * 0.06, cx, cy + r0 * 1.15])
		c.fs("#d04048"); c.circ(cx - r0 * 0.38, cy - r0 * 0.26, r0 * 0.42); c.circ(cx + r0 * 0.44, cy - r0 * 0.26, r0 * 0.42)
		c.fs(REZ); c.fill_rect(cx - r0 * 0.14, cy - r0 * 0.95, r0 * 0.28, r0 * 0.5)
		c.ss("#f0c080"); c.lw(2 * k); c.line(cx - r0 * 0.7, cy + r0 * 0.3, cx + r0 * 0.7, cy + r0 * 0.3)
	else:
		c.fs(col); c.circ(cx, cy, r0)
		c.fs("#fff4d0"); c.circ(cx - r0 * 0.2, cy - r0 * 0.25, r0 * 0.45)
	# szikrák
	for i in 14:
		var a := i * 0.449 + t * 0.01
		var d := fmod(t * 0.006 + i * 0.137, 1.0)
		c.fs(Color(col, 0.8 * (1.0 - d))); c.circ(cx + cos(a) * (40 + d * 150) * k, cy + sin(a) * (40 + d * 150) * k, 2.2 * k)


## A Sárgulás: a csövekből fertőző bio-gőz tör fel.
static func sargulas(c: Cv, x: float, y: float, w: float, h: float, t: float) -> void:
	var g := Cv.linear(0, y, 0, y + h)
	g.stop(0.0, "#141608").stop(1.0, "#4a4610")
	c.fs(g); c.fill_rect(x, y, w, h)
	var k := h / 400.0
	# csőrengeteg
	for i in 9:
		var px := x + (i + 0.5) * w / 9.0 + sin(i * 2.3) * 14 * k
		var pw := (14 + 10 * Data.rnd_seed(i * 5.1)) * k
		c.fs(sot(ROZSDA, 0.45)); c.fill_rect(px - pw / 2, y, pw, h)
		c.fs(ROZSDA); c.fill_rect(px - pw / 2, y, pw * 0.36, h)
		for j in 4:
			var jy := y + (j + 0.5) * h / 4.0 + Data.rnd_seed(i + j * 3.0) * 30 * k
			c.fs(sot(REZ, 0.2)); c.fill_rect(px - pw / 2 - 3 * k, jy, pw + 6 * k, 8 * k)
		# repedésből szivárgó gőz
		for j in 5:
			var gg := fmod(t * 0.006 + j * 0.2 + i * 0.13, 1.0)
			c.fs(rgba(210, 230, 70, 0.20 * (1.0 - gg)))
			c.circ(px + sin(gg * 4.0 + i) * 20 * k, y + h * (0.9 - gg * 0.9), (12 + gg * 46) * k)
	# alul rohadó zöld derengés
	var g2 := Cv.linear(0, y + h * 0.6, 0, y + h)
	g2.stop(0.0, rgba(160, 200, 40, 0.0)).stop(1.0, rgba(160, 200, 40, 0.45))
	c.fs(g2); c.fill_rect(x, y + h * 0.6, w, h * 0.4)


## A Kónusz-Lombik: a Műtőterem tartályában egy új test várja az emlékeket.
static func lombik(c: Cv, x: float, y: float, w: float, h: float, t: float) -> void:
	c.fs("#0c1012"); c.fill_rect(x, y, w, h)
	var k := h / 400.0
	var cx := x + w * 0.5
	# csempézett fal
	c.ss(rgba(60, 80, 80, 0.35)); c.lw(1)
	var step := 40 * k
	var gx := x
	while gx < x + w:
		c.line(gx, y, gx, y + h * 0.78)
		gx += step
	var gy := y
	while gy < y + h * 0.78:
		c.line(x, gy, x + w, gy)
		gy += step
	c.fs("#1a1612"); c.fill_rect(x, y + h * 0.78, w, h * 0.22)
	# három tartály; a középsőben test lebeg
	for i in 3:
		var tx := cx + (i - 1) * 190 * k
		var tw := (120 if i == 1 else 86) * k
		var th := (250 if i == 1 else 190) * k
		var ty := y + h * 0.80 - th
		c.fs(sot(REZ, 0.45)); c.fill_rect(tx - tw / 2 - 8 * k, ty - 16 * k, tw + 16 * k, 18 * k); c.fill_rect(tx - tw / 2 - 8 * k, ty + th - 2, tw + 16 * k, 18 * k)
		c.fs(REZ); c.fill_rect(tx - tw / 2 - 8 * k, ty - 16 * k, tw + 16 * k, 5 * k)
		var gl := 0.7 + 0.3 * sin(t * 0.04 + i * 2.0)
		c.fs(rgba(70, 200, 160, 0.20 * gl) if i == 1 else rgba(60, 150, 130, 0.10)); c.fill_rect(tx - tw / 2, ty, tw, th)
		c.fs(rgba(190, 255, 230, 0.10)); c.fill_rect(tx - tw / 2 + 6 * k, ty, 10 * k, th)
		# buborékok
		for j in 6:
			var bb := fmod(t * 0.006 + j * 0.17 + i * 0.3, 1.0)
			c.fs(rgba(200, 255, 235, 0.35 * (1.0 - bb))); c.circ(tx + sin(j * 2.2 + bb * 6.0) * tw * 0.3, ty + th * (1.0 - bb), (2 + j % 3) * k)
		if i == 1:
			# a test: fél ember, fél gép
			var by := ty + th * 0.52 + sin(t * 0.03) * 6 * k
			c.fs(rgba(20, 40, 36, 0.9))
			c.circ(tx, by - 62 * k, 17 * k)
			c.poly([tx - 26 * k, by - 40 * k, tx + 26 * k, by - 40 * k, tx + 18 * k, by + 30 * k, tx - 18 * k, by + 30 * k])
			c.fill_rect(tx - 16 * k, by + 28 * k, 12 * k, 70 * k); c.fill_rect(tx + 4 * k, by + 28 * k, 12 * k, 70 * k)
			c.fill_rect(tx - 38 * k, by - 38 * k, 11 * k, 62 * k)
			c.fs(sot(REZ, 0.2)); c.fill_rect(tx + 27 * k, by - 38 * k, 11 * k, 62 * k)
			c.fs(REZ); c.circ(tx + 32 * k, by - 6 * k, 6 * k)
			var hb := pow(0.5 + 0.5 * sin(t * 0.1), 3.0)
			c.fs(rgba(255, 80, 70, 0.3 + 0.5 * hb)); c.circ(tx - 5 * k, by - 16 * k, (6 + hb * 3) * k)
			# az agyból kivezetett idegpálya-huzalok
			c.ss(rgba(120, 230, 200, 0.6)); c.lw(1.2 * k)
			for j in 4:
				c.bp(); c.mt(tx + (-9 + j * 6) * k, by - 76 * k); c.qt(tx + (-30 + j * 20) * k, ty + 10 * k, tx + (-40 + j * 27) * k, ty); c.stroke()
