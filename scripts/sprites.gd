class_name Sprites
extends RefCounted
## Az összes rajzolt figura: hősök, szörnyek, tárgy-ikonok, díszek.
## Sorról sorra az eredeti canvas-rajzolók átirata (Cv = ctx).

static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Cv.rgba(r, g, b, a)


# ══════════ HŐSÖK ══════════
static func hero(c: Cv, cls: String, cx: float, cy: float, size: float, t: float) -> void:
	match cls:
		"Lovag": knight(c, cx, cy, size, t)
		"Mágus": mage(c, cx, cy, size, t)
		_: archer(c, cx, cy, size, t)


static func knight(c: Cv, cx: float, cy: float, size: float, t: float) -> void:
	var s := size / 40.0
	c.save()
	c.translate(cx, cy)
	var bob := sin(t * 0.05) * s
	c.fs("#5a1818")
	c.bp(); c.mt(-8 * s, -8 * s + bob); c.qt(-13 * s, 8 * s, -9 * s, 16 * s); c.lt(-3 * s, 12 * s); c.cp(); c.fill()
	c.fs("#3a3a44"); c.fill_rect(-5 * s, 8 * s, 4 * s, 10 * s); c.fill_rect(1 * s, 8 * s, 4 * s, 10 * s)
	c.fs("#8a90a0"); c.rrect(-7 * s, -6 * s + bob, 14 * s, 15 * s, 3 * s); c.fill()
	c.ss("#c8d0e0"); c.lw(1); c.rrect(-7 * s, -6 * s + bob, 14 * s, 15 * s, 3 * s); c.stroke()
	c.ss("#d4a84b"); c.lw(1.5 * s)
	c.line(0, -4 * s + bob, 0, 5 * s + bob)
	c.line(-4 * s, -1 * s + bob, 4 * s, -1 * s + bob)
	c.fs("#9aa0b0")
	c.bp(); c.arc(0, -12 * s + bob, 6.5 * s, PI, 0); c.fill()
	c.fill_rect(-6.5 * s, -12 * s + bob, 13 * s, 5 * s)
	c.fs("#181820"); c.fill_rect(-4.5 * s, -11 * s + bob, 9 * s, 1.6 * s)
	c.fs("#c03030")
	c.bp(); c.mt(0, -18 * s + bob); c.qt(4 * s, -22 * s, 7 * s, -18 * s + bob); c.qt(3 * s, -17 * s, 0, -15 * s + bob); c.cp(); c.fill()
	c.ss("#c8d0e0"); c.lw(2 * s)
	c.line(9 * s, 4 * s + bob, 15 * s, -12 * s + bob)
	c.ss("#8a6820"); c.lw(1.6 * s)
	c.line(8 * s, 1 * s + bob, 11.5 * s, -3 * s + bob)
	c.fs("#7a5a2a")
	c.bp(); c.mt(-9 * s, -2 * s + bob); c.lt(-14 * s, 0 + bob); c.lt(-13 * s, 8 * s + bob); c.lt(-9 * s, 10 * s + bob); c.cp(); c.fill()
	c.ss("#d4a84b"); c.lw(1); c.stroke()
	c.restore()


static func mage(c: Cv, cx: float, cy: float, size: float, t: float) -> void:
	var s := size / 40.0
	c.save()
	c.translate(cx, cy)
	var bob := sin(t * 0.05 + 1) * s
	c.fs("#3a1a6a")
	c.bp(); c.mt(-3 * s, -10 * s + bob); c.lt(-9 * s, 18 * s); c.lt(9 * s, 18 * s); c.lt(3 * s, -10 * s + bob); c.cp(); c.fill()
	c.ss("#6a3aaa"); c.lw(1); c.stroke()
	c.fs("#d4a84b"); c.fill_rect(-5 * s, 2 * s + bob, 10 * s, 1.6 * s)
	c.fs("#d8b090"); c.circ(0, -13 * s + bob, 5 * s)
	c.fs("#c8c8d0")
	c.bp(); c.mt(-4 * s, -11 * s + bob); c.qt(0, -2 * s + bob, 4 * s, -11 * s + bob); c.cp(); c.fill()
	c.fs("#2a1050")
	c.bp(); c.mt(-8 * s, -15 * s + bob); c.lt(8 * s, -15 * s + bob); c.lt(1 * s, -30 * s + bob); c.cp(); c.fill()
	c.ss("#6a3aaa"); c.lw(1); c.stroke()
	# ★ (az eredetiben szöveg-karakter; itt rajzolt ötágú csillag, hogy a figura gyorsítótárazható legyen)
	c.fs("#ffd700")
	star(c, -1 * s, -20.8 * s + bob, 2.3 * s)
	c.ss("#6a4a20"); c.lw(1.8 * s)
	c.line(10 * s, 16 * s, 12 * s, -16 * s + bob)
	var gl := 0.5 + 0.5 * sin(t * 0.1)
	var og := Cv.radial(12 * s, -18 * s + bob, 1, 7 * s).stop(0, rgba(120, 220, 255, 0.9 * gl)).stop(1, rgba(60, 140, 255, 0))
	c.fs(og); c.fill_rect(5 * s, -25 * s + bob, 14 * s, 14 * s)
	c.fs("#a0e0ff"); c.circ(12 * s, -18 * s + bob, 3 * s)
	c.restore()


static func archer(c: Cv, cx: float, cy: float, size: float, t: float) -> void:
	var s := size / 40.0
	c.save()
	c.translate(cx, cy)
	var bob := sin(t * 0.05 + 2) * s
	c.fs("#4a3a20"); c.fill_rect(-5 * s, 8 * s, 4 * s, 10 * s); c.fill_rect(1 * s, 8 * s, 4 * s, 10 * s)
	c.fs("#2a5a2a"); c.rrect(-6 * s, -6 * s + bob, 12 * s, 15 * s, 3 * s); c.fill()
	c.ss("#4a8a3a"); c.lw(1); c.rrect(-6 * s, -6 * s + bob, 12 * s, 15 * s, 3 * s); c.stroke()
	c.fs("#6a4a20"); c.fill_rect(-6 * s, 3 * s + bob, 12 * s, 2 * s)
	c.save(); c.rotate(-0.3); c.fs("#6a4a20"); c.rrect(-11 * s, -8 * s + bob, 4 * s, 12 * s, 1.5 * s); c.fill(); c.restore()
	c.ss("#d4a84b"); c.lw(0.8 * s)
	c.line(-10 * s, -9 * s + bob, -8 * s, -13 * s + bob)
	c.line(-8.5 * s, -8 * s + bob, -6.5 * s, -12.5 * s + bob)
	c.fs("#d8b090"); c.circ(0, -12 * s + bob, 5 * s)
	c.fs("#1e4a1e")
	c.bp(); c.arc(0, -13 * s + bob, 6 * s, PI * 0.9, PI * 2.1); c.fill()
	c.bp(); c.mt(-6 * s, -12 * s + bob); c.lt(0, -6 * s + bob); c.lt(6 * s, -12 * s + bob); c.cp(); c.fill()
	c.ss("#8a6820"); c.lw(1.8 * s)
	c.bp(); c.arc(11 * s, -2 * s + bob, 10 * s, -PI * 0.42, PI * 0.42); c.stroke()
	c.ss("#d0d0c0"); c.lw(0.7 * s)
	c.line(11 * s + 10 * s * cos(-PI * 0.42), -2 * s + bob + 10 * s * sin(-PI * 0.42),
		11 * s + 10 * s * cos(PI * 0.42), -2 * s + bob + 10 * s * sin(PI * 0.42))
	c.ss("#d4a84b"); c.lw(1 * s)
	c.line(3 * s, -2 * s + bob, 20 * s, -2 * s + bob)
	c.restore()


static func star(c: Cv, x: float, y: float, r: float) -> void:
	var pts: Array = []
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(x + cos(a) * rr)
		pts.append(y + sin(a) * rr)
	c.poly(pts)


## hős-figura gyorsítótárból: a lebegés fázisa 16 lépésre kerekítve, a kész háló csak eltolódik
static var _hero_cache := {}


static func hero_cached(c: Cv, cls: String, cx: float, cy: float, size: float, t: float) -> void:
	var period := TAU / 0.05
	var ph := int(floorf(fposmod(t, period) / period * 16.0)) % 16
	var key := "%s|%d|%d" % [cls, int(roundf(size * 4.0)), ph]
	if not _hero_cache.has(key):
		if _hero_cache.size() > 400:
			_hero_cache.clear()
		c.rec_begin()
		hero(c, cls, 0, 0, size, ph * period / 16.0)
		_hero_cache[key] = c.rec_end()
	c.replay(_hero_cache[key], Transform2D(0.0, Vector2(cx, cy)))


# ══════════ SZÖRNYEK ══════════
static func mon_bob(t: float, sd: float) -> float:
	return sin(t * 0.08 + sd) * 1.5


static func monster(c: Cv, key: String, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
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


static func goblin(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#3a7028"); c.ell(0, 3 * s, 7 * s, 8 * s)
	c.fs("#4a8c30"); c.circ(0, -6 * s, 6 * s)
	# fülek
	c.fs("#4a8c30")
	c.poly([-5 * s, -9 * s, -11 * s, -13 * s, -4 * s, -5 * s])
	c.poly([5 * s, -9 * s, 11 * s, -13 * s, 4 * s, -5 * s])
	# szemek
	c.fs("#f0e030")
	c.circ(-2.5 * s, -7 * s, 1.3 * s)
	c.circ(2.5 * s, -7 * s, 1.3 * s)
	# tőr
	c.ss("#b0b0b0"); c.lw(1.2 * s)
	c.line(7 * s, 2 * s, 12 * s, -4 * s)
	c.restore()


static func skeleton(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#d8d0b8"); c.circ(0, -7 * s, 5.5 * s)
	c.fill_rect(-3.5 * s, -4 * s, 7 * s, 3 * s)
	c.fs("#181410")
	c.circ(-2.2 * s, -8 * s, 1.6 * s)
	c.circ(2.2 * s, -8 * s, 1.6 * s)
	c.ss("#d8d0b8"); c.lw(1.3 * s)
	c.line(0, -1 * s, 0, 10 * s)
	for i in 3:
		c.bp(); c.mt(-5 * s, 1 * s + i * 3 * s); c.qt(0, 3 * s + i * 3 * s, 5 * s, 1 * s + i * 3 * s); c.stroke()
	c.line(-5 * s, 1 * s, -9 * s, 7 * s)
	c.line(5 * s, 1 * s, 9 * s, 7 * s)
	c.restore()


static func orc(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#7a4020"); c.ell(0, 4 * s, 9 * s, 9 * s)
	c.fs("#8a5028"); c.circ(0, -6 * s, 7 * s)
	c.fs("#e8e0c8")
	c.poly([-3.5 * s, -2 * s, -4.5 * s, -6 * s, -2 * s, -3 * s])
	c.poly([3.5 * s, -2 * s, 4.5 * s, -6 * s, 2 * s, -3 * s])
	c.fs("#e03020")
	c.circ(-2.8 * s, -8 * s, 1.4 * s)
	c.circ(2.8 * s, -8 * s, 1.4 * s)
	c.ss("#5a3a18"); c.lw(2.4 * s)
	c.line(8 * s, 6 * s, 14 * s, -4 * s)
	c.fs("#5a3a18"); c.circ(14 * s, -5 * s, 3 * s)
	c.restore()


static func vampire(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#280818")
	c.poly([0, -10 * s, -11 * s, 12 * s, -4 * s, 9 * s, 0, 12 * s, 4 * s, 9 * s, 11 * s, 12 * s])
	c.fs("#3a1024"); c.fill_rect(-4 * s, -4 * s, 8 * s, 13 * s)
	c.fs("#d8c8c0"); c.circ(0, -8 * s, 4.5 * s)
	c.fs("#181018")
	c.bp(); c.arc(0, -9.5 * s, 4.5 * s, PI, 0); c.fill()
	c.fs("#f02020")
	c.circ(-1.8 * s, -8 * s, 1 * s)
	c.circ(1.8 * s, -8 * s, 1 * s)
	c.fs("#ffffff")
	c.fill_rect(-1.6 * s, -5.5 * s, 1 * s, 2 * s); c.fill_rect(0.6 * s, -5.5 * s, 1 * s, 2 * s)
	c.restore()


static func spider(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd) * 0.5
	c.save(); c.translate(cx, cy + b)
	c.ss("#503810"); c.lw(1.2 * s)
	for i in 4:
		var wig := sin(t * 0.15 + i) * 2 * s
		c.bp(); c.mt(-3 * s, 0); c.qt(-9 * s, -4 * s + wig, -13 * s, 3 * s + i * 2 * s); c.stroke()
		c.bp(); c.mt(3 * s, 0); c.qt(9 * s, -4 * s - wig, 13 * s, 3 * s + i * 2 * s); c.stroke()
	c.fs("#684818"); c.ell(0, 2 * s, 6 * s, 7 * s)
	c.fs("#806018"); c.circ(0, -5 * s, 4 * s)
	c.fs("#c03030"); c.ell(0, 2 * s, 1.6 * s, 3 * s)
	c.fs("#f0e030")
	for i in [-1, 1]:
		c.circ(i * 1.7 * s, -6 * s, 0.9 * s)
	c.restore()


static func golem(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	c.save(); c.translate(cx, cy)
	c.fs("#787868"); c.rrect(-8 * s, -4 * s, 16 * s, 14 * s, 2 * s); c.fill()
	c.fs("#8a8a78"); c.rrect(-6 * s, -12 * s, 12 * s, 9 * s, 2 * s); c.fill()
	c.ss("#585848"); c.lw(0.8 * s)
	c.bp(); c.mt(-3 * s, -10 * s); c.lt(-1 * s, -6 * s); c.lt(-4 * s, -4 * s); c.stroke()
	c.line(3 * s, 2 * s, 5 * s, 6 * s)
	var gl := 0.6 + 0.4 * sin(t * 0.06 + sd)
	c.fs(rgba(255, 150, 30, gl))
	c.fill_rect(-4 * s, -9.5 * s, 2.4 * s, 1.8 * s); c.fill_rect(1.6 * s, -9.5 * s, 2.4 * s, 1.8 * s)
	c.fs("#6a6a5a")
	c.rrect(-12 * s, -3 * s, 4 * s, 11 * s, 2 * s); c.fill()
	c.rrect(8 * s, -3 * s, 4 * s, 11 * s, 2 * s); c.fill()
	c.restore()


static func witch(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#401060")
	c.poly([-2 * s, -8 * s, -8 * s, 12 * s, 8 * s, 12 * s, 2 * s, -8 * s])
	c.fs("#90b060"); c.circ(0, -10 * s, 4 * s)
	c.fs("#280840")
	c.poly([-7 * s, -12 * s, 7 * s, -12 * s, 1 * s, -24 * s])
	c.fill_rect(-8 * s, -13 * s, 16 * s, 1.6 * s)
	c.fs("#f0e030")
	c.circ(-1.6 * s, -10.5 * s, 0.9 * s)
	c.circ(1.6 * s, -10.5 * s, 0.9 * s)
	var og := 0.5 + 0.5 * sin(t * 0.12 + sd)
	c.fs(rgba(200, 80, 255, og))
	c.circ(9 * s, -6 * s + sin(t * 0.1) * 2 * s, 2.4 * s)
	c.restore()


static func assassin(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.alpha *= 0.85
	c.fs("#20201c")
	c.poly([0, -12 * s, -8 * s, 12 * s, 8 * s, 12 * s])
	c.fs("#2a2a24")
	c.bp(); c.arc(0, -9 * s, 5 * s, PI * 0.85, PI * 2.15); c.fill()
	c.fs("#e02020")
	c.fill_rect(-2.6 * s, -9.5 * s, 1.8 * s, 1 * s); c.fill_rect(0.8 * s, -9.5 * s, 1.8 * s, 1 * s)
	c.ss("#a0a8b0"); c.lw(1 * s)
	c.line(-7 * s, 2 * s, -11 * s, -3 * s)
	c.line(7 * s, 2 * s, 11 * s, -3 * s)
	c.restore()


static func troll(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#a05028"); c.ell(0, 2 * s, 10 * s, 10 * s)
	c.fs("#b05c30"); c.circ(0, -8 * s, 6 * s)
	c.fs("#8a4520"); c.fill_rect(-4 * s, -5 * s, 8 * s, 2.4 * s)
	c.fs("#e8e0c8")
	c.fill_rect(-3.4 * s, -6 * s, 1.4 * s, 2 * s); c.fill_rect(2 * s, -6 * s, 1.4 * s, 2 * s)
	c.fs("#301808")
	c.circ(-2.4 * s, -10 * s, 1 * s)
	c.circ(2.4 * s, -10 * s, 1 * s)
	c.fs("#94481f")
	c.ell(-10 * s, 4 * s, 3.4 * s, 7 * s, 0.3)
	c.ell(10 * s, 4 * s, 3.4 * s, 7 * s, -0.3)
	c.restore()


static func demon(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#5a0808")
	c.bp(); c.mt(-4 * s, -4 * s); c.qt(-16 * s, -14 * s, -14 * s, 2 * s); c.qt(-9 * s, -2 * s, -4 * s, 2 * s); c.cp(); c.fill()
	c.bp(); c.mt(4 * s, -4 * s); c.qt(16 * s, -14 * s, 14 * s, 2 * s); c.qt(9 * s, -2 * s, 4 * s, 2 * s); c.cp(); c.fill()
	c.fs("#a01818"); c.ell(0, 2 * s, 7 * s, 9 * s)
	c.fs("#b82020"); c.circ(0, -8 * s, 5 * s)
	c.ss("#301008"); c.lw(1.8 * s)
	c.bp(); c.mt(-3.4 * s, -11 * s); c.qt(-6 * s, -17 * s, -3 * s, -18 * s); c.stroke()
	c.bp(); c.mt(3.4 * s, -11 * s); c.qt(6 * s, -17 * s, 3 * s, -18 * s); c.stroke()
	var gl := 0.7 + 0.3 * sin(t * 0.1 + sd)
	c.fs(rgba(255, 220, 40, gl))
	c.circ(-2 * s, -8.5 * s, 1.2 * s)
	c.circ(2 * s, -8.5 * s, 1.2 * s)
	c.restore()


# ── FŐELLENSÉGEK ──
static func goblin_king(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	goblin(c, cx, cy, sz * 1.25, t, sd)
	var s := sz * 1.25 / 30.0
	c.save(); c.translate(cx, cy + mon_bob(t, sd))
	c.fs("#ffd700")
	c.poly([-5 * s, -13 * s, -5 * s, -17 * s, -2.5 * s, -14 * s, 0, -18 * s, 2.5 * s, -14 * s, 5 * s, -17 * s, 5 * s, -13 * s])
	c.restore()


static func necromancer(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz * 1.25 / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	c.fs("#181028")
	c.poly([-2 * s, -12 * s, -10 * s, 14 * s, 10 * s, 14 * s, 2 * s, -12 * s])
	c.fs("#d8d0b8"); c.circ(0, -13 * s, 5 * s)
	c.fs("#181410")
	c.circ(-2 * s, -14 * s, 1.4 * s)
	c.circ(2 * s, -14 * s, 1.4 * s)
	c.fs("#241838")
	c.bp(); c.arc(0, -14 * s, 6.4 * s, PI * 0.8, PI * 2.2); c.fill()
	c.ss("#3a2a18"); c.lw(1.6 * s)
	c.line(11 * s, 14 * s, 13 * s, -14 * s)
	c.fs("#d8d0b8"); c.circ(13 * s, -16 * s, 3 * s)
	var gl := 0.5 + 0.5 * sin(t * 0.09)
	c.fs(rgba(120, 255, 120, gl)); c.circ(13 * s, -16 * s, 1.4 * s)
	c.restore()


static func stone_titan(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	golem(c, cx, cy, sz * 1.45, t, sd)
	var s := sz * 1.45 / 30.0
	c.save(); c.translate(cx, cy)
	var gl := 0.5 + 0.5 * sin(t * 0.05)
	c.ss(rgba(255, 170, 40, gl)); c.lw(1.4 * s)
	c.bp(); c.arc(0, 2 * s, 3.4 * s, 0, 7); c.stroke()
	c.line(0, -1.4 * s, 0, 5.4 * s)
	c.restore()


static func shadow_lord(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz * 1.3 / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	var wob := sin(t * 0.07) * 2 * s
	c.fs(rgba(60, 16, 120, 0.75))
	c.bp(); c.mt(0, -14 * s)
	c.qt(-10 * s + wob, -4 * s, -8 * s, 14 * s)
	c.qt(0, 10 * s, 8 * s, 14 * s)
	c.qt(10 * s - wob, -4 * s, 0, -14 * s); c.fill()
	c.ss(rgba(100, 40, 180, 0.5)); c.lw(1.4 * s)
	for i in 3:
		c.bp(); c.mt((-6 + i * 6) * s, 12 * s)
		c.qt((-8 + i * 7) * s + wob, 18 * s, (-5 + i * 5) * s, 22 * s); c.stroke()
	var gl := 0.7 + 0.3 * sin(t * 0.11)
	c.fs(rgba(220, 120, 255, gl))
	c.circ(-2.4 * s, -8 * s, 1.6 * s)
	c.circ(2.4 * s, -8 * s, 1.6 * s)
	c.restore()


static func dragon(c: Cv, cx: float, cy: float, sz: float, t: float, sd: float) -> void:
	var s := sz * 1.5 / 30.0
	var b := mon_bob(t, sd)
	c.save(); c.translate(cx, cy + b)
	var flap := sin(t * 0.09) * 0.25
	c.fs("#701010")
	c.save(); c.rotate(-flap)
	c.bp(); c.mt(-3 * s, -4 * s); c.qt(-20 * s, -18 * s, -17 * s, 2 * s); c.qt(-10 * s, -3 * s, -3 * s, 2 * s); c.cp(); c.fill()
	c.restore()
	c.save(); c.rotate(flap)
	c.bp(); c.mt(3 * s, -4 * s); c.qt(20 * s, -18 * s, 17 * s, 2 * s); c.qt(10 * s, -3 * s, 3 * s, 2 * s); c.cp(); c.fill()
	c.restore()
	c.fs("#c01818"); c.ell(0, 3 * s, 8 * s, 10 * s)
	c.fs("#e8b048"); c.ell(0, 5 * s, 4.4 * s, 7 * s)
	c.fs("#d02020")
	c.ell(0, -9 * s, 4.4 * s, 6 * s)
	c.ell(0, -13 * s, 3 * s, 2.4 * s)
	c.ss("#e8d8a0"); c.lw(1.6 * s)
	c.line(-3 * s, -13 * s, -6 * s, -18 * s)
	c.line(3 * s, -13 * s, 6 * s, -18 * s)
	var gl := 0.7 + 0.3 * sin(t * 0.13)
	c.fs(rgba(255, 220, 40, gl))
	c.circ(-2 * s, -11 * s, 1.3 * s)
	c.circ(2 * s, -11 * s, 1.3 * s)
	# tűzokádás
	if sin(t * 0.04) > 0.4:
		for i in 4:
			var fy := -15 * s - i * 2.4 * s
			c.fs(rgba(255, int(140 + Data.rnd_seed(sd + i) * 80), 20, 0.7 - i * 0.15))
			c.circ((Data.rnd_seed(sd + i * 7) - 0.5) * 4 * s, fy, (1.6 - i * 0.25) * s)
	c.restore()


# ══════════ TÁRGY-IKONOK (rajzolt) ══════════
static var glow_tex: Texture2D = null

static func item_icon(c: Cv, it: Item, cx: float, cy: float, size: float, t: float) -> void:
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
	match it.subtype:
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
		_: c.ftxt(it.glyph if it.glyph != "" else "?", cx, cy + size * 0.2, it.col(), size * 0.6, "center", true)


static func i_sword(c: Cv, cx: float, cy: float, s: float, _t: float) -> void:
	c.save(); c.translate(cx, cy); c.rotate(-PI / 4)
	# penge csillanással
	var bg := Cv.linear(-s * 0.05, 0, s * 0.05, 0).stop(0, "#8a98a8").stop(0.5, "#e8f0f8").stop(1, "#8a98a8")
	c.fs(bg)
	c.poly([0, -s * 0.48, s * 0.06, -s * 0.38, s * 0.06, s * 0.12, -s * 0.06, s * 0.12, -s * 0.06, -s * 0.38])
	# vérárok
	c.ss("#70808f"); c.lw(1)
	c.line(0, -s * 0.42, 0, s * 0.08)
	# keresztvas
	c.fs("#c8a030"); c.fill_rect(-s * 0.16, s * 0.12, s * 0.32, s * 0.06)
	# markolat
	c.fs("#5a3a1a"); c.fill_rect(-s * 0.045, s * 0.18, s * 0.09, s * 0.2)
	c.ss("#8a6030"); c.lw(1)
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
	c.ss("#e8e0d0"); c.lw(1)
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
	c.ss("#3a2a10"); c.lw(1.4)
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
	c.ss("#586070"); c.lw(1.2)
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
	c.ss(rgba(230, 240, 255, 0.7)); c.lw(1.2)
	_flask_path(c, s, false); c.stroke()
	c.fs("#8a6030"); c.fill_rect(-s * 0.08, -s * 0.38, s * 0.16, s * 0.11)
	c.ss(rgba(255, 255, 255, 0.6)); c.lw(1.4)
	c.bp(); c.arc(-s * 0.1, s * 0.1, s * 0.16, PI * 0.9, PI * 1.3); c.stroke()
	c.restore()


static func i_maxheal(c: Cv, cx: float, cy: float, s: float, t: float) -> void:
	c.save(); c.translate(cx, cy)
	var beat := 1 + 0.06 * sin(t * 0.15)
	c.scale(beat, beat)
	var hg := Cv.radial(0, -s * 0.03, s * 0.05, s * 0.4).stop(0, "#ffd870").stop(1, "#d09010")
	c.fs(hg)
	c.bp()
	c.mt(0, s * 0.32)
	c.bt(-s * 0.42, s * 0.02, -s * 0.32, -s * 0.34, 0, -s * 0.12)
	c.bt(s * 0.32, -s * 0.34, s * 0.42, s * 0.02, 0, s * 0.32)
	c.fill()
	c.ss("#a87010"); c.lw(1.4); c.stroke()
	c.ss("#fff8e0"); c.lw(s * 0.055)
	c.line(0, -s * 0.1, 0, s * 0.14)
	c.line(-s * 0.1, 0.01, s * 0.1, 0.01)
	c.restore()


static func _scroll(c: Cv, cx: float, cy: float, s: float, ribbon: String) -> void:
	c.save(); c.translate(cx, cy)
	c.fs("#e0cc9a"); c.fill_rect(-s * 0.24, -s * 0.3, s * 0.48, s * 0.6)
	c.ss("#a8946a"); c.lw(1); c.stroke_rect(-s * 0.24, -s * 0.3, s * 0.48, s * 0.6)
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


# ══════════ DÍSZEK (amfora, pókháló, repedés...) ══════════
static func decor(c: Cv, type: String, px: float, py: float, s: float, sd: float) -> void:
	match type:
		"amphora":
			var cx := px + s / 2
			var base := py + s * 0.85
			c.fs("#a05828")
			c.bp()
			c.mt(cx - s * 0.16, base)
			c.bt(cx - s * 0.30, base - s * 0.28, cx - s * 0.22, base - s * 0.50, cx - s * 0.09, base - s * 0.55)
			c.lt(cx - s * 0.10, base - s * 0.64); c.lt(cx + s * 0.10, base - s * 0.64); c.lt(cx + s * 0.09, base - s * 0.55)
			c.bt(cx + s * 0.22, base - s * 0.50, cx + s * 0.30, base - s * 0.28, cx + s * 0.16, base)
			c.cp(); c.fill()
			c.ss("#7a3c18"); c.lw(1.4)
			c.line(cx - s * 0.13, base - s * 0.62, cx + s * 0.13, base - s * 0.62)
			c.bp(); c.arc(cx - s * 0.20, base - s * 0.48, s * 0.08, PI * 0.4, PI * 1.4); c.stroke()
			c.bp(); c.arc(cx + s * 0.20, base - s * 0.48, s * 0.08, PI * 1.6, PI * 0.6); c.stroke()
			c.ss("#d4a84b"); c.lw(1)
			c.line(cx - s * 0.22, base - s * 0.32, cx + s * 0.22, base - s * 0.32)
		"barrel":
			var cx := px + s / 2
			var cy := py + s * 0.55
			c.fs("#6a4520"); c.ell(cx, cy, s * 0.26, s * 0.34)
			c.ss("#3a2410"); c.lw(1.6)
			c.bp(); c.ellipse(cx, cy, s * 0.26, s * 0.34, 0, 0, 7); c.stroke()
			c.ss("#8a8078"); c.lw(1.6)
			c.line(cx - s * 0.25, cy - s * 0.14, cx + s * 0.25, cy - s * 0.14)
			c.line(cx - s * 0.25, cy + s * 0.14, cx + s * 0.25, cy + s * 0.14)
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
