class_name Sprites
extends RefCounted
## Az összes rajzolt figura: hősök, szörnyek, tárgy-ikonok, díszek.
## Sorról sorra az eredeti canvas-rajzolók átirata (Cv = ctx).

static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Cv.rgba(r, g, b, a)


# ══════════ HŐSÖK ══════════
## A hős NÉGY kinézet-helyből (fej, test, láb, fegyver) áll össze — a darabokat a skins.gd rajzolja.
## Minden hely alapból "" (alap kinézet); a boltban vett darabok csak a külsőt változtatják.
static func hero(c: Cv, cls: String, cx: float, cy: float, size: float, _t: float, skin := {}) -> void:
	c.save()
	c.translate(cx, cy)
	Skins.hos(c, cls, size / 40.0, skin)
	c.restore()


static func knight(c: Cv, cx: float, cy: float, size: float, t: float, skin := {}) -> void:
	hero(c, "Lovag", cx, cy, size, t, skin)


static func mage(c: Cv, cx: float, cy: float, size: float, t: float, skin := {}) -> void:
	hero(c, "Mágus", cx, cy, size, t, skin)


static func archer(c: Cv, cx: float, cy: float, size: float, t: float, skin := {}) -> void:
	hero(c, "Íjász", cx, cy, size, t, skin)


static func star(c: Cv, x: float, y: float, r: float) -> void:
	var pts: Array = []
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(x + cos(a) * rr)
		pts.append(y + sin(a) * rr)
	c.poly(pts)


## Nyugalmi mozgás: a KÉSZ háló csak fel-le tolódik (nincs képkockánkénti újrarajzolás).
## A fázis 16 lépésre kerekített — a rajzréteg ebből tudja, mikor kell egyáltalán frissítenie.
const HERO_PERIOD := TAU / 0.05
const HERO_FAZIS := {"Lovag": 0.0, "Mágus": 2.1, "Íjász": 4.2}


static func hero_phase(t: float) -> int:
	return int(floorf(fposmod(t, HERO_PERIOD) / HERO_PERIOD * 16.0)) % 16


static func hero_bob(cls: String, t: float, size: float) -> float:
	return sin(hero_phase(t) / 16.0 * TAU + float(HERO_FAZIS.get(cls, 0.0))) * (size / 40.0) * 0.9


static func hero_cached(c: Cv, cls: String, cx: float, cy: float, size: float, t: float, skin := {}) -> void:
	# a talajárnyék a földön marad (nem lebeg vele)
	c.blit("hsh|%d" % int(roundf(size * 4.0)),
		func() -> void: Skins.talajarnyek(c, 0, 0, size / 40.0, 12.5), cx, cy)
	c.blit("h|%s|%d|%s" % [cls, int(roundf(size * 4.0)), Skins.sig(skin, cls)],
		func() -> void: hero(c, cls, 0, 0, size, 0.0, skin), cx, cy + hero_bob(cls, t, size))


# ══════════ SZÖRNYEK ══════════
static func mon_bob(t: float, sd: float) -> float:
	return sin(t * 0.08 + sd) * 1.5


## világosít / sötétít (rétegzett árnyalás: alap + árnyék + csúcsfény)
static func vil(cc: Variant, f: float) -> Color:
	return Skins.vil(cc, f)


static func sot(cc: Variant, f: float) -> Color:
	return Skins.sot(cc, f)


## fáklyafény pereme a figura jobb oldalán
static func rim(c: Cv, pts: Array, w: float, a := 1.0) -> void:
	Skins.rim(c, pts, w, a)


## puha talajárnyék (a lebegéstől függetlenül a földön marad)
static func mon_shadow(c: Cv, key: String, cx: float, cy: float, sz: float) -> void:
	var k: float = MON_SHADOW.get(key, 1.0)
	c.blit("msh|%d|%d" % [int(roundf(sz * 4.0)), int(roundf(k * 16.0))], func() -> void:
		c.fs(Color(0, 0, 0, 0.30)); c.ell(0, sz * 0.42, sz * 0.34 * k, sz * 0.10 * k)
		c.fs(Color(0, 0, 0, 0.32)); c.ell(0, sz * 0.42, sz * 0.20 * k, sz * 0.06 * k), cx, cy)


const MON_SHADOW := {"goblin_king": 1.25, "necromancer": 1.2, "stone_titan": 1.5, "shadow_lord": 1.3,
	"dragon": 1.6, "golem": 1.2, "troll": 1.25, "demon": 1.2, "spider": 1.2}


static func monster(c: Cv, key: String, cx: float, cy: float, sz: float, t: float, sd: float, with_shadow := true) -> void:
	if with_shadow:
		mon_shadow(c, key, cx, cy, sz)
	match key:
		"goblin": goblin(c, cx, cy, sz, t, sd)
		"skeleton": skeleton(c, cx, cy, sz, t, sd)
		"orc": orc(c, cx, cy, sz, t, sd)
		"vampire": vampire(c, cx, cy, sz, t, sd)
		"spider": spider(c, cx, cy, sz, t, sd)
		"golem": golem(c, cx, cy, sz, t, sd)
		"witch": witch(c, cx, cy, sz, t, sd)
		"assassin": assassin(c, cx, cy, sz, t, sd)
		"troll": troll(c, cx, cy, sz, t, sd)
		"demon": demon(c, cx, cy, sz, t, sd)
		"goblin_king": goblin_king(c, cx, cy, sz, t, sd)
		"necromancer": necromancer(c, cx, cy, sz, t, sd)
		"stone_titan": stone_titan(c, cx, cy, sz, t, sd)
		"shadow_lord": shadow_lord(c, cx, cy, sz, t, sd)
		"dragon": dragon(c, cx, cy, sz, t, sd)


## Ezeknél a szörnyeknél az EGYETLEN mozgás a fel-le ringás (mon_bob), ezért a kész háló
## újrafelhasználható: csak feljebb-lejjebb kerül. A többi (izzó, lobogó, kavargó) élőben rajzolódik.
const SIMPLE_MONS := ["goblin", "skeleton", "orc", "vampire", "assassin", "troll", "goblin_king"]


static func monster_cached(c: Cv, key: String, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	mon_shadow(c, key, cx, cy, sz)
	if not key in SIMPLE_MONS:
		monster(c, key, cx, cy, sz, t, sd, false)
		return
	# a felvétel olyan időpillanatban készül, ahol a ringás éppen nulla -> a mag nem számít
	c.blit("m|%s|%d" % [key, int(roundf(sz * 4.0))],
		func() -> void: monster(c, key, 0, 0, sz, -sd / 0.08, sd, false), cx, cy + mon_bob(t, sd))


static func goblin(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	const ZO := "#4c8f31"
	c.save(); c.translate(cx, cy + b)
	# lábak
	c.fs(sot(ZO, 0.45))
	c.rrect(-4.4 * s, 6.6 * s, 3.4 * s, 5.6 * s, 1.2 * s); c.fill()
	c.rrect(1.0 * s, 6.6 * s, 3.4 * s, 5.6 * s, 1.2 * s); c.fill()
	c.fs("#3a2a12")
	c.rrect(-5.0 * s, 10.6 * s, 4.4 * s, 2.2 * s, 0.9 * s); c.fill()
	c.rrect(0.6 * s, 10.6 * s, 4.4 * s, 2.2 * s, 0.9 * s); c.fill()
	# görnyedt test
	c.fs(sot(ZO, 0.32)); c.ell(0, 2.4 * s, 6.2 * s, 6.0 * s)
	c.fs(ZO); c.ell(0.6 * s, 2.0 * s, 5.3 * s, 5.2 * s)
	c.fs(vil(ZO, 0.24)); c.ell(1.8 * s, 0.8 * s, 3.0 * s, 3.2 * s)
	# ágyékkötő
	c.fs("#6a4a1e"); c.fill_rect(-4.8 * s, 4.4 * s, 9.6 * s, 2.4 * s)
	c.fs("#8a6228"); c.fill_rect(-4.8 * s, 4.4 * s, 9.6 * s, 0.8 * s)
	# fej
	c.fs(sot(ZO, 0.28)); c.ell(0, -6.2 * s, 5.6 * s, 5.2 * s)
	c.fs(ZO); c.ell(0.5 * s, -6.6 * s, 4.9 * s, 4.5 * s)
	c.fs(vil(ZO, 0.22)); c.ell(1.4 * s, -8.2 * s, 2.8 * s, 2.0 * s)
	# fülek
	c.fs(sot(ZO, 0.18))
	c.poly([-4.4 * s, -8.2 * s, -11.2 * s, -12.4 * s, -9.6 * s, -7.0 * s, -3.8 * s, -4.6 * s])
	c.poly([4.4 * s, -8.2 * s, 11.2 * s, -12.4 * s, 9.6 * s, -7.0 * s, 3.8 * s, -4.6 * s])
	c.fs(vil(ZO, 0.14))
	c.poly([-4.6 * s, -8.0 * s, -9.8 * s, -11.2 * s, -8.6 * s, -7.6 * s])
	c.poly([4.6 * s, -8.0 * s, 9.8 * s, -11.2 * s, 8.6 * s, -7.6 * s])
	# orr + száj
	c.fs(sot(ZO, 0.20))
	c.poly([0.4 * s, -6.6 * s, 3.2 * s, -4.8 * s, 0.4 * s, -4.0 * s])
	c.fs("#2a1a10")
	c.bp(); c.mt(-2.6 * s, -3.4 * s); c.qt(0.4 * s, -1.6 * s, 3.4 * s, -3.6 * s)
	c.qt(0.4 * s, -2.6 * s, -2.6 * s, -3.4 * s); c.cp(); c.fill()
	c.fs("#efe8cf")
	c.poly([-1.6 * s, -2.9 * s, -0.7 * s, -2.9 * s, -1.2 * s, -1.7 * s])
	c.poly([1.4 * s, -3.0 * s, 2.3 * s, -3.0 * s, 1.8 * s, -1.9 * s])
	# szemek
	c.fs("#1c2a10")
	c.ell(-2.2 * s, -7.6 * s, 1.7 * s, 1.5 * s)
	c.ell(2.6 * s, -7.6 * s, 1.7 * s, 1.5 * s)
	c.fs("#f4e23c")
	c.ell(-2.0 * s, -7.6 * s, 1.1 * s, 0.95 * s)
	c.ell(2.8 * s, -7.6 * s, 1.1 * s, 0.95 * s)
	c.fs("#1a1206")
	c.ell(-1.8 * s, -7.6 * s, 0.35 * s, 0.8 * s)
	c.ell(3.0 * s, -7.6 * s, 0.35 * s, 0.8 * s)
	# tőr
	c.save(); c.translate(6.4 * s, 2.0 * s); c.rotate(-0.66)
	c.fs("#3a2a12"); c.rrect(-0.7 * s, 0, 1.4 * s, 2.8 * s, 0.6 * s); c.fill()
	c.fs("#6c7688"); c.poly([0, -6.6 * s, 0.85 * s, -5.0 * s, 0.85 * s, -0.2 * s, -0.85 * s, -0.2 * s, -0.85 * s, -5.0 * s])
	c.fs("#cbd6e6"); c.poly([0.1 * s, -6.2 * s, 0.75 * s, -4.9 * s, 0.75 * s, -0.4 * s, 0.15 * s, -0.4 * s])
	c.restore()
	c.fs(ZO); c.circ(5.8 * s, 3.0 * s, 1.5 * s)
	rim(c, [3.6 * s, -9.6 * s, 5.2 * s, -6.4 * s, 5.6 * s, 0.4 * s, 4.4 * s, 6.4 * s], 0.65 * s)
	c.restore()


static func skeleton(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	const CS := "#ddd5bd"
	c.save(); c.translate(cx, cy + b)
	# lábcsontok
	c.ss(sot(CS, 0.30)); c.lw(1.6 * s)
	c.line(-2.0 * s, 8.0 * s, -2.8 * s, 12.6 * s)
	c.line(2.0 * s, 8.0 * s, 2.8 * s, 12.6 * s)
	c.fs(sot(CS, 0.15))
	c.ell(-3.0 * s, 12.8 * s, 2.0 * s, 0.9 * s)
	c.ell(3.0 * s, 12.8 * s, 2.0 * s, 0.9 * s)
	# medence
	c.fs(sot(CS, 0.22))
	c.poly([-3.4 * s, 6.0 * s, 3.4 * s, 6.0 * s, 2.6 * s, 8.8 * s, -2.6 * s, 8.8 * s])
	# gerinc
	c.ss(sot(CS, 0.18)); c.lw(1.3 * s)
	c.line(0, -1.6 * s, 0, 6.4 * s)
	# bordák (3 árnyalat: hátsó sötét, elülső világos)
	c.ss(sot(CS, 0.34)); c.lw(1.5 * s)
	for i in 4:
		c.bp(); c.mt(-4.8 * s, (-0.6 + i * 1.9) * s); c.qt(0, (1.8 + i * 1.9) * s, 4.8 * s, (-0.6 + i * 1.9) * s); c.stroke()
	c.ss(CS); c.lw(0.9 * s)
	for i in 4:
		c.bp(); c.mt(-4.6 * s, (-0.9 + i * 1.9) * s); c.qt(0, (1.4 + i * 1.9) * s, 4.6 * s, (-0.9 + i * 1.9) * s); c.stroke()
	# vállak, karok
	c.ss(sot(CS, 0.25)); c.lw(1.5 * s)
	c.line(-5.0 * s, -1.4 * s, 5.0 * s, -1.4 * s)
	c.line(-5.0 * s, -1.4 * s, -7.6 * s, 5.0 * s)
	c.line(5.0 * s, -1.4 * s, 8.2 * s, 3.6 * s)
	c.ss(CS); c.lw(0.9 * s)
	c.line(4.9 * s, -1.7 * s, 8.1 * s, 3.3 * s)
	# koponya
	c.fs(sot(CS, 0.28)); c.ell(0, -6.6 * s, 5.0 * s, 5.2 * s)
	c.fs(CS); c.ell(0.4 * s, -6.9 * s, 4.4 * s, 4.6 * s)
	c.fs(vil(CS, 0.30)); c.ell(1.4 * s, -8.4 * s, 2.4 * s, 1.8 * s)
	c.fs(CS); c.rrect(-2.6 * s, -3.6 * s, 5.4 * s, 2.4 * s, 0.7 * s); c.fill()
	c.fs(sot(CS, 0.45))
	for i in 4:
		c.fill_rect((-2.0 + i * 1.3) * s, -3.4 * s, 0.4 * s, 2.0 * s)
	# szemgödrök + halvány derengés
	c.fs("#120e08")
	c.ell(-1.8 * s, -7.4 * s, 1.7 * s, 1.9 * s)
	c.ell(2.4 * s, -7.4 * s, 1.7 * s, 1.9 * s)
	c.fs(Color(0.62, 0.86, 1.0, 0.6))
	c.ell(-1.8 * s, -7.2 * s, 0.7 * s, 0.8 * s)
	c.ell(2.4 * s, -7.2 * s, 0.7 * s, 0.8 * s)
	c.fs("#120e08")
	c.poly([0.3 * s, -5.6 * s, 1.1 * s, -4.4 * s, -0.5 * s, -4.4 * s])
	rim(c, [3.2 * s, -9.6 * s, 4.6 * s, -6.6 * s, 4.4 * s, -3.4 * s], 0.6 * s)
	c.restore()


static func orc(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	const BO := "#7f5a2c"
	c.save(); c.translate(cx, cy + b)
	# lábak
	c.fs("#3d3220")
	c.rrect(-5.2 * s, 8.0 * s, 4.4 * s, 5.0 * s, 1.4 * s); c.fill()
	c.rrect(0.8 * s, 8.0 * s, 4.4 * s, 5.0 * s, 1.4 * s); c.fill()
	c.fs("#241c10")
	c.rrect(-5.6 * s, 11.6 * s, 5.2 * s, 2.2 * s, 0.9 * s); c.fill()
	c.rrect(0.4 * s, 11.6 * s, 5.2 * s, 2.2 * s, 0.9 * s); c.fill()
	# tömzsi törzs
	c.fs(sot(BO, 0.34)); c.ell(0, 2.6 * s, 8.4 * s, 7.6 * s)
	c.fs(BO); c.ell(0.6 * s, 2.2 * s, 7.4 * s, 6.8 * s)
	c.fs(vil(BO, 0.20)); c.ell(2.2 * s, 0.6 * s, 4.0 * s, 4.0 * s)
	# bőrpáncél
	c.fs("#4a3418")
	c.poly([-6.0 * s, -1.4 * s, 6.4 * s, -1.4 * s, 5.4 * s, 6.6 * s, -5.0 * s, 6.6 * s])
	c.fs("#6a4c24")
	c.poly([0.4 * s, -1.4 * s, 6.4 * s, -1.4 * s, 5.4 * s, 6.6 * s, 0.4 * s, 6.6 * s])
	c.fs("#a5882f")
	for i in 3:
		c.circ((-3.6 + i * 3.4) * s, 1.6 * s, 0.55 * s)
	# vállvért
	c.fs("#4b5361"); c.ell(-6.8 * s, -2.6 * s, 3.6 * s, 2.7 * s, -0.3)
	c.fs("#7d8798"); c.ell(-6.8 * s, -3.1 * s, 3.0 * s, 2.1 * s, -0.3)
	# fej
	c.fs(sot(BO, 0.30)); c.ell(0, -7.0 * s, 6.4 * s, 5.8 * s)
	c.fs(BO); c.ell(0.5 * s, -7.4 * s, 5.7 * s, 5.1 * s)
	c.fs(vil(BO, 0.20)); c.ell(1.8 * s, -9.4 * s, 3.2 * s, 2.2 * s)
	# állkapocs + agyarak
	c.fs(sot(BO, 0.22))
	c.rrect(-3.6 * s, -4.8 * s, 7.6 * s, 3.2 * s, 1.2 * s); c.fill()
	c.fs("#1c1208"); c.fill_rect(-2.8 * s, -3.8 * s, 6.0 * s, 0.9 * s)
	c.fs("#efe8cf")
	c.poly([-3.4 * s, -2.6 * s, -2.0 * s, -2.6 * s, -2.6 * s, -6.6 * s])
	c.poly([2.6 * s, -2.6 * s, 4.0 * s, -2.6 * s, 3.4 * s, -6.6 * s])
	# szemek
	c.fs("#231404")
	c.ell(-2.4 * s, -8.6 * s, 1.8 * s, 1.5 * s)
	c.ell(2.8 * s, -8.6 * s, 1.8 * s, 1.5 * s)
	c.fs("#e8422a")
	c.ell(-2.2 * s, -8.6 * s, 1.0 * s, 0.85 * s)
	c.ell(3.0 * s, -8.6 * s, 1.0 * s, 0.85 * s)
	# bunkó
	c.save(); c.translate(9.0 * s, 2.0 * s); c.rotate(-0.58)
	c.fs("#4a3418"); c.rrect(-1.0 * s, -2.0 * s, 2.0 * s, 10.0 * s, 0.9 * s); c.fill()
	c.fs("#6a4c24"); c.fill_rect(0, -2.0 * s, 0.8 * s, 10.0 * s)
	c.fs("#3d3020"); c.ell(0, -6.0 * s, 3.6 * s, 4.6 * s)
	c.fs("#5b4a30"); c.ell(0.5 * s, -6.4 * s, 3.0 * s, 3.9 * s)
	c.fs("#8b775a"); c.ell(1.2 * s, -7.6 * s, 1.5 * s, 1.6 * s)
	c.fs("#c8ccd4")
	for p in [[-2.6, -7.4], [2.6, -5.0], [-1.4, -3.2], [2.0, -8.6]]:
		c.poly([float(p[0]) * s, float(p[1]) * s, (float(p[0]) + 1.3) * s, (float(p[1]) + 0.8) * s, (float(p[0]) + 0.3) * s, (float(p[1]) + 1.5) * s])
	c.restore()
	rim(c, [3.4 * s, -11.0 * s, 6.0 * s, -7.2 * s, 7.4 * s, 0.4 * s, 5.6 * s, 7.4 * s], 0.7 * s)
	c.restore()


static func vampire(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	# köpeny
	c.fs("#1c0410")
	c.bp(); c.mt(0, -9.0 * s)
	c.qt(-13.0 * s, -2.0 * s, -11.6 * s, 12.6 * s)
	c.lt(-4.0 * s, 9.4 * s); c.lt(0, 12.6 * s); c.lt(4.0 * s, 9.4 * s); c.lt(11.6 * s, 12.6 * s)
	c.qt(13.0 * s, -2.0 * s, 0, -9.0 * s); c.cp(); c.fill()
	c.fs("#4a0a24")
	c.bp(); c.mt(2.0 * s, -8.6 * s)
	c.qt(11.0 * s, -1.6 * s, 10.4 * s, 11.6 * s)
	c.lt(4.0 * s, 9.0 * s); c.lt(2.4 * s, 10.4 * s); c.cp(); c.fill()
	# gallér
	c.fs("#38081c")
	c.poly([-5.2 * s, -6.0 * s, -6.6 * s, -13.2 * s, -1.6 * s, -7.4 * s])
	c.poly([5.2 * s, -6.0 * s, 6.6 * s, -13.2 * s, 1.6 * s, -7.4 * s])
	c.fs("#6d1233")
	c.poly([-5.0 * s, -6.2 * s, -5.8 * s, -12.0 * s, -2.4 * s, -7.6 * s])
	c.poly([5.0 * s, -6.2 * s, 5.8 * s, -12.0 * s, 2.4 * s, -7.6 * s])
	# mellény
	c.fs("#2a0a18"); c.fill_rect(-3.4 * s, -4.0 * s, 6.8 * s, 12.0 * s)
	c.fs("#4a1028"); c.fill_rect(0.2 * s, -4.0 * s, 3.2 * s, 12.0 * s)
	c.fs("#c8a03a")
	for i in 3:
		c.circ(0, (-1.8 + i * 3.0) * s, 0.55 * s)
	# fej
	c.fs("#b3a49e"); c.ell(0, -8.0 * s, 4.4 * s, 4.7 * s)
	c.fs("#d9cbc4"); c.ell(0.4 * s, -8.3 * s, 3.9 * s, 4.2 * s)
	c.fs("#f1e8e2"); c.ell(1.3 * s, -9.6 * s, 2.0 * s, 1.6 * s)
	# haj
	c.fs("#120a10")
	c.bp(); c.arc(0, -9.4 * s, 4.6 * s, PI * 1.02, PI * 1.98); c.lt(4.4 * s, -8.4 * s)
	c.qt(2.4 * s, -10.6 * s, 0, -10.4 * s); c.qt(-2.4 * s, -10.6 * s, -4.4 * s, -8.4 * s); c.cp(); c.fill()
	c.fs("#2c1c28")
	c.bp(); c.mt(1.0 * s, -13.2 * s); c.qt(4.2 * s, -12.0 * s, 4.4 * s, -8.6 * s)
	c.qt(3.0 * s, -11.2 * s, 0.6 * s, -11.6 * s); c.cp(); c.fill()
	# szemek + tépőfogak
	c.fs("#2a0a0c")
	c.ell(-1.6 * s, -8.4 * s, 1.3 * s, 1.0 * s)
	c.ell(2.2 * s, -8.4 * s, 1.3 * s, 1.0 * s)
	c.fs("#ff2a2a")
	c.ell(-1.6 * s, -8.4 * s, 0.7 * s, 0.6 * s)
	c.ell(2.2 * s, -8.4 * s, 0.7 * s, 0.6 * s)
	c.fs("#8a1414"); c.fill_rect(-1.8 * s, -6.2 * s, 4.0 * s, 0.7 * s)
	c.fs("#ffffff")
	c.poly([-1.5 * s, -5.9 * s, -0.7 * s, -5.9 * s, -1.1 * s, -4.5 * s])
	c.poly([1.2 * s, -5.9 * s, 2.0 * s, -5.9 * s, 1.6 * s, -4.5 * s])
	rim(c, [2.4 * s, -12.4 * s, 4.2 * s, -8.2 * s, 7.4 * s, 0.0, 9.8 * s, 9.0 * s], 0.7 * s)
	c.restore()


static func spider(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd) * 0.5
	const PO := "#6b4a17"
	c.save(); c.translate(cx, cy + b)
	# lábak: sötét alsó réteg + világosabb felső él
	for pass_i in 2:
		c.ss(sot(PO, 0.55) if pass_i == 0 else PO)
		c.lw((1.9 if pass_i == 0 else 1.0) * s)
		for i in 4:
			var wig := sin(t * 0.15 + i) * 1.6 * s
			c.bp(); c.mt(-2.6 * s, 0.4 * s)
			c.qt(-9.0 * s, (-5.0 + i * 1.4) * s + wig, -12.6 * s, (2.4 + i * 2.2) * s); c.stroke()
			c.bp(); c.mt(2.6 * s, 0.4 * s)
			c.qt(9.0 * s, (-5.0 + i * 1.4) * s - wig, 12.6 * s, (2.4 + i * 2.2) * s); c.stroke()
	# potroh
	c.fs(sot(PO, 0.40)); c.ell(0, 2.6 * s, 6.4 * s, 7.2 * s)
	c.fs(PO); c.ell(0.5 * s, 2.2 * s, 5.6 * s, 6.4 * s)
	c.fs(vil(PO, 0.22)); c.ell(1.8 * s, 0.2 * s, 2.8 * s, 3.0 * s)
	# homokóra-minta
	c.fs("#c0342c")
	c.poly([-1.8 * s, 0.6 * s, 1.8 * s, 0.6 * s, 0.5 * s, 3.0 * s, 2.0 * s, 6.0 * s, -1.4 * s, 6.0 * s, 0.0, 3.0 * s])
	# fejtor
	c.fs(sot(PO, 0.25)); c.ell(0, -5.2 * s, 4.4 * s, 3.8 * s)
	c.fs(vil(PO, 0.14)); c.ell(0.6 * s, -5.6 * s, 3.7 * s, 3.1 * s)
	# csáprágók
	c.fs("#241708")
	c.poly([-2.0 * s, -3.4 * s, -3.2 * s, -1.0 * s, -1.0 * s, -2.6 * s])
	c.poly([2.0 * s, -3.4 * s, 3.2 * s, -1.0 * s, 1.0 * s, -2.6 * s])
	# szemek (4+2)
	c.fs("#f3e33c")
	c.circ(-1.8 * s, -6.2 * s, 1.0 * s)
	c.circ(1.8 * s, -6.2 * s, 1.0 * s)
	c.circ(-3.2 * s, -4.8 * s, 0.6 * s)
	c.circ(3.2 * s, -4.8 * s, 0.6 * s)
	c.circ(-0.7 * s, -4.4 * s, 0.45 * s)
	c.circ(0.9 * s, -4.4 * s, 0.45 * s)
	c.fs("#1a1206")
	c.ell(-1.7 * s, -6.2 * s, 0.35 * s, 0.6 * s)
	c.ell(1.9 * s, -6.2 * s, 0.35 * s, 0.6 * s)
	rim(c, [2.6 * s, -7.4 * s, 5.4 * s, -1.0 * s, 4.6 * s, 6.4 * s], 0.65 * s)
	c.restore()


static func golem(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	const KO := "#7c7a68"
	c.save(); c.translate(cx, cy)
	# lábak
	c.fs(sot(KO, 0.42))
	c.rrect(-5.6 * s, 9.0 * s, 4.6 * s, 4.4 * s, 1.0 * s); c.fill()
	c.rrect(1.0 * s, 9.0 * s, 4.6 * s, 4.4 * s, 1.0 * s); c.fill()
	# karok
	c.fs(sot(KO, 0.32))
	c.rrect(-12.4 * s, -3.4 * s, 4.6 * s, 12.0 * s, 1.8 * s); c.fill()
	c.rrect(7.8 * s, -3.4 * s, 4.6 * s, 12.0 * s, 1.8 * s); c.fill()
	c.fs(vil(sot(KO, 0.32), 0.16))
	c.rrect(10.2 * s, -3.0 * s, 1.9 * s, 11.2 * s, 0.9 * s); c.fill()
	# törzs (kőtömbök)
	c.fs(sot(KO, 0.30)); c.rrect(-8.4 * s, -4.4 * s, 16.8 * s, 14.4 * s, 2.0 * s); c.fill()
	c.fs(KO); c.rrect(-7.6 * s, -4.4 * s, 15.6 * s, 14.0 * s, 1.8 * s); c.fill()
	c.fs(vil(KO, 0.20)); c.rrect(2.0 * s, -4.0 * s, 5.6 * s, 13.2 * s, 1.4 * s); c.fill()
	c.ss(sot(KO, 0.45)); c.lw(0.8 * s)
	c.line(-7.6 * s, 1.4 * s, 8.0 * s, 1.4 * s)
	c.line(-1.6 * s, -4.4 * s, -1.6 * s, 1.4 * s)
	c.line(2.8 * s, 1.4 * s, 2.8 * s, 9.6 * s)
	# fej
	c.fs(sot(KO, 0.24)); c.rrect(-6.4 * s, -12.6 * s, 12.8 * s, 9.0 * s, 1.8 * s); c.fill()
	c.fs(vil(KO, 0.12)); c.rrect(-5.6 * s, -12.6 * s, 11.6 * s, 8.6 * s, 1.6 * s); c.fill()
	c.fs(vil(KO, 0.28)); c.rrect(1.4 * s, -12.2 * s, 4.4 * s, 7.8 * s, 1.2 * s); c.fill()
	# repedések
	c.ss(sot(KO, 0.55)); c.lw(0.7 * s)
	c.bp(); c.mt(-3.2 * s, -12.0 * s); c.lt(-1.4 * s, -8.6 * s); c.lt(-4.0 * s, -6.2 * s); c.stroke()
	c.bp(); c.mt(3.4 * s, 2.6 * s); c.lt(5.2 * s, 6.4 * s); c.stroke()
	# moha
	c.fs(Color(0.24, 0.42, 0.18, 0.55))
	c.ell(-5.0 * s, -5.2 * s, 2.4 * s, 0.9 * s, 0.2)
	c.ell(4.6 * s, 8.6 * s, 2.2 * s, 0.8 * s, -0.2)
	# izzó szemek
	var gl := 0.6 + 0.4 * sin(t * 0.06 + sd)
	c.fs(rgba(255, 150, 30, gl * 0.35))
	c.ell(-2.8 * s, -9.0 * s, 3.4 * s, 2.6 * s)
	c.ell(2.6 * s, -9.0 * s, 3.4 * s, 2.6 * s)
	c.fs(rgba(255, 190, 70, gl))
	c.rrect(-4.2 * s, -9.8 * s, 2.8 * s, 1.8 * s, 0.6 * s); c.fill()
	c.rrect(1.4 * s, -9.8 * s, 2.8 * s, 1.8 * s, 0.6 * s); c.fill()
	rim(c, [4.6 * s, -12.2 * s, 6.0 * s, -4.4 * s, 8.0 * s, 9.0 * s], 0.7 * s)
	c.restore()


static func witch(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	const KE := "#4a1470"
	c.save(); c.translate(cx, cy + b)
	# köntös
	c.fs(sot(KE, 0.35))
	c.bp(); c.mt(-2.6 * s, -6.6 * s); c.qt(-6.0 * s, 2.0 * s, -8.6 * s, 12.6 * s)
	c.lt(8.6 * s, 12.6 * s); c.qt(6.0 * s, 2.0 * s, 2.6 * s, -6.6 * s); c.cp(); c.fill()
	c.fs(KE)
	c.bp(); c.mt(-2.2 * s, -6.4 * s); c.qt(-5.2 * s, 2.0 * s, -7.6 * s, 12.0 * s)
	c.lt(7.6 * s, 12.0 * s); c.qt(5.2 * s, 2.0 * s, 2.2 * s, -6.4 * s); c.cp(); c.fill()
	c.fs(vil(KE, 0.24))
	c.bp(); c.mt(0.8 * s, -6.4 * s); c.qt(3.0 * s, 2.0 * s, 4.0 * s, 12.0 * s)
	c.lt(7.6 * s, 12.0 * s); c.qt(5.2 * s, 2.0 * s, 2.2 * s, -6.4 * s); c.cp(); c.fill()
	c.fs("#2a0a12"); c.fill_rect(-4.6 * s, 1.6 * s, 9.6 * s, 1.4 * s)
	# fej (zöldes bőr)
	c.fs("#6f8f48"); c.ell(0, -9.4 * s, 4.0 * s, 4.3 * s)
	c.fs("#93b45e"); c.ell(0.4 * s, -9.7 * s, 3.5 * s, 3.8 * s)
	c.fs("#b6d283"); c.ell(1.2 * s, -10.8 * s, 1.8 * s, 1.4 * s)
	# görbe orr + áll
	c.fs("#7f9f52")
	c.poly([0.4 * s, -9.6 * s, 3.6 * s, -7.4 * s, 0.6 * s, -7.0 * s])
	c.fs("#3a2010"); c.fill_rect(-1.6 * s, -6.6 * s, 3.4 * s, 0.6 * s)
	# szemek
	c.fs("#231a06")
	c.ell(-1.5 * s, -10.4 * s, 1.2 * s, 1.0 * s)
	c.ell(2.1 * s, -10.4 * s, 1.2 * s, 1.0 * s)
	c.fs("#f3e33c")
	c.ell(-1.5 * s, -10.4 * s, 0.65 * s, 0.55 * s)
	c.ell(2.1 * s, -10.4 * s, 0.65 * s, 0.55 * s)
	# haj
	c.fs("#4b4652")
	c.bp(); c.mt(-3.8 * s, -11.0 * s); c.qt(-6.4 * s, -6.0 * s, -4.6 * s, -1.6 * s)
	c.qt(-3.0 * s, -6.4 * s, -2.4 * s, -10.4 * s); c.cp(); c.fill()
	# kalap
	c.fs("#20063a"); c.ell(0, -12.4 * s, 8.6 * s, 1.9 * s)
	c.fs("#2f0a52"); c.ell(0, -12.8 * s, 8.0 * s, 1.6 * s)
	c.fs("#4a1478"); c.ell(1.2 * s, -13.3 * s, 5.4 * s, 0.85 * s)
	c.fs("#20063a")
	c.bp(); c.mt(-5.0 * s, -12.8 * s); c.lt(5.0 * s, -12.8 * s)
	c.qt(3.4 * s, -19.6 * s, -1.4 * s, -24.0 * s); c.cp(); c.fill()
	c.fs("#3d0f66")
	c.bp(); c.mt(-4.2 * s, -13.2 * s); c.lt(4.4 * s, -13.2 * s)
	c.qt(3.0 * s, -19.2 * s, -1.4 * s, -23.2 * s); c.cp(); c.fill()
	c.fs("#5c1f92")
	c.bp(); c.mt(0.6 * s, -13.2 * s); c.lt(4.4 * s, -13.2 * s)
	c.qt(3.0 * s, -19.2 * s, -1.4 * s, -23.2 * s); c.qt(1.0 * s, -18.4 * s, 0.6 * s, -13.2 * s); c.cp(); c.fill()
	c.fs("#c8a03a"); c.fill_rect(-4.6 * s, -14.6 * s, 9.2 * s, 1.5 * s)
	# lebegő méregbogyó
	var og := 0.5 + 0.5 * sin(t * 0.12 + sd)
	var oy := -5.0 * s + sin(t * 0.1) * 2.0 * s
	c.fs(rgba(200, 80, 255, 0.28 * og)); c.circ(8.4 * s, oy, 4.2 * s)
	c.fs(rgba(150, 50, 210, 0.9)); c.circ(8.4 * s, oy, 2.3 * s)
	c.fs(rgba(226, 170, 255, 0.95)); c.circ(7.8 * s, oy - 0.7 * s, 1.0 * s)
	rim(c, [0.6 * s, -22.6 * s, 4.0 * s, -13.6 * s, 4.2 * s, -8.0 * s, 6.6 * s, 11.6 * s], 0.68 * s)
	c.restore()


static func assassin(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.alpha *= 0.9
	# köpeny
	c.fs("#111114")
	c.bp(); c.mt(0, -11.0 * s)
	c.qt(-9.6 * s, -1.0 * s, -8.0 * s, 12.4 * s)
	c.lt(8.0 * s, 12.4 * s)
	c.qt(9.6 * s, -1.0 * s, 0, -11.0 * s); c.cp(); c.fill()
	c.fs("#23242b")
	c.bp(); c.mt(1.4 * s, -10.6 * s)
	c.qt(7.6 * s, -1.0 * s, 6.6 * s, 12.0 * s)
	c.lt(1.4 * s, 12.0 * s); c.cp(); c.fill()
	c.fs("#0a0a0c")
	c.fill_rect(-3.0 * s, 1.6 * s, 6.4 * s, 1.5 * s)
	# csuklya
	c.fs("#191a20")
	c.bp(); c.arc(0, -8.4 * s, 5.2 * s, PI * 0.82, PI * 2.18)
	c.lt(4.6 * s, -3.4 * s); c.qt(0, -1.8 * s, -4.6 * s, -3.4 * s); c.cp(); c.fill()
	c.fs("#2c2e37")
	c.bp(); c.arc(0, -8.6 * s, 4.6 * s, -PI * 0.46, PI * 0.06)
	c.lt(2.4 * s, -4.6 * s); c.qt(3.0 * s, -9.0 * s, 1.0 * s, -13.2 * s); c.cp(); c.fill()
	c.fs("#050506"); c.ell(0, -7.8 * s, 3.4 * s, 3.2 * s)
	# izzó szemek
	c.fs(rgba(255, 60, 40, 0.30)); c.ell(0, -8.2 * s, 4.4 * s, 2.4 * s)
	c.fs("#ff3a28")
	c.rrect(-2.6 * s, -8.8 * s, 1.9 * s, 0.9 * s, 0.4 * s); c.fill()
	c.rrect(0.7 * s, -8.8 * s, 1.9 * s, 0.9 * s, 0.4 * s); c.fill()
	# két tőr
	for d in [-1.0, 1.0]:
		c.save(); c.translate(d * 6.8 * s, 2.4 * s); c.rotate(d * 0.85)
		c.fs("#1a1a1e"); c.rrect(-0.6 * s, 0, 1.2 * s, 2.6 * s, 0.5 * s); c.fill()
		c.fs("#59616e"); c.poly([0, -6.2 * s, 0.8 * s, -4.6 * s, 0.8 * s, -0.2 * s, -0.8 * s, -0.2 * s, -0.8 * s, -4.6 * s])
		c.fs("#b9c4d4"); c.poly([0.1 * s, -5.8 * s, 0.7 * s, -4.5 * s, 0.7 * s, -0.4 * s, 0.15 * s, -0.4 * s])
		c.restore()
	rim(c, [1.4 * s, -13.2 * s, 4.4 * s, -8.4 * s, 6.8 * s, 1.0 * s, 7.6 * s, 11.6 * s], 0.62 * s)
	c.restore()


static func troll(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	const TR := "#9e5a2c"
	c.save(); c.translate(cx, cy + b)
	# hosszú karok
	c.fs(sot(TR, 0.32))
	c.ell(-10.0 * s, 3.4 * s, 3.6 * s, 7.4 * s, 0.28)
	c.ell(10.0 * s, 3.4 * s, 3.6 * s, 7.4 * s, -0.28)
	c.fs(sot(TR, 0.12))
	c.ell(11.0 * s, 1.4 * s, 1.6 * s, 4.4 * s, -0.28)
	c.fs(sot(TR, 0.42))
	c.ell(-10.6 * s, 10.0 * s, 2.8 * s, 2.4 * s)
	c.ell(10.6 * s, 10.0 * s, 2.8 * s, 2.4 * s)
	# lábak
	c.fs(sot(TR, 0.40))
	c.rrect(-5.4 * s, 9.0 * s, 4.6 * s, 4.4 * s, 1.2 * s); c.fill()
	c.rrect(0.8 * s, 9.0 * s, 4.6 * s, 4.4 * s, 1.2 * s); c.fill()
	# test
	c.fs(sot(TR, 0.34)); c.ell(0, 2.0 * s, 9.6 * s, 8.6 * s)
	c.fs(TR); c.ell(0.8 * s, 1.6 * s, 8.6 * s, 7.8 * s)
	c.fs(vil(TR, 0.20)); c.ell(2.6 * s, -0.4 * s, 4.6 * s, 4.4 * s)
	c.fs(sot(TR, 0.18)); c.ell(0.4 * s, 4.4 * s, 5.2 * s, 4.0 * s)
	# ágyékkötő
	c.fs("#4a3418"); c.fill_rect(-5.6 * s, 6.6 * s, 11.2 * s, 3.0 * s)
	c.fs("#66491f"); c.fill_rect(-5.6 * s, 6.6 * s, 11.2 * s, 0.9 * s)
	# fej
	c.fs(sot(TR, 0.28)); c.ell(0, -7.6 * s, 6.0 * s, 5.4 * s)
	c.fs(TR); c.ell(0.5 * s, -8.0 * s, 5.3 * s, 4.7 * s)
	c.fs(vil(TR, 0.20)); c.ell(1.8 * s, -9.8 * s, 2.8 * s, 2.0 * s)
	# alsó állkapocs + agyarak
	c.fs(sot(TR, 0.20))
	c.rrect(-4.0 * s, -5.4 * s, 8.2 * s, 3.2 * s, 1.3 * s); c.fill()
	c.fs("#efe8cf")
	c.poly([-3.2 * s, -4.0 * s, -1.8 * s, -4.0 * s, -2.4 * s, -7.8 * s])
	c.poly([2.4 * s, -4.0 * s, 3.8 * s, -4.0 * s, 3.2 * s, -7.8 * s])
	c.fs("#2a1408"); c.fill_rect(-2.4 * s, -4.4 * s, 5.2 * s, 0.7 * s)
	# szemek
	c.fs("#2a1408")
	c.ell(-2.2 * s, -9.4 * s, 1.5 * s, 1.2 * s)
	c.ell(2.8 * s, -9.4 * s, 1.5 * s, 1.2 * s)
	c.fs("#ffd66a")
	c.ell(-2.0 * s, -9.4 * s, 0.7 * s, 0.6 * s)
	c.ell(3.0 * s, -9.4 * s, 0.7 * s, 0.6 * s)
	rim(c, [3.2 * s, -11.6 * s, 5.6 * s, -7.8 * s, 9.0 * s, 0.0, 7.6 * s, 8.4 * s], 0.72 * s)
	c.restore()


static func demon(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	const DE := "#a81c1c"
	c.save(); c.translate(cx, cy + b)
	# szárnyak
	for d in [-1.0, 1.0]:
		c.fs("#48060a")
		c.bp(); c.mt(d * 3.4 * s, -4.4 * s)
		c.qt(d * 17.0 * s, -15.6 * s, d * 15.0 * s, 2.4 * s)
		c.qt(d * 9.0 * s, -2.4 * s, d * 3.4 * s, 2.0 * s); c.cp(); c.fill()
		c.fs("#6d0c12")
		c.bp(); c.mt(d * 3.6 * s, -4.2 * s)
		c.qt(d * 14.4 * s, -13.2 * s, d * 13.2 * s, 0.8 * s)
		c.qt(d * 8.4 * s, -2.6 * s, d * 3.6 * s, 1.2 * s); c.cp(); c.fill()
		c.ss("#a02222"); c.lw(0.7 * s)
		for p in [[15.0, 2.4], [11.0, -0.4], [7.4, -1.6]]:
			c.line(d * 3.4 * s, -4.4 * s, d * float(p[0]) * s, float(p[1]) * s)
	# lábak (pata)
	c.fs("#4d0a0e")
	c.rrect(-4.6 * s, 8.4 * s, 3.8 * s, 4.2 * s, 1.1 * s); c.fill()
	c.rrect(0.8 * s, 8.4 * s, 3.8 * s, 4.2 * s, 1.1 * s); c.fill()
	c.fs("#1c1210")
	c.rrect(-5.0 * s, 11.6 * s, 4.4 * s, 2.0 * s, 0.7 * s); c.fill()
	c.rrect(0.6 * s, 11.6 * s, 4.4 * s, 2.0 * s, 0.7 * s); c.fill()
	# test
	c.fs(sot(DE, 0.38)); c.ell(0, 2.0 * s, 7.4 * s, 8.0 * s)
	c.fs(DE); c.ell(0.6 * s, 1.6 * s, 6.5 * s, 7.2 * s)
	c.fs(vil(DE, 0.22)); c.ell(2.0 * s, -0.4 * s, 3.4 * s, 3.8 * s)
	# mellkas-lemez
	c.fs(sot(DE, 0.50))
	c.poly([-4.4 * s, -2.6 * s, 4.8 * s, -2.6 * s, 3.4 * s, 5.4 * s, -3.0 * s, 5.4 * s])
	c.fs(rgba(255, 140, 30, 0.5))
	c.poly([-1.2 * s, -1.6 * s, 1.6 * s, -1.6 * s, 0.6 * s, 4.4 * s, -0.2 * s, 4.4 * s])
	# fej
	c.fs(sot(DE, 0.30)); c.ell(0, -7.4 * s, 5.2 * s, 4.8 * s)
	c.fs(vil(DE, 0.10)); c.ell(0.5 * s, -7.7 * s, 4.6 * s, 4.2 * s)
	c.fs(vil(DE, 0.30)); c.ell(1.6 * s, -9.2 * s, 2.4 * s, 1.7 * s)
	# szarvak
	for d in [-1.0, 1.0]:
		c.ss("#2a0c06"); c.lw(2.0 * s)
		c.bp(); c.mt(d * 3.2 * s, -10.6 * s); c.qt(d * 6.6 * s, -15.4 * s, d * 3.4 * s, -18.4 * s); c.stroke()
		c.ss("#5a2412"); c.lw(0.7 * s)
		c.bp(); c.mt(d * 3.4 * s, -11.0 * s); c.qt(d * 6.0 * s, -15.0 * s, d * 3.6 * s, -17.8 * s); c.stroke()
	# száj
	c.fs("#2a0606")
	c.bp(); c.mt(-2.6 * s, -5.4 * s); c.qt(0.4 * s, -3.0 * s, 3.4 * s, -5.4 * s)
	c.qt(0.4 * s, -4.4 * s, -2.6 * s, -5.4 * s); c.cp(); c.fill()
	c.fs("#efe4cc")
	for i in 4:
		c.poly([(-2.0 + i * 1.4) * s, -5.2 * s, (-1.3 + i * 1.4) * s, -5.2 * s, (-1.65 + i * 1.4) * s, -4.0 * s])
	# izzó szemek
	var gl := 0.7 + 0.3 * sin(t * 0.1 + sd)
	c.fs(rgba(255, 220, 40, gl * 0.35))
	c.ell(-1.8 * s, -8.4 * s, 3.0 * s, 2.2 * s)
	c.ell(2.6 * s, -8.4 * s, 3.0 * s, 2.2 * s)
	c.fs(rgba(255, 228, 70, gl))
	c.ell(-1.8 * s, -8.4 * s, 1.3 * s, 1.1 * s)
	c.ell(2.6 * s, -8.4 * s, 1.3 * s, 1.1 * s)
	c.fs("#3a0a00")
	c.ell(-1.6 * s, -8.4 * s, 0.35 * s, 0.9 * s)
	c.ell(2.8 * s, -8.4 * s, 0.35 * s, 0.9 * s)
	rim(c, [2.6 * s, -11.2 * s, 4.8 * s, -7.2 * s, 6.4 * s, 1.0 * s, 4.6 * s, 8.0 * s], 0.7 * s)
	c.restore()


# ── FŐELLENSÉGEK ──
static func goblin_king(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz * 1.25 / 30.0
	var b := mon_bob(t, sd)
	# királyi palást a goblin mögé
	c.save(); c.translate(cx, cy + b)
	c.fs("#4a0a16")
	c.bp(); c.mt(-5.6 * s, -7.0 * s); c.qt(-11.6 * s, 2.0 * s, -9.0 * s, 12.8 * s)
	c.lt(9.0 * s, 12.8 * s); c.qt(11.6 * s, 2.0 * s, 5.6 * s, -7.0 * s); c.cp(); c.fill()
	c.fs("#7a1220")
	c.bp(); c.mt(2.0 * s, -7.0 * s); c.qt(9.4 * s, 2.0 * s, 7.8 * s, 12.2 * s)
	c.lt(3.0 * s, 12.2 * s); c.cp(); c.fill()
	c.fs("#e6e0cc"); c.fill_rect(-9.2 * s, 10.8 * s, 18.4 * s, 2.0 * s)
	c.restore()
	goblin(c, cx, cy, sz * 1.25, t, sd)
	c.save(); c.translate(cx, cy + b)
	# korona
	c.fs("#8a6410")
	c.poly([-5.4 * s, -10.4 * s, 5.4 * s, -10.4 * s, 5.4 * s, -13.2 * s, 3.2 * s, -15.2 * s,
		1.8 * s, -12.8 * s, 0, -16.4 * s, -1.8 * s, -12.8 * s, -3.2 * s, -15.2 * s, -5.4 * s, -13.2 * s])
	c.fs("#d9ab4d")
	c.poly([-4.9 * s, -10.6 * s, 4.9 * s, -10.6 * s, 4.9 * s, -13.2 * s, 3.0 * s, -14.8 * s,
		1.7 * s, -12.7 * s, 0, -15.8 * s, -1.7 * s, -12.7 * s, -3.0 * s, -14.8 * s, -4.9 * s, -13.2 * s])
	c.fs("#f5dd90")
	c.poly([0.6 * s, -10.8 * s, 4.9 * s, -10.8 * s, 4.9 * s, -13.2 * s, 3.0 * s, -14.6 * s, 1.8 * s, -12.8 * s, 0.6 * s, -13.2 * s])
	c.fs("#e0402a"); c.circ(0, -11.8 * s, 0.85 * s)
	c.fs("#4aa0e0"); c.circ(-3.0 * s, -11.6 * s, 0.6 * s)
	c.fs("#4ad080"); c.circ(3.0 * s, -11.6 * s, 0.6 * s)
	c.restore()


static func necromancer(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz * 1.25 / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	# köntös
	c.fs("#0d0818")
	c.bp(); c.mt(-3.0 * s, -11.0 * s); c.qt(-7.0 * s, 0.0, -10.6 * s, 14.2 * s)
	c.lt(10.6 * s, 14.2 * s); c.qt(7.0 * s, 0.0, 3.0 * s, -11.0 * s); c.cp(); c.fill()
	c.fs("#1b1230")
	c.bp(); c.mt(-2.6 * s, -10.8 * s); c.qt(-6.2 * s, 0.0, -9.6 * s, 13.6 * s)
	c.lt(9.6 * s, 13.6 * s); c.qt(6.2 * s, 0.0, 2.6 * s, -10.8 * s); c.cp(); c.fill()
	c.fs("#2e2050")
	c.bp(); c.mt(1.0 * s, -10.8 * s); c.qt(4.4 * s, 0.0, 5.6 * s, 13.6 * s)
	c.lt(9.6 * s, 13.6 * s); c.qt(6.2 * s, 0.0, 2.6 * s, -10.8 * s); c.cp(); c.fill()
	c.ss(rgba(120, 255, 140, 0.30)); c.lw(0.7 * s)
	c.bp(); c.mt(-5.6 * s, 6.0 * s); c.qt(0, 8.4 * s, 5.6 * s, 6.0 * s); c.stroke()
	# öv
	c.fs("#3a2a18"); c.fill_rect(-5.0 * s, 1.0 * s, 10.4 * s, 1.5 * s)
	# koponyafej
	c.fs("#bfb79f"); c.ell(0, -13.2 * s, 4.6 * s, 4.9 * s)
	c.fs("#e4dcc3"); c.ell(0.4 * s, -13.5 * s, 4.1 * s, 4.3 * s)
	c.fs("#f4eeda"); c.ell(1.3 * s, -15.0 * s, 2.0 * s, 1.5 * s)
	c.fs("#ded5bb"); c.rrect(-2.4 * s, -10.6 * s, 5.0 * s, 2.2 * s, 0.6 * s); c.fill()
	c.fs("#0d0a06")
	c.ell(-1.7 * s, -13.9 * s, 1.6 * s, 1.8 * s)
	c.ell(2.3 * s, -13.9 * s, 1.6 * s, 1.8 * s)
	c.fs(rgba(120, 255, 130, 0.85))
	c.ell(-1.7 * s, -13.7 * s, 0.7 * s, 0.8 * s)
	c.ell(2.3 * s, -13.7 * s, 0.7 * s, 0.8 * s)
	# csuklya
	c.fs("#0d0818")
	c.bp(); c.arc(0, -13.6 * s, 6.6 * s, PI * 0.80, PI * 2.20)
	c.lt(5.8 * s, -6.6 * s); c.qt(0, -4.6 * s, -5.8 * s, -6.6 * s); c.cp(); c.fill()
	c.fs("#241838")
	c.bp(); c.arc(0, -13.8 * s, 6.0 * s, PI * 0.82, PI * 2.18)
	c.lt(5.2 * s, -7.2 * s); c.qt(0, -5.4 * s, -5.2 * s, -7.2 * s); c.cp(); c.fill()
	c.fs("#3a2a58")
	c.bp(); c.arc(0, -13.8 * s, 6.0 * s, -PI * 0.46, PI * 0.02)
	c.lt(3.0 * s, -8.4 * s); c.qt(3.6 * s, -14.2 * s, 1.2 * s, -19.6 * s); c.cp(); c.fill()
	c.fs("#0a0610"); c.ell(0, -12.6 * s, 4.2 * s, 4.0 * s)
	c.fs(rgba(120, 255, 130, 0.9))
	c.ell(-1.7 * s, -13.6 * s, 0.85 * s, 0.95 * s)
	c.ell(2.3 * s, -13.6 * s, 0.85 * s, 0.95 * s)
	# bot koponyával
	c.ss("#241808"); c.lw(1.9 * s)
	c.line(11.4 * s, 14.0 * s, 13.2 * s, -14.4 * s)
	c.ss("#4a3418"); c.lw(0.8 * s)
	c.line(11.6 * s, 13.6 * s, 13.4 * s, -14.0 * s)
	var gl := 0.5 + 0.5 * sin(t * 0.09)
	c.fs(rgba(120, 255, 120, 0.26 * gl)); c.circ(13.4 * s, -16.4 * s, 5.6 * s)
	c.fs("#bfb79f"); c.ell(13.4 * s, -16.6 * s, 2.8 * s, 3.0 * s)
	c.fs("#e8e0c6"); c.ell(13.8 * s, -16.9 * s, 2.3 * s, 2.5 * s)
	c.fs("#0d0a06")
	c.ell(12.6 * s, -17.2 * s, 0.85 * s, 1.0 * s)
	c.ell(14.8 * s, -17.2 * s, 0.85 * s, 1.0 * s)
	c.fs(rgba(140, 255, 140, gl))
	c.ell(12.6 * s, -17.1 * s, 0.45 * s, 0.55 * s)
	c.ell(14.8 * s, -17.1 * s, 0.45 * s, 0.55 * s)
	rim(c, [1.2 * s, -19.4 * s, 4.8 * s, -15.4 * s, 6.4 * s, -6.0 * s, 9.4 * s, 13.2 * s], 0.7 * s)
	c.restore()


static func stone_titan(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	golem(c, cx, cy, sz * 1.45, t, sd)
	var s := sz * 1.45 / 30.0
	c.save(); c.translate(cx, cy)
	var gl := 0.5 + 0.5 * sin(t * 0.05)
	# izzó mag a mellkasban
	c.fs(rgba(255, 170, 40, 0.30 * gl)); c.circ(0.2 * s, 2.4 * s, 6.2 * s)
	c.fs(rgba(255, 140, 20, 0.85)); c.circ(0.2 * s, 2.4 * s, 2.6 * s)
	c.fs(rgba(255, 236, 160, 0.95)); c.circ(-0.4 * s, 1.6 * s, 1.1 * s)
	c.ss(rgba(255, 190, 70, gl)); c.lw(1.2 * s)
	c.bp(); c.arc(0.2 * s, 2.4 * s, 4.0 * s, 0, 7); c.stroke()
	# izzó erezet
	c.ss(rgba(255, 150, 40, 0.55 + 0.35 * gl)); c.lw(0.8 * s)
	c.bp(); c.mt(-4.6 * s, -2.6 * s); c.lt(-2.4 * s, 1.4 * s); c.lt(-4.0 * s, 6.0 * s); c.stroke()
	c.bp(); c.mt(4.8 * s, -2.0 * s); c.lt(3.0 * s, 2.2 * s); c.lt(4.6 * s, 7.4 * s); c.stroke()
	c.restore()


static func shadow_lord(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz * 1.3 / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	var wob := sin(t * 0.07) * 2 * s
	# külső árnyékfelhő
	c.fs(rgba(28, 6, 56, 0.55))
	c.bp(); c.mt(0, -15.6 * s)
	c.qt(-12.0 * s + wob, -4.0 * s, -9.6 * s, 15.0 * s)
	c.qt(0, 11.0 * s, 9.6 * s, 15.0 * s)
	c.qt(12.0 * s - wob, -4.0 * s, 0, -15.6 * s); c.fill()
	c.fs(rgba(62, 18, 122, 0.8))
	c.bp(); c.mt(0, -14.0 * s)
	c.qt(-9.6 * s + wob, -4.0 * s, -7.8 * s, 13.6 * s)
	c.qt(0, 10.0 * s, 7.8 * s, 13.6 * s)
	c.qt(9.6 * s - wob, -4.0 * s, 0, -14.0 * s); c.fill()
	c.fs(rgba(112, 52, 190, 0.7))
	c.bp(); c.mt(1.4 * s, -13.4 * s)
	c.qt(7.0 * s - wob * 0.4, -4.0 * s, 6.4 * s, 12.6 * s)
	c.qt(3.0 * s, 11.6 * s, 2.0 * s, 12.0 * s)
	c.qt(3.4 * s, -2.0 * s, 1.4 * s, -13.4 * s); c.cp(); c.fill()
	# csuklya belseje
	c.fs(rgba(10, 2, 22, 0.95))
	c.ell(0, -9.0 * s, 4.8 * s, 5.2 * s)
	# korona-tüskék
	c.fs(rgba(150, 90, 230, 0.75))
	for i in 5:
		var xx := (-4.4 + i * 2.2) * s
		c.poly([xx, -12.6 * s, xx + 1.0 * s, -12.6 * s, xx + 0.5 * s, (-16.4 - absf(2 - i) * -0.9) * s])
	# foszló csóva
	c.ss(rgba(110, 46, 190, 0.5)); c.lw(1.4 * s)
	for i in 3:
		c.bp(); c.mt((-6 + i * 6) * s, 12.6 * s)
		c.qt((-8 + i * 7) * s + wob, 18.4 * s, (-5 + i * 5) * s, 22.4 * s); c.stroke()
	# izzó szemek
	var gl := 0.7 + 0.3 * sin(t * 0.11)
	c.fs(rgba(220, 120, 255, 0.30 * gl))
	c.ell(-2.4 * s, -8.6 * s, 3.6 * s, 2.6 * s)
	c.ell(2.4 * s, -8.6 * s, 3.6 * s, 2.6 * s)
	c.fs(rgba(228, 150, 255, gl))
	c.ell(-2.4 * s, -8.6 * s, 1.6 * s, 1.2 * s)
	c.ell(2.4 * s, -8.6 * s, 1.6 * s, 1.2 * s)
	c.fs(rgba(255, 245, 255, gl))
	c.ell(-2.4 * s, -8.8 * s, 0.6 * s, 0.5 * s)
	c.ell(2.4 * s, -8.8 * s, 0.6 * s, 0.5 * s)
	c.restore()


static func dragon(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz * 1.5 / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	var flap := sin(t * 0.09) * 0.25
	# szárnyak (két tónus + bordák)
	for d in [-1.0, 1.0]:
		c.save(); c.rotate(d * flap); c.scale(d, 1)
		c.fs("#4a0708")
		c.bp(); c.mt(3 * s, -4 * s); c.qt(20 * s, -18 * s, 17 * s, 2 * s); c.qt(10 * s, -3 * s, 3 * s, 2 * s); c.cp(); c.fill()
		c.fs("#7a1012")
		c.bp(); c.mt(3.4 * s, -4.2 * s); c.qt(17.6 * s, -15.6 * s, 15.2 * s, 0.8 * s); c.qt(9.4 * s, -3.4 * s, 3.4 * s, 1.2 * s); c.cp(); c.fill()
		c.ss("#a82222"); c.lw(0.7 * s)
		for p in [[17.0, 2.0], [12.4, -0.6], [8.0, -1.8]]:
			c.line(3 * s, -4 * s, float(p[0]) * s, float(p[1]) * s)
		c.restore()
	# farok
	c.fs("#7a1012")
	c.bp(); c.mt(-3.0 * s, 8.0 * s); c.qt(-13.0 * s, 14.0 * s, -16.0 * s, 8.0 * s)
	c.qt(-11.0 * s, 17.0 * s, -1.0 * s, 12.0 * s); c.cp(); c.fill()
	# test
	c.fs("#8b1114"); c.ell(0, 3.4 * s, 8.2 * s, 10.0 * s)
	c.fs("#c31a1c"); c.ell(0.8 * s, 3.0 * s, 7.2 * s, 9.2 * s)
	c.fs("#e04a32"); c.ell(2.2 * s, 0.4 * s, 3.4 * s, 4.4 * s)
	# has-lemezek
	c.fs("#c69a3e"); c.ell(0.2 * s, 5.0 * s, 4.4 * s, 7.0 * s)
	c.fs("#e8b048"); c.ell(0.6 * s, 4.6 * s, 3.8 * s, 6.4 * s)
	c.ss(rgba(120, 70, 10, 0.45)); c.lw(0.7 * s)
	for i in 4:
		c.bp(); c.mt(-3.2 * s, (0.2 + i * 2.6) * s); c.qt(0.6 * s, (1.6 + i * 2.6) * s, 4.2 * s, (0.2 + i * 2.6) * s); c.stroke()
	# hát-tüskék
	c.fs("#4e0a10")
	for i in 4:
		var sy := -6.0 * s + i * 3.4 * s
		c.poly([-6.6 * s - i * 0.3 * s, sy, -9.6 * s - i * 0.5 * s, sy - 1.8 * s, -6.2 * s - i * 0.3 * s, sy + 2.0 * s])
	# nyak + fej
	c.fs("#a4151a")
	c.bp(); c.mt(-4.2 * s, -4.0 * s); c.qt(-4.0 * s, -10.0 * s, -3.6 * s, -12.0 * s)
	c.lt(4.2 * s, -12.0 * s); c.qt(4.4 * s, -9.0 * s, 4.6 * s, -4.0 * s); c.cp(); c.fill()
	c.fs("#8b1114"); c.ell(0, -9.4 * s, 4.8 * s, 6.2 * s)
	c.fs("#cf1f22"); c.ell(0.5 * s, -9.8 * s, 4.2 * s, 5.6 * s)
	c.fs("#e8583a"); c.ell(1.6 * s, -12.0 * s, 2.2 * s, 2.0 * s)
	# pofa
	c.fs("#a4151a"); c.ell(0.4 * s, -13.4 * s, 3.2 * s, 2.6 * s)
	c.fs("#2a0405"); c.ell(0.4 * s, -13.0 * s, 2.4 * s, 1.1 * s)
	c.fs("#f3ead0")
	for i in 4:
		c.poly([(-1.4 + i * 1.2) * s, -13.4 * s, (-0.8 + i * 1.2) * s, -13.4 * s, (-1.1 + i * 1.2) * s, -12.2 * s])
	# szarvak
	c.ss("#2a1408"); c.lw(2.0 * s)
	c.bp(); c.mt(-3.0 * s, -13.0 * s); c.qt(-6.4 * s, -17.0 * s, -6.2 * s, -19.6 * s); c.stroke()
	c.bp(); c.mt(3.4 * s, -13.0 * s); c.qt(6.8 * s, -17.0 * s, 6.6 * s, -19.6 * s); c.stroke()
	c.ss("#e8d8a0"); c.lw(0.8 * s)
	c.bp(); c.mt(-3.2 * s, -13.4 * s); c.qt(-6.2 * s, -17.0 * s, -6.0 * s, -19.2 * s); c.stroke()
	c.bp(); c.mt(3.6 * s, -13.4 * s); c.qt(6.6 * s, -17.0 * s, 6.4 * s, -19.2 * s); c.stroke()
	# szemek
	var gl := 0.7 + 0.3 * sin(t * 0.13)
	c.fs(rgba(255, 220, 40, 0.32 * gl))
	c.ell(-2.0 * s, -11.4 * s, 3.2 * s, 2.4 * s)
	c.ell(2.4 * s, -11.4 * s, 3.2 * s, 2.4 * s)
	c.fs(rgba(255, 230, 80, gl))
	c.ell(-2.0 * s, -11.4 * s, 1.5 * s, 1.2 * s)
	c.ell(2.4 * s, -11.4 * s, 1.5 * s, 1.2 * s)
	c.fs("#2a0a00")
	c.ell(-1.8 * s, -11.4 * s, 0.4 * s, 1.0 * s)
	c.ell(2.6 * s, -11.4 * s, 0.4 * s, 1.0 * s)
	# tűzokádás
	if sin(t * 0.04) > 0.4:
		for i in 5:
			var fy := -15.4 * s - i * 2.4 * s
			c.fs(rgba(255, int(140 + Data.rnd_seed(sd + i) * 80), 20, 0.72 - i * 0.13))
			c.circ(0.4 * s + (Data.rnd_seed(sd + i * 7) - 0.5) * 4 * s, fy, (1.8 - i * 0.24) * s)
	rim(c, [2.0 * s, -18.4 * s, 4.4 * s, -12.0 * s, 7.0 * s, -2.0 * s, 6.2 * s, 10.0 * s], 0.8 * s)
	c.restore()


# ══════════ TÁRGY-IKONOK (rajzolt) ══════════
static var glow_tex: Texture2D = null

static func item_icon(c: Cv, it: Item, cx: float, cy: float, size: float, t: float) -> void:
	item_glow(c, it, cx, cy, size, t)
	item_shape(c, it, cx, cy, size, t)


## Csak a ritkaság-ragyogás. Listákban érdemes minden ragyogást egyben kirajzolni, utána
## minden alakot: a textúra ugyanis megszakítja a háromszög-köteget, így kevesebb rajzhívás lesz.
static func item_glow(c: Cv, it: Item, cx: float, cy: float, size: float, t: float) -> void:
	var pulse := (0.35 + 0.2 * sin(t * 0.1)) if it.rarity == "legendary" else 0.25
	var bc: Color = Cv.col(it.border())
	var gc := bc
	gc.a = pulse
	if glow_tex:
		# ragyogás a ritkaság színével (sugaras textúra; a négyzetbe írt kör ugyanaz, mint az eredeti)
		c.tex(glow_tex, Rect2(cx - size * 0.65, cy - size * 0.65, size * 1.3, size * 1.3), gc)
	else:
		var tc := bc
		tc.a = 0
		c.fs(Cv.radial(cx, cy, 1, size * 0.65).stop(0, gc).stop(1, tc))
		c.fill_rect(cx - size * 0.65, cy - size * 0.65, size * 1.3, size * 1.3)


static func item_shape(c: Cv, it: Item, cx: float, cy: float, size: float, t: float) -> void:
	var sub: String = it.subtype
	# a mozdulatlan ikonok kész hálóból kerülnek ki (a rajzuk színátmenetek miatt drága)
	if sub in STATIC_ICONS:
		c.blit("i|%s|%d" % [sub, int(roundf(size * 4.0))], func() -> void: _icon_shape(c, sub, 0, 0, size, 0.0), cx, cy)
	elif sub == "maxheal":
		# csak egyenletesen lüktet: a kész háló nagyítva játszódik vissza
		var beat := 1 + 0.06 * sin(t * 0.15)
		c.replay(c.rec_cached("i|maxheal|%d" % int(roundf(size * 4.0)), func() -> void: i_maxheal_shape(c, size)),
			Transform2D(0.0, Vector2(cx, cy)) * Transform2D(Vector2(beat, 0), Vector2(0, beat), Vector2.ZERO))
	elif sub in DRAWN_ICONS:
		_icon_shape(c, sub, cx, cy, size, t)
	else:
		c.ftxt(it.glyph if it.glyph != "" else "?", cx, cy + size * 0.2, it.col(), size * 0.6, "center", true)


## egységes vonalvastagság az ikonokon: a méret arányában, de 40 px alatt sem tűnik el
static func ilw(s: float) -> float:
	return maxf(0.85, s * 0.028)


const STATIC_ICONS := ["sword", "bow", "shield", "armor", "atk_up", "def_up"]
const DRAWN_ICONS := ["cannon", "heal", "fireball"]


static func _icon_shape(c: Cv, sub: String, cx: float, cy: float, size: float, t: float) -> void:
	match sub:
		"sword": i_sword(c, cx, cy, size, t)
		"bow": i_bow(c, cx, cy, size, t)
		"cannon": i_cannon(c, cx, cy, size, t)
		"shield": i_shield(c, cx, cy, size, t)
		"armor": i_armor(c, cx, cy, size, t)
		"heal": i_heal(c, cx, cy, size, t)
		"maxheal": i_maxheal(c, cx, cy, size, t)
		"atk_up": i_atk_up(c, cx, cy, size, t)
		"def_up": i_def_up(c, cx, cy, size, t)
		"fireball": i_fireball(c, cx, cy, size, t)


static func i_sword(c: Cv, cx: float, cy: float, s: float, _t: float) -> void:
	c.save(); c.translate(cx, cy); c.rotate(-PI / 4)
	# penge csillanással
	var bg := Cv.linear(-s * 0.05, 0, s * 0.05, 0).stop(0, "#8a98a8").stop(0.5, "#e8f0f8").stop(1, "#8a98a8")
	c.fs(bg)
	c.poly([0, -s * 0.48, s * 0.06, -s * 0.38, s * 0.06, s * 0.12, -s * 0.06, s * 0.12, -s * 0.06, -s * 0.38])
	# vérárok
	c.ss("#70808f"); c.lw(ilw(s))
	c.line(0, -s * 0.42, 0, s * 0.08)
	# keresztvas
	c.fs("#c8a030"); c.fill_rect(-s * 0.16, s * 0.12, s * 0.32, s * 0.06)
	# markolat
	c.fs("#5a3a1a"); c.fill_rect(-s * 0.045, s * 0.18, s * 0.09, s * 0.2)
	c.ss("#8a6030"); c.lw(ilw(s))
	for i in range(1, 4):
		c.line(-s * 0.045, s * 0.18 + i * s * 0.05, s * 0.045, s * 0.18 + i * s * 0.05)
	# gömb
	c.fs("#c8a030"); c.circ(0, s * 0.42, s * 0.06)
	c.restore()


static func i_bow(c: Cv, cx: float, cy: float, s: float, _t: float) -> void:
	c.save(); c.translate(cx, cy)
	c.ss("#8a5c20"); c.lw(s * 0.07)
	c.bp(); c.arc(-s * 0.12, 0, s * 0.4, -PI * 0.42, PI * 0.42); c.stroke()
	c.fs("#c8a030")
	var ex := -s * 0.12 + s * 0.4 * cos(PI * 0.42)
	var ey := s * 0.4 * sin(PI * 0.42)
	c.circ(ex, ey, s * 0.045)
	c.circ(ex, -ey, s * 0.045)
	c.ss("#e8e0d0"); c.lw(ilw(s))
	c.line(ex, -ey, ex, ey)
	c.ss("#d4a84b"); c.lw(s * 0.04)
	c.line(-s * 0.45, 0, s * 0.32, 0)
	c.fs("#e8e8f0")
	c.poly([s * 0.42, 0, s * 0.28, -s * 0.07, s * 0.28, s * 0.07])
	c.fs("#c04030")
	c.poly([-s * 0.45, 0, -s * 0.34, -s * 0.07, -s * 0.32, 0, -s * 0.34, s * 0.07])
	c.restore()


static func i_cannon(c: Cv, cx: float, cy: float, s: float, t: float) -> void:
	c.save(); c.translate(cx, cy); c.rotate(-0.2)
	var cg := Cv.linear(0, -s * 0.12, 0, s * 0.12).stop(0, "#585860").stop(0.5, "#88888f").stop(1, "#48484f")
	c.fs(cg)
	c.fill_rect(-s * 0.42, -s * 0.11, s * 0.72, s * 0.22)
	c.fs("#38383f"); c.fill_rect(s * 0.24, -s * 0.14, s * 0.09, s * 0.28)
	c.fs("#6a4520")
	c.poly([-s * 0.42, -s * 0.08, -s * 0.42, s * 0.11, -s * 0.28, s * 0.34, -s * 0.16, s * 0.30, -s * 0.26, s * 0.11])
	c.ss("#3a2a10"); c.lw(ilw(s) * 1.3)
	c.bp(); c.mt(-s * 0.34, -s * 0.11); c.qt(-s * 0.40, -s * 0.26, -s * 0.30, -s * 0.30); c.stroke()
	var sp := 0.5 + 0.5 * sin(t * 0.25)
	c.fs(rgba(255, int(180 + 60 * sp), 40, 0.7 + 0.3 * sp))
	c.circ(-s * 0.30, -s * 0.31, s * 0.05 * (0.8 + 0.4 * sp))
	c.restore()


static func i_shield(c: Cv, cx: float, cy: float, s: float, _t: float) -> void:
	c.save(); c.translate(cx, cy)
	var sg := Cv.linear(0, -s * 0.4, 0, s * 0.45).stop(0, "#8098b8").stop(1, "#4a6088")
	c.fs(sg)
	c.bp()
	c.mt(0, -s * 0.42)
	c.lt(s * 0.32, -s * 0.30); c.lt(s * 0.30, s * 0.1)
	c.qt(s * 0.22, s * 0.35, 0, s * 0.46)
	c.qt(-s * 0.22, s * 0.35, -s * 0.30, s * 0.1)
	c.lt(-s * 0.32, -s * 0.30); c.cp(); c.fill()
	c.ss("#c8a030"); c.lw(s * 0.045); c.stroke()
	c.ss("#e8d890"); c.lw(s * 0.05)
	c.line(0, -s * 0.22, 0, s * 0.2)
	c.line(-s * 0.15, -s * 0.04, s * 0.15, -s * 0.04)
	c.fs("#c8a030"); c.circ(0, -s * 0.04, s * 0.05)
	c.restore()


static func i_armor(c: Cv, cx: float, cy: float, s: float, _t: float) -> void:
	c.save(); c.translate(cx, cy)
	var ag := Cv.linear(-s * 0.3, 0, s * 0.3, 0).stop(0, "#787f8f").stop(0.5, "#b8c0d0").stop(1, "#687080")
	c.fs(ag)
	c.bp()
	c.mt(-s * 0.3, -s * 0.34)
	c.qt(0, -s * 0.44, s * 0.3, -s * 0.34)
	c.lt(s * 0.34, s * 0.05)
	c.qt(s * 0.2, s * 0.4, 0, s * 0.44)
	c.qt(-s * 0.2, s * 0.4, -s * 0.34, s * 0.05)
	c.cp(); c.fill()
	c.fs("#2a2018"); c.ell(0, -s * 0.34, s * 0.12, s * 0.06)
	c.ss("#586070"); c.lw(ilw(s) * 1.2)
	c.line(0, -s * 0.24, 0, s * 0.3)
	c.bp(); c.arc(-s * 0.13, -s * 0.08, s * 0.1, PI * 1.3, PI * 1.9); c.stroke()
	c.bp(); c.arc(s * 0.13, -s * 0.08, s * 0.1, PI * 1.1, PI * 1.7); c.stroke()
	c.fs("#c8a030"); c.circ(0, s * 0.05, s * 0.05)
	c.restore()


static func _flask_path(c: Cv, s: float, close: bool) -> void:
	c.bp()
	c.mt(-s * 0.07, -s * 0.28); c.lt(-s * 0.07, -s * 0.12)
	c.bt(-s * 0.3, -s * 0.02, -s * 0.3, s * 0.35, 0, s * 0.4)
	c.bt(s * 0.3, s * 0.35, s * 0.3, -s * 0.02, s * 0.07, -s * 0.12)
	c.lt(s * 0.07, -s * 0.28)
	if close:
		c.cp()


static func i_heal(c: Cv, cx: float, cy: float, s: float, t: float) -> void:
	c.save(); c.translate(cx, cy)
	c.fs(rgba(200, 230, 255, 0.25))
	_flask_path(c, s, true); c.fill()
	var lv := sin(t * 0.08) * s * 0.015
	c.fs("#d02838")
	c.bp()
	c.mt(-s * 0.2, s * 0.06 + lv)
	c.bt(-s * 0.26, s * 0.2, -s * 0.2, s * 0.34, 0, s * 0.37)
	c.bt(s * 0.2, s * 0.34, s * 0.26, s * 0.2, s * 0.2, s * 0.06 - lv)
	c.cp(); c.fill()
	c.fs(rgba(255, 120, 130, 0.7))
	c.circ(-s * 0.06, s * 0.18 + lv * 2, s * 0.03)
	c.circ(s * 0.08, s * 0.25, s * 0.02)
	c.ss(rgba(230, 240, 255, 0.7)); c.lw(ilw(s) * 1.2)
	_flask_path(c, s, false); c.stroke()
	c.fs("#8a6030"); c.fill_rect(-s * 0.08, -s * 0.38, s * 0.16, s * 0.11)
	c.ss(rgba(255, 255, 255, 0.6)); c.lw(ilw(s) * 1.3)
	c.bp(); c.arc(-s * 0.1, s * 0.1, s * 0.16, PI * 0.9, PI * 1.3); c.stroke()
	c.restore()


static func i_maxheal(c: Cv, cx: float, cy: float, s: float, t: float) -> void:
	c.save(); c.translate(cx, cy)
	var beat := 1 + 0.06 * sin(t * 0.15)
	c.scale(beat, beat)
	i_maxheal_shape(c, s)
	c.restore()


## a szív alakja (a lüktetés kívülről, nagyítással kerül rá)
static func i_maxheal_shape(c: Cv, s: float) -> void:
	var hg := Cv.radial(0, -s * 0.03, s * 0.05, s * 0.4).stop(0, "#ffd870").stop(1, "#d09010")
	c.fs(hg)
	c.bp()
	c.mt(0, s * 0.32)
	c.bt(-s * 0.42, s * 0.02, -s * 0.32, -s * 0.34, 0, -s * 0.12)
	c.bt(s * 0.32, -s * 0.34, s * 0.42, s * 0.02, 0, s * 0.32)
	c.fill()
	c.ss("#a87010"); c.lw(ilw(s) * 1.3); c.stroke()
	c.ss("#fff8e0"); c.lw(s * 0.055)
	c.line(0, -s * 0.1, 0, s * 0.14)
	c.line(-s * 0.1, 0.01, s * 0.1, 0.01)


static func _scroll(c: Cv, cx: float, cy: float, s: float, ribbon: String) -> void:
	c.save(); c.translate(cx, cy)
	c.fs("#e0cc9a"); c.fill_rect(-s * 0.24, -s * 0.3, s * 0.48, s * 0.6)
	c.ss("#a8946a"); c.lw(ilw(s)); c.stroke_rect(-s * 0.24, -s * 0.3, s * 0.48, s * 0.6)
	c.fs("#c8b078")
	c.ell(0, -s * 0.3, s * 0.27, s * 0.055)
	c.ell(0, s * 0.3, s * 0.27, s * 0.055)
	c.ss("#8a7a50"); c.stroke()
	c.fs(ribbon); c.fill_rect(-s * 0.26, s * 0.06, s * 0.09, s * 0.16)
	c.restore()


static func i_atk_up(c: Cv, cx: float, cy: float, s: float, _t: float) -> void:
	_scroll(c, cx, cy, s, "#c03030")
	c.ss("#e04040"); c.lw(s * 0.05)
	c.bp()
	c.mt(cx + s * 0.05, cy - s * 0.16); c.lt(cx - s * 0.06, cy + 0.01)
	c.lt(cx + s * 0.03, cy + 0.01); c.lt(cx - s * 0.05, cy + s * 0.17)
	c.stroke()


static func i_def_up(c: Cv, cx: float, cy: float, s: float, _t: float) -> void:
	_scroll(c, cx, cy, s, "#3060c0")
	c.ss("#4878d8"); c.lw(s * 0.045)
	c.bp()
	c.mt(cx, cy - s * 0.15); c.lt(cx + s * 0.1, cy - s * 0.09)
	c.lt(cx + s * 0.09, cy + s * 0.05); c.qt(cx + s * 0.05, cy + s * 0.14, cx, cy + s * 0.17)
	c.qt(cx - s * 0.05, cy + s * 0.14, cx - s * 0.09, cy + s * 0.05)
	c.lt(cx - s * 0.1, cy - s * 0.09); c.cp(); c.stroke()


static func i_fireball(c: Cv, cx: float, cy: float, s: float, t: float) -> void:
	c.save(); c.translate(cx, cy)
	var flick := 0.85 + 0.15 * sin(t * 0.3)
	var fg := Cv.radial(0, 0, s * 0.05, s * 0.38 * flick).stop(0, "#fff0a0").stop(0.4, "#ff9020").stop(1, rgba(200, 40, 10, 0))
	c.fs(fg); c.circ(0, 0, s * 0.42)
	c.fs("#ffb838"); c.circ(0, 0, s * 0.19)
	c.fs(rgba(255, 120, 20, 0.8 * flick))
	for i in 5:
		var a := i * 1.256 + t * 0.05
		var fx2 := cos(a) * s * 0.24
		var fy2 := sin(a) * s * 0.24
		c.bp()
		c.mt(fx2, fy2)
		c.qt(fx2 * 1.8, fy2 * 1.8 - s * 0.1, fx2 * 1.4, fy2 * 1.4 - s * 0.22)
		c.qt(fx2 * 1.2, fy2 * 1.2, fx2 * 0.6, fy2 * 0.6)
		c.fill()
	c.restore()


# ══════════ CSAPDÁK, TITKOS AJTÓ, SZENTÉLY, KERESKEDŐ ══════════
## Mindegyik mozdulatlan (a szentély gyöngye kivételével), ezért kész hálóból kerül ki: a
## kulcs a fajtát és a méretet tartalmazza, a visszajátszás már csak egy eltolás.
static func trap(c: Cv, type: String, px: float, py: float, s: float, sprung: bool) -> void:
	c.blit("tr|%s|%d|%d" % [type, int(roundf(s * 4.0)), 1 if sprung else 0],
		func() -> void: _trap_shape(c, type, s, sprung), px, py)


static func _trap_shape(c: Cv, type: String, s: float, sprung: bool) -> void:
	var h := s / 2.0
	match type:
		"tuske":
			c.fs("#4a4438" if not sprung else "#5a2a22")
			c.rrect(s * 0.16, s * 0.16, s * 0.68, s * 0.68, s * 0.08); c.fill()
			c.ss("#8a8270" if not sprung else "#c05040"); c.lw(1.4)
			c.rrect(s * 0.16, s * 0.16, s * 0.68, s * 0.68, s * 0.08); c.stroke()
			c.fs("#d8dce8" if not sprung else "#e06050")
			for i in 4:
				var tx := s * (0.30 + 0.13 * i)
				c.poly([tx, s * 0.70, tx + s * 0.055, s * 0.30, tx + s * 0.11, s * 0.70])
		"mereg":
			c.fs("#2a3a18")
			c.rrect(s * 0.16, s * 0.16, s * 0.68, s * 0.68, s * 0.22); c.fill()
			c.ss("#90c030"); c.lw(1.4)
			c.rrect(s * 0.16, s * 0.16, s * 0.68, s * 0.68, s * 0.22); c.stroke()
			c.fs("#7ac030" if not sprung else "#b0e050")
			c.circ(s * 0.40, s * 0.44, s * 0.09)
			c.circ(s * 0.60, s * 0.56, s * 0.07)
			c.circ(s * 0.52, s * 0.34, s * 0.05)
		_:
			c.fs("#3a3020")
			c.rrect(s * 0.18, s * 0.18, s * 0.64, s * 0.64, s * 0.08); c.fill()
			c.ss("#e0a030"); c.lw(1.5)
			c.rrect(s * 0.18, s * 0.18, s * 0.64, s * 0.64, s * 0.08); c.stroke()
			c.fs("#e0a030" if not sprung else "#8a6820")
			c.bp(); c.arc(s * 0.5, s * 0.52, s * 0.17, PI, 0.0); c.fill()
			c.fill_rect(s * 0.30, s * 0.50, s * 0.40, s * 0.06)
			c.circ(s * 0.5, s * 0.64, s * 0.05)


## a megtalált titkos ajtó: nyitott boltív a falban
static func secret_door(c: Cv, px: float, py: float, s: float) -> void:
	c.blit("sd|%d" % int(roundf(s * 4.0)), func() -> void:
		c.fs("#241a10")
		c.rrect(s * 0.14, s * 0.10, s * 0.72, s * 0.82, s * 0.06); c.fill()
		c.ss("#8a6a2e"); c.lw(2.0)
		c.bp()
		c.mt(s * 0.18, s * 0.90)
		c.lt(s * 0.18, s * 0.42)
		c.arc(s * 0.50, s * 0.42, s * 0.32, PI, 0.0)
		c.lt(s * 0.82, s * 0.90)
		c.stroke()
		c.fs("#d4a84b")
		c.circ(s * 0.68, s * 0.58, s * 0.05), px, py)


static func shrine(c: Cv, px: float, py: float, s: float, kind: String, used: bool, t: float) -> void:
	var col: String = Data.SHRINES.get(kind, {}).get("col", "#70d0ff")
	c.blit("shr|%d|%d" % [int(roundf(s * 4.0)), 1 if used else 0], func() -> void:
		c.fs("#3a3a42")
		c.poly([s * 0.24, s * 0.90, s * 0.32, s * 0.34, s * 0.68, s * 0.34, s * 0.76, s * 0.90])
		c.fs("#55555f"); c.fill_rect(s * 0.20, s * 0.86, s * 0.60, s * 0.08)
		c.ss("#7a7a88"); c.lw(1.0)
		c.line(s * 0.34, s * 0.50, s * 0.66, s * 0.50), px, py)
	if used:
		c.fs("#4a4a52")
		c.circ(px + s * 0.5, py + s * 0.30, s * 0.11)
		return
	if glow_tex:
		var gc: Color = Cv.col(col)
		gc.a = 0.28 + 0.16 * sin(t * 0.08)
		c.tex(glow_tex, Rect2(px + s * 0.5 - s * 0.8, py + s * 0.30 - s * 0.8, s * 1.6, s * 1.6), gc)
	c.fs(col)
	c.circ(px + s * 0.5, py + s * 0.30, s * 0.12)
	c.fs("#ffffff")
	c.circ(px + s * 0.46, py + s * 0.26, s * 0.04)


static func merchant(c: Cv, px: float, py: float, s: float, t: float) -> void:
	var bob := sin(t * 0.05) * s * 0.02
	c.blit("mer|%d" % int(roundf(s * 4.0)), func() -> void:
		c.fs("#3a2a5a")
		c.bp(); c.mt(s * 0.50, s * 0.18); c.lt(s * 0.22, s * 0.88); c.lt(s * 0.78, s * 0.88); c.cp(); c.fill()
		c.ss("#7a5aaa"); c.lw(1.2); c.stroke()
		c.fs("#d8b090")
		c.circ(s * 0.50, s * 0.30, s * 0.11)
		c.fs("#2a1a44")
		c.bp(); c.arc(s * 0.50, s * 0.29, s * 0.14, PI * 0.95, PI * 2.05); c.fill()
		c.fs("#20102a"); c.fill_rect(s * 0.40, s * 0.28, s * 0.20, s * 0.04)
		c.fs("#6a4a20"); c.rrect(s * 0.60, s * 0.52, s * 0.22, s * 0.22, s * 0.05); c.fill()
		c.ss("#d4a84b"); c.lw(1.0); c.rrect(s * 0.60, s * 0.52, s * 0.22, s * 0.22, s * 0.05); c.stroke(), px, py + bob)
	c.fs("#ffd700")
	c.circ(px + s * 0.71, py + bob + s * 0.63, s * 0.055)


# ══════════ DÍSZEK (amfora, pókháló, repedés...) ══════════
static func decor(c: Cv, type: String, px: float, py: float, s: float, sd: float) -> void:
	match type:
		"amphora":
			var cx := px + s / 2
			var base := py + s * 0.85
			# talajárnyék + sötét váz, hogy a tárgy elváljon a padlótól
			c.fs(Color(0, 0, 0, 0.30))
			c.ell(cx, base + s * 0.015, s * 0.22, s * 0.055)
			c.fs("#7c3f1a")
			c.bp()
			c.mt(cx - s * 0.18, base)
			c.bt(cx - s * 0.32, base - s * 0.28, cx - s * 0.24, base - s * 0.50, cx - s * 0.10, base - s * 0.56)
			c.lt(cx - s * 0.11, base - s * 0.65); c.lt(cx + s * 0.11, base - s * 0.65); c.lt(cx + s * 0.10, base - s * 0.56)
			c.bt(cx + s * 0.24, base - s * 0.50, cx + s * 0.32, base - s * 0.28, cx + s * 0.18, base)
			c.cp(); c.fill()
			c.fs("#a05828")
			c.bp()
			c.mt(cx - s * 0.16, base)
			c.bt(cx - s * 0.30, base - s * 0.28, cx - s * 0.22, base - s * 0.50, cx - s * 0.09, base - s * 0.55)
			c.lt(cx - s * 0.10, base - s * 0.64); c.lt(cx + s * 0.10, base - s * 0.64); c.lt(cx + s * 0.09, base - s * 0.55)
			c.bt(cx + s * 0.22, base - s * 0.50, cx + s * 0.30, base - s * 0.28, cx + s * 0.16, base)
			c.cp(); c.fill()
			c.fs("#c8803e")
			c.bp()
			c.mt(cx + s * 0.03, base - s * 0.03)
			c.bt(cx + s * 0.19, base - s * 0.28, cx + s * 0.15, base - s * 0.47, cx + s * 0.06, base - s * 0.53)
			c.lt(cx + s * 0.03, base - s * 0.53); c.cp(); c.fill()
			c.ss("#7a3c18"); c.lw(1.4)
			c.line(cx - s * 0.13, base - s * 0.62, cx + s * 0.13, base - s * 0.62)
			c.bp(); c.arc(cx - s * 0.20, base - s * 0.48, s * 0.08, PI * 0.4, PI * 1.4); c.stroke()
			c.bp(); c.arc(cx + s * 0.20, base - s * 0.48, s * 0.08, PI * 1.6, PI * 0.6); c.stroke()
			c.ss("#d4a84b"); c.lw(1)
			c.line(cx - s * 0.22, base - s * 0.32, cx + s * 0.22, base - s * 0.32)
		"barrel":
			var cx := px + s / 2
			var cy := py + s * 0.55
			c.fs(Color(0, 0, 0, 0.30))
			c.ell(cx, cy + s * 0.34, s * 0.24, s * 0.06)
			c.fs("#4d3116"); c.ell(cx, cy, s * 0.27, s * 0.35)
			c.fs("#6a4520"); c.ell(cx + s * 0.01, cy, s * 0.25, s * 0.33)
			c.fs("#8a5c2c"); c.ell(cx + s * 0.09, cy - s * 0.02, s * 0.10, s * 0.26)
			c.ss("#3a2410"); c.lw(1.4)
			c.bp(); c.ellipse(cx, cy, s * 0.26, s * 0.34, 0, 0, 7); c.stroke()
			c.ss("#6e675f"); c.lw(1.8)
			c.line(cx - s * 0.25, cy - s * 0.14, cx + s * 0.25, cy - s * 0.14)
			c.line(cx - s * 0.25, cy + s * 0.14, cx + s * 0.25, cy + s * 0.14)
			c.ss("#a29a90"); c.lw(0.7)
			c.line(cx - s * 0.25, cy - s * 0.155, cx + s * 0.25, cy - s * 0.155)
			c.line(cx - s * 0.25, cy + s * 0.125, cx + s * 0.25, cy + s * 0.125)
			c.ss("#523618"); c.lw(0.8)
			c.line(cx, cy - s * 0.33, cx, cy + s * 0.33)
		"web":
			var corner := int(floorf(Data.rnd_seed(sd) * 4))
			var ox := px if corner % 2 == 0 else px + s
			var oy := py if corner < 2 else py + s
			var sx2 := 1.0 if corner % 2 == 0 else -1.0
			var sy2 := 1.0 if corner < 2 else -1.0
			c.ss(rgba(220, 220, 230, 0.4)); c.lw(0.7)
			for i in 5:
				var ang := (i / 4.0) * PI / 2
				c.line(ox, oy, ox + sx2 * cos(ang) * s * 0.7, oy + sy2 * sin(ang) * s * 0.7)
			var r2 := 0.25
			while r2 <= 0.62:
				c.bp()
				for i in 5:
					var ang := (i / 4.0) * PI / 2
					var wx := ox + sx2 * cos(ang) * s * r2
					var wy := oy + sy2 * sin(ang) * s * r2
					if i == 0: c.mt(wx, wy)
					else: c.lt(wx, wy)
				c.stroke()
				r2 += 0.18
		"crack":
			c.ss(rgba(10, 8, 6, 0.8)); c.lw(1.3)
			var x := px + s * (0.3 + Data.rnd_seed(sd) * 0.4)
			var y := py + s * 0.08
			c.bp(); c.mt(x, y)
			for i in 4:
				x += (Data.rnd_seed(sd + i * 3) - 0.5) * s * 0.4
				y += s * 0.22
				c.lt(x, y)
			c.stroke()
			c.lw(0.8)
			c.line(px + s * 0.5, py + s * 0.4, px + s * 0.5 + (Data.rnd_seed(sd + 9) - 0.5) * s * 0.5, py + s * 0.55)
		"bones":
			var cx := px + s / 2
			var cy := py + s * 0.6
			c.ss("#d8d0b8"); c.lw(2)
			c.save(); c.translate(cx, cy); c.rotate(Data.rnd_seed(sd) * 3)
			c.line(-s * 0.2, 0, s * 0.2, 0)
			c.fs("#d8d0b8")
			for ex in [-s * 0.2, s * 0.2]:
				c.circ(ex, -s * 0.045, s * 0.05)
				c.circ(ex, s * 0.045, s * 0.05)
			c.restore()
		"skull":
			var cx := px + s / 2
			var cy := py + s * 0.55
			c.fs("#d0c8b0")
			c.circ(cx, cy, s * 0.14)
			c.fill_rect(cx - s * 0.09, cy + s * 0.06, s * 0.18, s * 0.09)
			c.fs("#181410")
			c.circ(cx - s * 0.05, cy - s * 0.02, s * 0.04)
			c.circ(cx + s * 0.05, cy - s * 0.02, s * 0.04)
		"rubble":
			c.fs("#5a5048")
			for i in 4:
				var rx := px + s * (0.2 + Data.rnd_seed(sd + i) * 0.6)
				var ry := py + s * (0.4 + Data.rnd_seed(sd + i * 7) * 0.4)
				var rr2 := s * (0.04 + Data.rnd_seed(sd + i * 13) * 0.06)
				c.circ(rx, ry, rr2)
		"moss":
			c.fs(rgba(60, 110, 40, 0.5))
			for i in 3:
				var mx := px + s * Data.rnd_seed(sd + i * 5)
				var my := py + s * (0.6 + Data.rnd_seed(sd + i * 11) * 0.35)
				c.ell(mx, my, s * 0.14, s * 0.07, Data.rnd_seed(sd + i) * 3)
		"puddle":
			c.fs(rgba(20, 30, 50, 0.55))
			c.ell(px + s / 2, py + s * 0.6, s * 0.3, s * 0.17)
			c.ss(rgba(120, 150, 200, 0.25)); c.lw(0.8)
			c.bp(); c.ellipse(px + s / 2, py + s * 0.6, s * 0.22, s * 0.11, 0, 0, 7); c.stroke()
