class_name MenuArt
extends RefCounted
## A főmenü "borítóképe": téglafal, boltív, fáklyák, sárkány, tűz, keresztbe tett kardok, díszítések.

static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Cv.rgba(r, g, b, a)


static func menu_rrect(c: Cv, x: float, y: float, w: float, h: float, r: float) -> void:
	c.rrect(x, y, w, h, r)


## A statikus háttér (egyszer rajzolódik ki; csak átméretezéskor újra)
static func static_bg(c: Cv, cw: float, ch: float, grain: Texture2D) -> void:
	var g := Cv.linear(0, 0, 0, ch).stop(0, "#0a0806").stop(0.45, "#191207").stop(1, "#080604")
	g.seg = 60.0
	c.fs(g); c.fill_rect(0, 0, cw, ch)
	# téglafal
	var k := minf(cw, ch) / 600.0
	var bh := 44 * k
	var bw := 96 * k
	var floor_y := ch * 0.78
	var row := 0
	var y := -bh
	while y < floor_y + bh:
		var off := (row % 2) * bw / 2
		var x := -bw
		while x < cw + bw:
			var sd := row * 31 + Data.jround(x / bw)
			var v := Data.rnd_seed_m(sd * 1.7)
			c.fs(Color8(int(28 + v * 18), int(21 + v * 12), int(14 + v * 8)))
			menu_rrect(c, x + off + 2 * k, y + 2 * k, bw - 4 * k, bh - 4 * k, 3 * k); c.fill()
			c.fs(rgba(255, 220, 170, 0.025 + v * 0.025))
			menu_rrect(c, x + off + 2 * k, y + 2 * k, bw - 4 * k, 3 * k, 1 * k); c.fill()
			c.fs(rgba(0, 0, 0, 0.22))
			menu_rrect(c, x + off + 2 * k, y + bh - 6 * k, bw - 4 * k, 3 * k, 1 * k); c.fill()
			x += bw
		row += 1
		y += bh
	# padló
	var fg := Cv.linear(0, floor_y, 0, ch).stop(0, "#1b140d").stop(1, "#080605")
	c.fs(fg); c.fill_rect(0, floor_y, cw, ch - floor_y)
	c.ss(rgba(0, 0, 0, 0.45)); c.lw(1.2 * k)
	var y2 := floor_y
	var st := 7 * k
	while y2 < ch:
		c.line(0, y2, cw, y2)
		st *= 1.28
		y2 += st
	var vp_y := floor_y - 180 * k
	for i in range(-16, 17):
		var xt := cw / 2 + i * 36 * k
		var tt := (ch - vp_y) / (floor_y - vp_y)
		c.line(xt, floor_y, cw / 2 + (xt - cw / 2) * tt, ch)
	c.fs(rgba(0, 0, 0, 0.32)); c.fill_rect(0, floor_y, cw, 7 * k)
	# boltív belseje
	var arch_w := minf(cw * 0.52, 420 * k)
	var arch_r := arch_w / 2
	var spring := floor_y - arch_w * 0.52
	var ig := Cv.linear(0, spring - arch_r, 0, floor_y).stop(0, "#080510").stop(0.5, "#12081a").stop(1, "#050308")
	c.fs(ig)
	_arch_path(c, cw / 2, spring, arch_r, floor_y)
	c.fill()
	var pg2 := Cv.radial(cw / 2, spring + arch_r * 0.35, 4, arch_r * 1.4).stop(0, rgba(110, 45, 155, 0.32)).stop(1, rgba(40, 10, 70, 0))
	c.fs(pg2)
	_arch_path(c, cw / 2, spring, arch_r, floor_y)
	c.fill()
	# kőgyűrű (egyetlen U alakú sokszög: külső ív + belső ív visszafelé)
	var th := 26 * k
	var ro := arch_r + th
	var sg := Cv.linear(cw / 2 - ro, 0, cw / 2 + ro, 0).stop(0, "#262018").stop(0.5, "#453a28").stop(1, "#262018")
	c.fs(sg)
	c.bp()
	c.mt(cw / 2 - ro, floor_y); c.lt(cw / 2 - ro, spring)
	c.arc(cw / 2, spring, ro, PI, 0)
	c.lt(cw / 2 + ro, floor_y); c.lt(cw / 2 + arch_r, floor_y); c.lt(cw / 2 + arch_r, spring)
	c.arc(cw / 2, spring, arch_r, 0, PI, true)
	c.lt(cw / 2 - arch_r, floor_y)
	c.cp(); c.fill()
	c.ss(rgba(8, 5, 3, 0.7)); c.lw(1.6 * k)
	for i in 11:
		var ang := PI + i * (PI / 10)
		c.line(cw / 2 + arch_r * cos(ang), spring + arch_r * sin(ang), cw / 2 + ro * cos(ang), spring + ro * sin(ang))
	c.fs("#d4a84b"); c.circ(cw / 2, spring - ro - 4 * k, 7 * k)
	c.ss("#d4a84b"); c.lw(1.6 * k)
	c.bp(); c.arc(cw / 2, spring, arch_r + th * 0.5, PI, 0); c.stroke()
	# filmszemcse
	if grain:
		c.alpha = 0.45
		c.tex_tiled(grain, Rect2(0, 0, cw, ch))
		c.alpha = 1.0


static func _arch_path(c: Cv, cx: float, spring: float, r: float, floor_y: float) -> void:
	c.bp()
	c.mt(cx - r, floor_y); c.lt(cx - r, spring)
	c.arc(cx, spring, r, PI, 0)
	c.lt(cx + r, floor_y); c.cp()


static func torch(c: Cv, x: float, y: float, k: float, t: float, ph: float, glow_tex: Texture2D) -> void:
	var fl := 0.65 + 0.35 * sin(t * 0.09 + ph) + 0.1 * sin(t * 0.29 + ph * 2)
	# fényudvar (előre elkészített sugaras textúra, erősség = fl)
	c.tex(glow_tex, Rect2(x - 200 * k, y - 200 * k, 400 * k, 400 * k), Color(1, 1, 1, clampf(fl, 0.0, 1.5) / 1.1))
	# tartó
	c.fs("#2b2118"); menu_rrect(c, x - 9 * k, y + 7 * k, 18 * k, 42 * k, 3 * k); c.fill()
	c.ss("#4a3a24"); c.lw(1.6 * k); menu_rrect(c, x - 9 * k, y + 7 * k, 18 * k, 42 * k, 3 * k); c.stroke()
	c.fs("#3a2c1c")
	c.bp(); c.mt(x - 16 * k, y + 3 * k); c.lt(x + 16 * k, y + 3 * k)
	c.lt(x + 10 * k, y + 14 * k); c.lt(x - 10 * k, y + 14 * k); c.cp(); c.fill()
	c.ss("#6a5230"); c.lw(1.6 * k); c.stroke()
	# lángok
	var cols := [rgba(200, 55, 8, 0.82), rgba(255, 140, 22, 0.92), rgba(255, 235, 160, 0.96)]
	for i in 3:
		var fh := (36 + i * 13) * k * fl
		var fw := (12 - i * 2.6) * k
		c.fs(cols[i])
		c.bp(); c.mt(x - fw, y + 2 * k)
		c.qt(x - fw * 1.4 + sin(t * 0.13 + i) * 4 * k, y - fh * 0.5, x + sin(t * 0.1 + i) * 3 * k, y - fh)
		c.qt(x + fw * 1.4 + sin(t * 0.11 + i) * 4 * k, y - fh * 0.5, x + fw, y + 2 * k)
		c.cp(); c.fill()


## A menü sárkánya. A mozdulatlan részek (test, szárnyak) hálója gyorsítótárban van, csak
## transzformálva rajzolódik újra; az izzások (száj, szemek) minden képkockán élőben készülnek.
static var _dcache := {}


static func dragon(c: Cv, cx: float, cy: float, sz: float, t: float) -> void:
	var s := sz / 30.0
	var key := int(roundf(sz * 2.0))
	if _dcache.get("key", -1) != key:
		_dcache = {"key": key}
		c.rec_begin(); _dragon_wing(c, s); _dcache["wing"] = c.rec_end()
		c.rec_begin(); _dragon_body_a(c, s); _dcache["a"] = c.rec_end()
		c.rec_begin(); _dragon_body_b(c, s); _dcache["b"] = c.rec_end()
	var flap := sin(t * 0.045) * 0.10
	var base := Transform2D(0.0, Vector2(cx, cy))
	for dir in [-1.0, 1.0]:
		c.replay(_dcache["wing"], base * Transform2D(Vector2(dir, 0), Vector2(0, 1), Vector2.ZERO) * Transform2D(-flap, Vector2.ZERO))
	c.replay(_dcache["a"], base)
	c.save(); c.translate(cx, cy)
	# nyitott száj izzása
	var th2 := 0.6 + 0.4 * sin(t * 0.14)
	var tg := Cv.radial(0, -11.6 * s, 0.4 * s, 4.2 * s).stop(0, rgba(255, 235, 160, th2)).stop(0.5, rgba(255, 130, 18, 0.6 * th2)).stop(1, rgba(200, 40, 0, 0))
	c.fs(tg); c.ell(0, -11.6 * s, 4.2 * s, 2.8 * s)
	c.restore()
	c.replay(_dcache["b"], base)
	c.save(); c.translate(cx, cy)
	# izzó szemek
	var eg := 0.72 + 0.28 * sin(t * 0.11)
	for d in [-1.0, 1.0]:
		var g2 := Cv.radial(d * 2.4 * s, -19.4 * s, 0.2 * s, 3.4 * s).stop(0, rgba(255, 255, 180, eg)).stop(0.4, rgba(255, 195, 35, 0.8 * eg)).stop(1, rgba(255, 110, 0, 0))
		c.fs(g2); c.circ(d * 2.4 * s, -19.4 * s, 3.4 * s)
		c.fs("#fff6c0"); c.ell(d * 2.4 * s, -19.4 * s, 1.4 * s, 1.0 * s)
		c.fs("#2a0a00"); c.ell(d * 2.4 * s, -19.4 * s, 0.4 * s, 1.0 * s)
	c.restore()


static func _dragon_wing(c: Cv, s: float) -> void:
	var wg := Cv.linear(3 * s, -8 * s, 26 * s, 4 * s).stop(0, "#6b0d12").stop(1, "#25050a")
	c.fs(wg)
	c.bp(); c.mt(3 * s, -7 * s)
	c.qt(15 * s, -24 * s, 26 * s, -16 * s)
	c.qt(23 * s, -8 * s, 28 * s, -1 * s)
	c.qt(20 * s, -3 * s, 18 * s, 4 * s)
	c.qt(12 * s, -0.5 * s, 10 * s, 8 * s)
	c.qt(7 * s, 2 * s, 3 * s, 4 * s); c.cp(); c.fill()
	c.ss("#8c1c18"); c.lw(1.1 * s)
	for p in [Vector2(26 * s, -16 * s), Vector2(28 * s, -1 * s), Vector2(18 * s, 4 * s), Vector2(10 * s, 8 * s)]:
		c.line(3 * s, -7 * s, p.x, p.y)


static func _dragon_body_a(c: Cv, s: float) -> void:
	# farok
	c.fs("#7d1113")
	c.bp(); c.mt(-4 * s, 9 * s); c.qt(-20 * s, 17 * s, -27 * s, 9 * s)
	c.qt(-17 * s, 22 * s, -2 * s, 15 * s); c.cp(); c.fill()
	# test
	var bgd := Cv.linear(-9 * s, -4 * s, 9 * s, 16 * s).stop(0, "#d42a22").stop(0.55, "#a4131a").stop(1, "#5c070e")
	c.fs(bgd); c.ell(0, 6 * s, 9.4 * s, 11.4 * s)
	# has
	c.fs("#e2ac48"); c.ell(0, 8 * s, 5 * s, 8 * s)
	c.ss(rgba(120, 70, 10, 0.5)); c.lw(0.9 * s)
	for i in 5:
		c.bp(); c.mt(-4.4 * s, 2 * s + i * 3.1 * s); c.qt(0, 4 * s + i * 3.1 * s, 4.4 * s, 2 * s + i * 3.1 * s); c.stroke()
	# pikkelyek
	c.ss(rgba(60, 4, 8, 0.4)); c.lw(0.8 * s)
	for r in 4:
		for cc in range(-2, 3):
			c.bp(); c.arc(cc * 3.4 * s - (1.7 * s if r % 2 == 1 else 0.0), 1 * s + r * 3.3 * s, 1.6 * s, PI * 1.05, PI * 1.95); c.stroke()
	# karok
	c.fs("#8f1216")
	for d in [-1.0, 1.0]:
		c.save(); c.scale(d, 1)
		c.ell(9 * s, 11 * s, 3.1 * s, 5.6 * s, -0.35)
		c.ss("#efe3c2"); c.lw(0.9 * s)
		for i in range(-1, 2):
			c.line(9.5 * s + i * 1.4 * s, 15 * s, 10.6 * s + i * 2 * s, 18.4 * s)
		c.restore()
	# nyak
	c.fs("#bf1e1e")
	c.bp(); c.mt(-6.4 * s, 1 * s); c.qt(-5.4 * s, -10 * s, -4.8 * s, -14 * s)
	c.lt(4.8 * s, -14 * s); c.qt(5.4 * s, -10 * s, 6.4 * s, 1 * s); c.cp(); c.fill()
	c.fs("#e2ac48")
	for i in 4:
		c.ell(0, -3 * s - i * 3 * s, 2.6 * s, 1.1 * s)
	# hát-tüskék
	c.fs("#4e0a10")
	for i in 5:
		var sy := -15 * s + i * 4 * s
		c.poly([-4.6 * s - i * 0.5 * s, sy, -8.4 * s - i * 0.9 * s, sy - 2.4 * s, -4.6 * s - i * 0.5 * s, sy + 2.4 * s])
		c.poly([4.6 * s + i * 0.5 * s, sy, 8.4 * s + i * 0.9 * s, sy - 2.4 * s, 4.6 * s + i * 0.5 * s, sy + 2.4 * s])
	# fej
	var hg := Cv.linear(0, -24 * s, 0, -12 * s).stop(0, "#e03028").stop(1, "#8f1216")
	c.fs(hg); c.ell(0, -18.5 * s, 6.4 * s, 5.6 * s)
	c.ell(0, -13.6 * s, 4.3 * s, 3.6 * s)
	# szemöldök
	c.fs("#6d0c11")
	c.poly([-6.2 * s, -21.4 * s, -1.2 * s, -19.8 * s, -6.2 * s, -18.6 * s])
	c.poly([6.2 * s, -21.4 * s, 1.2 * s, -19.8 * s, 6.2 * s, -18.6 * s])
	# nyitott száj (az izzás élőben kerül rá)
	c.fs("#280405"); c.ell(0, -11.6 * s, 3.5 * s, 2.1 * s)


static func _dragon_body_b(c: Cv, s: float) -> void:
	# fogak
	c.fs("#f3ead0")
	for i in range(-2, 3):
		c.poly([i * 1.4 * s - 0.5 * s, -13 * s, i * 1.4 * s + 0.5 * s, -13 * s, i * 1.4 * s, -11.4 * s])
	# szarvak
	c.ss("#eadfb8"); c.lw(1.8 * s)
	for d in [-1.0, 1.0]:
		c.bp(); c.mt(d * 4 * s, -22.4 * s); c.qt(d * 9.5 * s, -26.5 * s, d * 8 * s, -32 * s); c.stroke()
		c.bp(); c.mt(d * 5.6 * s, -20 * s); c.qt(d * 10.5 * s, -20.5 * s, d * 12 * s, -24.5 * s); c.stroke()

static func fire(c: Cv, cx: float, cy: float, s: float, t: float) -> void:
	c.save(); c.translate(cx, cy)
	var p := 0.5 + 0.5 * sin(t * 0.05)
	var L := 22 * s * (0.85 + 0.22 * p)
	var g := Cv.linear(0, 0, 0, L).stop(0, rgba(255, 242, 180, 0.94)).stop(0.22, rgba(255, 162, 28, 0.82)).stop(0.62, rgba(220, 60, 8, 0.4)).stop(1, rgba(130, 18, 0, 0))
	c.fs(g)
	c.bp(); c.mt(-1.4 * s, 0)
	c.qt(-8 * s, L * 0.5, -6.5 * s, L)
	c.qt(0, L * 1.05, 6.5 * s, L)
	c.qt(8 * s, L * 0.5, 1.4 * s, 0); c.cp(); c.fill()
	for i in 18:
		var q := fmod(t * 0.012 + Data.rnd_seed_m(i * 3.3), 1.0)
		var y := q * L
		var sp := (Data.rnd_seed_m(i * 7.7) - 0.5) * q * 10 * s
		var r := (2.2 - q * 1.4) * s * (0.5 + Data.rnd_seed_m(i * 5.1))
		c.fs(rgba(255, int(215 - q * 130), int(55 - q * 45), 0.7 * (1 - q)))
		c.circ(sp, y, maxf(0.5, r))
	c.restore()


static func crossed_swords(c: Cv, cx: float, cy: float, sz: float, colr: String) -> void:
	c.save(); c.translate(cx, cy)
	for d in [-1.0, 1.0]:
		c.save(); c.rotate(d * 0.62)
		c.fs(colr)
		c.poly([0, -sz * 0.52, sz * 0.055, -sz * 0.38, sz * 0.055, sz * 0.10, -sz * 0.055, sz * 0.10, -sz * 0.055, -sz * 0.38])
		c.fill_rect(-sz * 0.20, sz * 0.10, sz * 0.40, sz * 0.065)
		c.fill_rect(-sz * 0.045, sz * 0.165, sz * 0.09, sz * 0.20)
		c.circ(0, sz * 0.38, sz * 0.065)
		c.restore()
	c.restore()


static func ornament(c: Cv, x: float, y: float, w: float, colr: String, k: float) -> void:
	c.ss(colr); c.lw(1.4 * k)
	c.line(x, y, x + w, y)
	c.fs(colr)
	c.circ(x, y, 2.8 * k)
	c.circ(x + w, y, 2.8 * k)


## Ritkított betűközű szöveg; visszaadja a teljes szélességet
static func ls_width(s: String, sz: float, sp: float) -> float:
	var tot := 0.0
	for ch in s:
		tot += Cv.measure(ch, sz) + sp
	return tot - sp


static func ls_text(c: Cv, s: String, x: float, y: float, colr: Variant, sz: float, sp: float, al: String) -> void:
	var tot := ls_width(s, sz, sp)
	var sx := x - tot / 2 if al == "center" else x
	for ch in s:
		c.ftxt(ch, sx, y, colr, sz)
		sx += Cv.measure(ch, sz) + sp


static func flourish(c: Cv, x: float, y: float, w: float, colr: String, k: float, flip: bool) -> void:
	c.save(); c.translate(x, y)
	if flip:
		c.scale(-1, 1)
	c.ss(colr); c.lw(1.6 * k)
	c.bp(); c.mt(0, 0); c.qt(w * 0.5, -w * 0.13, w, 0); c.stroke()
	c.bp(); c.mt(w * 0.18, 0); c.qt(w * 0.36, w * 0.15, w * 0.56, 0.02); c.stroke()
	c.fs(colr); c.circ(0, 0, 3 * k)
	c.poly([w, -4 * k, w + 8 * k, 0, w, 4 * k])
	c.restore()
