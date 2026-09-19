class_name Render
extends RefCounted
## A pálya kirajzolása rétegenként: csempék + lágy fény, fáklyafény (additív), tárgyak/szörnyek/hős,
## lövedékek és villanások, a hős körüli sötétítés, és az alsó sáv (HUD).

const T := float(Data.TILE)


static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Cv.rgba(r, g, b, a)


## mennyire látszik egy mező (0..1): a tárgyak és szörnyek is fokozatosan tűnnek fel és el
static func seen_a(w: World, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= Data.MAP_W or y >= Data.MAP_H:
		return 0.0
	return clampf((w.fade[x * Data.MAP_H + y] - 0.36) / 0.64, 0.0, 1.0)


# ══════════ 1. CSEMPÉK, DÍSZEK ══════════
static func world_base(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var cam: Vector2 = m.cam
	c.fs("#080604"); c.fill_rect(0, 0, W, gh)
	var cam_w := int(ceilf(W / T)) + 2
	var cam_h := int(ceilf(gh / T)) + 2
	var cx0 := int(floorf(cam.x))
	var cy0 := int(floorf(cam.y))
	var fade := w.fade
	var fk := minf(1.0, m.dt / 110.0)
	# kötegelt rajzolás: kitöltések, vonalak, lépcsők, sötétítés
	var qp := PackedVector2Array()
	var qc := PackedColorArray()
	var qi := PackedInt32Array()
	var op := PackedVector2Array()
	var oc := PackedColorArray()
	var oi := PackedInt32Array()
	var wall_lines := PackedVector2Array()
	var floor_lines := PackedVector2Array()
	var stairs: Array = []
	var c_wall := Color("#2e2218")
	var c_floor := Color("#1c1610")
	var c_stair := Color("#2a2050")
	for sx in range(-1, cam_w + 1):
		for sy in range(-1, cam_h + 1):
			var tx := cx0 + sx
			var ty := cy0 + sy
			if tx < 0 or tx >= Data.MAP_W or ty < 0 or ty >= Data.MAP_H:
				continue
			var fi := tx * Data.MAP_H + ty
			var is_vis := w.vis[fi] == 1
			var is_exp := w.explored[fi] == 1
			var target := 1.0 if is_vis else (0.36 if is_exp else 0.0)
			fade[fi] += (target - fade[fi]) * fk
			var lt := fade[fi]
			if not is_exp and lt < 0.01:
				continue
			var tt := w.tiles[fi]
			var px := (tx - cam.x) * T
			var py := (ty - cam.y) * T
			var col := c_wall if tt == Data.WALL else (c_floor if tt == Data.FLOOR else c_stair)
			_quad(qp, qc, qi, px, py, T + 1, T + 1, col)
			if tt == Data.WALL:
				wall_lines.append_array([Vector2(px, py + T * 0.45), Vector2(px + T, py + T * 0.45),
					Vector2(px + T * 0.5, py), Vector2(px + T * 0.5, py + T * 0.45),
					Vector2(px + T * 0.25, py + T * 0.45), Vector2(px + T * 0.25, py + T),
					Vector2(px + T * 0.75, py + T * 0.45), Vector2(px + T * 0.75, py + T)])
			elif tt == Data.FLOOR:
				var a := Vector2(px + 0.5, py + 0.5)
				var b := Vector2(px + T - 0.5, py + T - 0.5)
				floor_lines.append_array([a, Vector2(b.x, a.y), Vector2(b.x, a.y), b, b, Vector2(a.x, b.y), Vector2(a.x, b.y), a])
			else:
				stairs.append(Vector2(px, py))
			# sötétítés a fényerő szerint (puha átmenet a látható és a bejárt rész között)
			if lt < 0.999:
				_quad(op, oc, oi, px, py, T + 1, T + 1, rgba(8, 6, 4, (1.0 - lt) * 0.92))
	w.fade = fade
	c.flush()
	var ci := c.ci
	if qp.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(ci, qi, qp, qc)
	if wall_lines.size() > 0:
		RenderingServer.canvas_item_add_multiline(ci, wall_lines, PackedColorArray([Color(0.235, 0.18, 0.11, 0.7)]), -1.0)
	if floor_lines.size() > 0:
		RenderingServer.canvas_item_add_multiline(ci, floor_lines, PackedColorArray([Color(0.157, 0.125, 0.10, 0.6)]), -1.0)
	for s in stairs:
		c.ss("#8070d0"); c.lw(1.5)
		c.bp(); c.arc(s.x + T / 2, s.y + T / 2, T / 3.2, 0, PI * 1.5); c.stroke()
		c.ftxt("▼", s.x + T / 2, s.y + T / 2 + 6, "#c0b0ff", T * 0.5, "center", true)
	if op.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(ci, oi, op, oc)
	# díszek (amfora, pókháló, repedés, csontok...)
	for d in w.decor:
		var dx: int = d["x"]
		var dy: int = d["y"]
		if not w.is_exp(dx, dy):
			continue
		var sx := (dx - cam.x) * T
		var sy := (dy - cam.y) * T
		if sx < -T or sx > W or sy < -T or sy > gh:
			continue
		c.ga(maxf(0.3, w.fade[dx * Data.MAP_H + dy]))
		Sprites.decor(c, d["type"], sx, sy, T, d["seed"])
		c.ga(1.0)


static func _quad(p: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, x: float, y: float, w: float, h: float, col: Color) -> void:
	var b := p.size()
	p.append(Vector2(x, y)); p.append(Vector2(x + w, y)); p.append(Vector2(x + w, y + h)); p.append(Vector2(x, y + h))
	cols.append(col); cols.append(col); cols.append(col); cols.append(col)
	idx.append(b); idx.append(b + 1); idx.append(b + 2); idx.append(b); idx.append(b + 2); idx.append(b + 3)


# ══════════ 2. FÁKLYAFÉNY (additív réteg) ══════════
static func world_glow(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var cam: Vector2 = m.cam
	var tick: float = m.tick
	var tex: Texture2D = m.tex_torch
	for tor in w.torches:
		var a := seen_a(w, tor["x"], tor["y"])
		if a <= 0.01:
			continue
		var sx: float = (tor["x"] - cam.x) * T
		var sy: float = (tor["y"] - cam.y) * T
		if sx < -T * 4 or sx > W + T * 4 or sy < -T * 4 or sy > gh + T * 4:
			continue
		var fl: float = 0.8 + 0.12 * sin(tick * 0.05 + tor["ph"]) + 0.08 * sin(tick * 0.13 + tor["ph"] * 2)
		var R := T * 3.4
		c.tex(tex, Rect2(sx + T / 2 - R, sy + T / 2 - R, R * 2, R * 2), Color(1, 1, 1, clampf(fl * a, 0.0, 1.0)))


# ══════════ 3. LÁNGOK, LÁDÁK, SZÖRNYEK, HŐS ══════════
static func world_mid(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var p: Player = m.game.player
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var cam: Vector2 = m.cam
	var tick: float = m.tick
	var glow: Texture2D = m.tex_glow
	# fáklyák lángja (lassan, nem kockánként lobog)
	for tor in w.torches:
		var a := seen_a(w, tor["x"], tor["y"])
		if a <= 0.01:
			continue
		var sx: float = (tor["x"] - cam.x) * T
		var sy: float = (tor["y"] - cam.y) * T
		if sx < -T * 2 or sx > W + T or sy < -T * 2 or sy > gh + T:
			continue
		var fl: float = 0.6 + 0.4 * sin(tick * 0.07 + tor["ph"])
		c.ga(a)
		c.ss("#5a3a10"); c.lw(2.5)
		c.line(sx + T / 2, sy + T * 0.7, sx + T / 2, sy + T * 0.4)
		c.fs(rgba(255, int(170 + 50 * fl), 40, 0.85 + 0.15 * fl))
		c.ell(sx + T / 2, sy + T * 0.32, 3, 5 + 2 * fl)
		c.ga(1.0)
	# ládák
	for ch in w.chests:
		if ch["opened"]:
			continue
		var ca := seen_a(w, ch["x"], ch["y"])
		if ca <= 0.01:
			continue
		var sx: float = (ch["x"] - cam.x) * T
		var sy: float = (ch["y"] - cam.y) * T
		if sx < -T or sx > W or sy < -T or sy > gh:
			continue
		c.ga(ca)
		var gp := 0.15 + 0.15 * sin(tick * 0.08)
		c.tex(glow, Rect2(sx + T * 0.5 - T * 0.75, sy + T * 0.5 - T * 0.75, T * 1.5, T * 1.5), rgba(220, 160, 0, gp))
		c.fs("#4a2c10"); c.rrect(sx + T * 0.15, sy + T * 0.35, T * 0.7, T * 0.45, 3); c.fill()
		c.fs("#5a3818"); c.rrect(sx + T * 0.12, sy + T * 0.22, T * 0.76, T * 0.2, 3); c.fill()
		c.ss(Data.P["parchGold"]); c.lw(1.5)
		c.rrect(sx + T * 0.12, sy + T * 0.22, T * 0.76, T * 0.58, 3); c.stroke()
		c.fs(Data.P["parchGold"]); c.circ(sx + T / 2, sy + T * 0.48, T * 0.08)
		c.ga(1.0)
	# szörnyek (rajzolt figurák)
	for mo in w.mons:
		if not mo.alive:
			continue
		# a szörny a saját mezője fényével tűnik fel és el (nem villan)
		var ma := 0.0
		if w.is_vis(mo.x, mo.y):
			ma = maxf(0.15, seen_a(w, Data.jround(mo.rx), Data.jround(mo.ry)))
		else:
			ma = seen_a(w, mo.x, mo.y) * 0.6
		if ma <= 0.02:
			continue
		var sx := (mo.rx - cam.x) * T
		var sy := (mo.ry - cam.y) * T
		if sx < -T * 2 or sx > W + T or sy < -T * 2 or sy > gh + T:
			continue
		c.ga(ma)
		if mo.boss:
			var pl := 0.2 + 0.2 * sin(tick * 0.05)
			c.tex(glow, Rect2(sx + T * 0.5 - T * 1.25, sy + T * 0.5 - T * 1.25, T * 2.5, T * 2.5), rgba(255, 200, 40, pl))
		c.save()
		if mo.facing < 0:
			c.translate((sx + T / 2) * 2, 0)
			c.scale(-1, 1)
		Sprites.monster(c, mo.key, sx + T / 2, sy + T / 2, T * 0.85, tick, mo.seedv)
		c.restore()
		# életerő-csík
		var bw := T - 6
		var hw := maxf(1.0, floorf(bw * mo.hp / mo.max_hp))
		c.fs("#3a0808"); c.fill_rect(sx + 3, sy - 3, bw, 3.5)
		c.fs(Data.P["legendary"] if mo.boss else "#c83028"); c.fill_rect(sx + 3, sy - 3, hw, 3.5)
		c.ga(1.0)
	# a hős (siklás + előrelendülés támadáskor)
	var lox := p.lunge * p.lunge_dx * T * 0.3
	var loy := p.lunge * p.lunge_dy * T * 0.3
	var px2 := (p.rx - cam.x) * T + lox
	var py2 := (p.ry - cam.y) * T + loy
	var pc: Color = Cv.col(p.col)
	pc.a = 0x40 / 255.0
	c.tex(glow, Rect2(px2 + T * 0.5 - T * 0.9, py2 + T * 0.5 - T * 0.9, T * 1.8, T * 1.8), pc)
	c.save()
	if p.facing < 0:
		c.translate((px2 + T / 2) * 2, 0)
		c.scale(-1, 1)
	Sprites.hero_cached(c, p.cls, px2 + T / 2, py2 + T / 2, T * 0.72, tick)
	c.restore()
	if p.poison > 0:
		c.ga(0.2 + 0.12 * sin(tick * 0.15))
		c.fs("#60c020"); c.fill_rect(px2, py2, T, T)
		c.ga(1.0)


# ══════════ 4. VARÁZSGÖMB ÉS BECSAPÓDÁS (additív réteg) ══════════
static func fx_add(m: Node, c: Cv) -> void:
	var cam: Vector2 = m.cam
	var now: float = m.now_ms()
	var orb: Texture2D = m.tex_orb
	var burst: Texture2D = m.tex_burst
	for f in m.game.fx:
		var dl: float = f.get("delay", 0.0)
		if now - f["t0"] < dl:
			continue
		var p: float = clampf((now - f["t0"] - dl) / f["dur"], 0.0, 1.0)
		if f["type"] == "orb":
			# kék varázsgömb: izzó mag, fényudvar és szikrázó csóva
			var x: float = (f["x0"] + (f["x1"] - f["x0"]) * p - cam.x) * T + T / 2
			var y: float = (f["y0"] + (f["y1"] - f["y0"]) * p - cam.y) * T + T / 2
			var ddx: float = f["x1"] - f["x0"]
			var ddy: float = f["y1"] - f["y0"]
			var ln := maxf(0.0001, Vector2(ddx, ddy).length())
			for i in range(1, 6):
				var tx := x - ddx / ln * i * T * 0.16
				var ty := y - ddy / ln * i * T * 0.16
				c.fs(rgba(80, 150, 255, 0.28 - i * 0.045))
				c.circ(tx, ty, T * (0.16 - i * 0.018))
			var r := T * 0.55
			c.tex(orb, Rect2(x - r, y - r, r * 2, r * 2))
		elif f["type"] == "mburst":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var r := T * (0.25 + p * 0.8)
			c.tex(burst, Rect2(x - r, y - r, r * 2, r * 2), Color(1, 1, 1, 1.0 - p))
			c.ss(rgba(140, 190, 255, 0.8 * (1 - p))); c.lw(2)
			for i in 6:
				var a := i / 6.0 * PI * 2 + p
				c.line(x + cos(a) * r * 0.4, y + sin(a) * r * 0.4, x + cos(a) * r, y + sin(a) * r)


# ══════════ 5. NYÍL, ÁGYÚGOLYÓ, VÁGÁS, ROBBANÁS, SEBZÉSSZÁM + a hős körüli sötétítés ══════════
static func fx(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var pl: Player = m.game.player
	var cam: Vector2 = m.cam
	var now: float = m.now_ms()
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	for f in m.game.fx:
		var dl: float = f.get("delay", 0.0)
		if now - f["t0"] < dl:
			continue
		var p: float = clampf((now - f["t0"] - dl) / f["dur"], 0.0, 1.0)
		var ty: String = f["type"]
		if ty == "arrow" or ty == "ball":
			var x: float = (f["x0"] + (f["x1"] - f["x0"]) * p - cam.x) * T + T / 2
			var y: float = (f["y0"] + (f["y1"] - f["y0"]) * p - cam.y) * T + T / 2
			if ty == "arrow":
				var ang := atan2(f["y1"] - f["y0"], f["x1"] - f["x0"])
				c.save(); c.translate(x, y); c.rotate(ang)
				c.ss("#d4a84b"); c.lw(2)
				c.line(-8, 0, 6, 0)
				c.fs("#e8e0c8")
				c.poly([8, 0, 3, -3, 3, 3])
				c.restore()
			else:
				c.fs("#282828"); c.circ(x, y, 5)
				c.fs(rgba(255, 140, 20, 0.8 * (1 - p)))
				c.circ(x - (f["x1"] - f["x0"]) * 3, y - (f["y1"] - f["y0"]) * 3, 3.5)
		elif ty == "slash":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			c.save(); c.translate(x, y); c.rotate(-0.6 + p * 1.4)
			c.ss(rgba(240, 240, 255, 0.9 * (1 - p))); c.lw(3)
			c.bp(); c.arc(0, 0, T * 0.55, -0.5, 0.7); c.stroke()
			c.restore()
		elif ty == "boom":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var r := T * (0.3 + p * 0.9)
			c.ss(rgba(255, int(160 - p * 100), 20, 0.9 * (1 - p)))
			c.lw(4 * (1 - p) + 1)
			c.bp(); c.arc(x, y, r, 0, 7); c.stroke()
		elif ty == "dmgnum":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] + f.get("dy", 0.0) - cam.y) * T - p * 22
			c.ftxt(f["txt"], x, y, f.get("col", "#ff6050"), 13 * (1 - p * 0.3), "center", true)
	# a játékos körüli fény: vele együtt, simán mozog (a látóhatár felé fokozatosan sötétedik)
	var lcx := (pl.rx - cam.x) * T + T / 2
	var lcy := (pl.ry - cam.y) * T + T / 2
	var R := T * (Data.FOV_R + 2)
	c.tex(m.tex_dark, Rect2(lcx - R, lcy - R, R * 2, R * 2))
	c.fs(rgba(4, 3, 2, 0.35))
	if lcy - R > 0: c.fill_rect(0, 0, W, lcy - R)
	if lcy + R < gh: c.fill_rect(0, lcy + R, W, gh - (lcy + R))
	if lcx - R > 0: c.fill_rect(0, maxf(0, lcy - R), lcx - R, minf(gh, lcy + R) - maxf(0, lcy - R))
	if lcx + R < W: c.fill_rect(lcx + R, maxf(0, lcy - R), W - (lcx + R), minf(gh, lcy + R) - maxf(0, lcy - R))
	if w == null:
		return


# ══════════ HUD ══════════
static func hud(m: Node, c: Cv) -> void:
	var p: Player = m.game.player
	var w: World = m.game.world
	var W: float = m.W
	var H: float = m.H
	var y0 := H - Data.HUD_H
	var P := Data.P
	c.fs(P["hudBg"]); c.fill_rect(0, y0, W, Data.HUD_H)
	c.ss(P["hudBorder"]); c.lw(1.5); c.line(0, y0, W, y0)
	var hp_pct := clampf(float(p.hp) / p.max_hp, 0.0, 1.0)
	var xp_pct := clampf(float(p.xp) / p.xp_next, 0.0, 1.0)
	var hp_col := "#b03020" if hp_pct > 0.5 else ("#d05010" if hp_pct > 0.25 else "#f03010")
	c.bar(10, y0 + 10, 170, 12, hp_pct, hp_col, "#2a0808")
	c.ftxt("Életerő %d/%d" % [p.hp, p.max_hp], 12, y0 + 20, "#ffffff", 9)
	c.bar(10, y0 + 28, 170, 8, xp_pct, "#404090", "#141428")
	c.ftxt("XP %d/%d" % [p.xp, p.xp_next], 12, y0 + 35, "#c0c0e0", 8, "left", true)
	c.ftxt("♥".repeat(maxi(0, p.lives)) + "♡".repeat(maxi(0, 3 - p.lives)), 10, y0 + 58, P["vein"], 15)
	# állapotok: méreg, regeneráció, életlopás
	var st: Array[String] = []
	if p.poison > 0: st.append("☠ Méreg %d" % p.poison)
	if p.regen > 0: st.append("✚ +%d/kör" % p.regen)
	if p.lifesteal > 0: st.append("♥ Lopás %d%%" % int(roundf(p.lifesteal * 100)))
	if not st.is_empty():
		c.ftxt_fit("  ".join(st), 10, y0 + 80, "#80c870", 9, 190)
	var c2 := 210.0
	c.ftxt("%s  ·  Lv.%d" % [p.cls, p.plvl], c2, y0 + 22, P["parchGold"], 12)
	if p.cls == "Mágus":
		c.ftxt("✦ %d    🛡 %d" % [p.mag, p.def], c2, y0 + 42, P["ink"], 11)
	else:
		c.ftxt("⚔ %d    🛡 %d" % [p.atk, p.def], c2, y0 + 42, P["ink"], 11)
	c.ftxt_fit("Mélység %d/%d · %s · Kör %d" % [w.dungeon_level, Data.MAX_LEVEL, Data.DIFF[w.diff]["label"], w.turn], c2, y0 + 62, P["inkDark"], 10, 250)
	if m.game.on_stair():
		var sl := "▼ Lépcső: %s" % m.key_label(m.binds["stair"])
		c.ftxt(sl, c2, y0 + 82, "#c0b0ff", 10)
	var c3 := 470.0
	var mx := maxf(c3 + 230, W * 0.62)
	var colw := mx - c3 - 12
	c.ftxt_fit("⚔ " + (p.weapon.label if p.weapon else "Puszta kéz"), c3, y0 + 18, p.weapon.border() if p.weapon else P["inkDark"], 10, colw)
	c.ftxt_fit("🛡 " + (p.armor.label if p.armor else "Nincs páncél"), c3, y0 + 35, p.armor.border() if p.armor else P["inkDark"], 10, colw)
	c.ftxt_fit("⛨ " + (p.shield.label if p.shield else "Nincs pajzs"), c3, y0 + 52, p.shield.border() if p.shield else P["inkDark"], 10, colw)
	c.ftxt_fit("WASD · I:Táska · %s:Lépcső · M:Hang" % m.key_label(m.binds["stair"]), c3, y0 + 72, P["inkDark"], 9, colw)
	var mw := W - mx - 8
	if mw > 100:
		var msgs: Array = p.msgs.slice(maxi(0, p.msgs.size() - 4))
		for i in msgs.size():
			var a := 0.4 + 0.6 * (float(i) / maxf(1.0, msgs.size() - 1))
			c.ga(a)
			c.ftxt_fit(msgs[i]["t"], mx, y0 + 16 + i * 19, msgs[i]["c"], 10, mw)
			c.ga(1.0)
