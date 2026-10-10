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
## A csempék színe és mintája a zónától függ (Story.ZONES): rozsdás kazánlemez, márvány
## sakktábla, eres hús, aranyfugás acél.
static func world_base(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var cam: Vector2 = m.cam
	var z := Story.zone(w.dungeon_level)
	c.fs("#060504"); c.fill_rect(0, 0, W, gh)
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
	var vein_lines := PackedVector2Array()
	var stairs: Array = []
	var c_wall := Color(str(z["wall"]))
	var c_floor := Color(str(z["floor"]))
	var c_acc := Color(str(z["acc"]))
	var pat := str(z["pat"])
	var moving := false
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
			var dv := (target - fade[fi]) * fk
			if absf(dv) > 0.0006:
				moving = true
			fade[fi] += dv
			var lt := fade[fi]
			if not is_exp and lt < 0.01:
				continue
			var tt := w.tiles[fi]
			var px := (tx - cam.x) * T
			var py := (ty - cam.y) * T
			# a még meg nem talált titkos ajtó pontosan úgy néz ki, mint a fal
			var is_wall := tt == Data.WALL or tt == Data.SECRET
			# csempénkénti, determinisztikus árnyalat-változat (nem zaj: egy mező mindig ugyanazt
			# kapja, így a kép nem "sercegik", de a falfelület nem lesz egyhangú)
			var hsh := ((tx * 73856093) ^ (ty * 19349663)) & 7
			var vv := 0.90 + float(hsh) * 0.032
			if not is_wall and pat == "checker":
				vv *= 1.16 if ((tx + ty) & 1) == 0 else 0.86
			var col := c_wall if is_wall else c_floor
			col = Color(col.r * vv, col.g * vv, col.b * vv)
			_quad(qp, qc, qi, px, py, T + 1, T + 1, col)
			if is_wall:
				# felső kőél (fény) és alsó árnyék: a fal így kiemelkedik a padlóból
				_quad(qp, qc, qi, px, py, T + 1, T * 0.10, Color(col.r * 1.5, col.g * 1.46, col.b * 1.4))
				_quad(qp, qc, qi, px, py + T * 0.88, T + 1, T * 0.12 + 1, Color(col.r * 0.5, col.g * 0.5, col.b * 0.54))
				# futókötéses téglakötés: a függőleges hézagok soronként váltakoznak
				if (ty & 1) == 1:
					wall_lines.append_array([Vector2(px, py + T * 0.45), Vector2(px + T, py + T * 0.45),
						Vector2(px + T * 0.3, py), Vector2(px + T * 0.3, py + T * 0.45),
						Vector2(px + T * 0.7, py), Vector2(px + T * 0.7, py + T * 0.45),
						Vector2(px + T * 0.5, py + T * 0.45), Vector2(px + T * 0.5, py + T * 0.88)])
				else:
					wall_lines.append_array([Vector2(px, py + T * 0.45), Vector2(px + T, py + T * 0.45),
						Vector2(px + T * 0.5, py), Vector2(px + T * 0.5, py + T * 0.45),
						Vector2(px + T * 0.25, py + T * 0.45), Vector2(px + T * 0.25, py + T * 0.88),
						Vector2(px + T * 0.75, py + T * 0.45), Vector2(px + T * 0.75, py + T * 0.88)])
			else:
				var a := Vector2(px + 0.5, py + 0.5)
				var b := Vector2(px + T - 0.5, py + T - 0.5)
				floor_lines.append_array([a, Vector2(b.x, a.y), Vector2(b.x, a.y), b, b, Vector2(a.x, b.y), Vector2(a.x, b.y), a])
				if pat == "vein" and hsh < 3:
					# a Tüdő-Kert padlóját erek hálózzák be
					vein_lines.append_array([Vector2(px + T * 0.1, py + T * (0.2 + hsh * 0.2)), Vector2(px + T * 0.5, py + T * 0.5),
						Vector2(px + T * 0.5, py + T * 0.5), Vector2(px + T * 0.9, py + T * (0.8 - hsh * 0.2))])
				elif pat == "plate" and hsh == 0:
					# kazánlemez: szegecsek a sarkokban
					for q in [Vector2(0.14, 0.14), Vector2(0.86, 0.14), Vector2(0.14, 0.86), Vector2(0.86, 0.86)]:
						_quad(qp, qc, qi, px + T * q.x - 1.5, py + T * q.y - 1.5, 3, 3, Color(col.r * 1.7, col.g * 1.6, col.b * 1.4))
				if tt == Data.STAIR:
					stairs.append(Vector2(px, py))
			# sötétítés a fényerő szerint (puha átmenet a látható és a bejárt rész között)
			if lt < 0.999:
				_quad(op, oc, oi, px, py, T + 1, T + 1, rgba(6, 5, 4, (1.0 - lt) * 0.92))
	w.fade = fade
	m.world_fading = moving
	c.flush()
	var ci := c.ci
	var c_line := Color(str(z["line"]))
	var c_fline := Color(str(z["fline"]))
	if qp.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(ci, qi, qp, qc)
	if wall_lines.size() > 0:
		RenderingServer.canvas_item_add_multiline(ci, wall_lines, PackedColorArray([Color(c_line.r, c_line.g, c_line.b, 0.55)]), -1.0)
	if floor_lines.size() > 0:
		RenderingServer.canvas_item_add_multiline(ci, floor_lines, PackedColorArray([Color(c_fline.r, c_fline.g, c_fline.b, 0.7)]), -1.0)
	if vein_lines.size() > 0:
		RenderingServer.canvas_item_add_multiline(ci, vein_lines, PackedColorArray([Color(0.62, 0.16, 0.24, 0.55)]), 1.5)
	# lejárat: amíg a zóna ura él, zárva van (szürke); utána a zóna színében izzik
	var open := w.boss() == null
	for s in stairs:
		var sc: Color = c_acc if open else Color(0.45, 0.42, 0.40)
		c.fs(Color(0.04, 0.03, 0.03, 0.9)); c.rrect(s.x + T * 0.10, s.y + T * 0.10, T * 0.80, T * 0.80, T * 0.10); c.fill()
		for i in 4:
			c.fs(Color(sc.r, sc.g, sc.b, 0.85 - i * 0.18))
			c.fill_rect(s.x + T * (0.16 + i * 0.07), s.y + T * (0.18 + i * 0.17), T * (0.68 - i * 0.14), T * 0.10)
		c.ss(sc); c.lw(2.0)
		c.rrect(s.x + T * 0.10, s.y + T * 0.10, T * 0.80, T * 0.80, T * 0.10); c.stroke()
	if op.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(ci, oi, op, oc)
	# díszek (amfora, pókháló, repedés, csontok...)
	for d in w.decor:
		var dx: int = d["x"]
		var dy: int = d["y"]
		if not w.is_exp(dx, dy) or d["type"] in Sprites2.ELO_DISZEK:
			continue   # a mozgó díszek a szörnyekkel együtt, minden képkockán rajzolódnak (world_mid)
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


# ══════════ 2. LÁMPAFÉNY (additív réteg) ══════════
static func world_glow(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var p: Player = m.game.player
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var cam: Vector2 = m.cam
	var tick: float = m.tick
	var tex: Texture2D = m.tex_glow
	var lamp := Color(str(Story.zone(w.dungeon_level)["lamp"]))
	for tor in w.torches:
		var a := seen_a(w, tor["x"], tor["y"])
		if a <= 0.01:
			continue
		var sx: float = (tor["x"] - cam.x) * T
		var sy: float = (tor["y"] - cam.y) * T
		if sx < -T * 4 or sx > W + T * 4 or sy < -T * 4 or sy > gh + T * 4:
			continue
		var fl: float = 0.8 + 0.12 * sin(tick * 0.05 + tor["ph"]) + 0.08 * sin(tick * 0.13 + tor["ph"] * 2)
		var R := T * 3.6
		c.tex(tex, Rect2(sx + T / 2 - R, sy + T / 2 - R, R * 2, R * 2), Color(lamp.r, lamp.g * 0.8, lamp.b * 0.6, clampf(fl * a * 0.30, 0.0, 1.0)))
	# a hős saját fénye: meleg kör, amely vele együtt mozog
	var hx := (p.rx - cam.x) * T + T / 2
	var hy := (p.ry - cam.y) * T + T / 2
	var HR := T * 4.2
	c.tex(tex, Rect2(hx - HR, hy - HR, HR * 2, HR * 2), Color(1.0, 0.82, 0.58, 0.16))
	# előre jelzett csapások izzása
	var now: float = m.now_ms()
	for h in w.hazards:
		var ha := seen_a(w, h["x"], h["y"])
		if ha <= 0.01:
			continue
		var x: float = (h["x"] - cam.x) * T
		var y: float = (h["y"] - cam.y) * T
		var hc := Color(str(Data.HAZ_COL.get(h["kind"], "#ffffff")))
		var pu := 0.5 + 0.5 * sin(now * 0.018)
		c.tex(tex, Rect2(x - T * 0.3, y - T * 0.3, T * 1.6, T * 1.6), Color(hc.r, hc.g, hc.b, (0.35 + 0.3 * pu) * ha * (1.0 if h["warn"] else 0.45)))


## egy mező képernyő-helye; false, ha nem látszik
static func _on_screen(sx: float, sy: float, W: float, gh: float, pad := 1.0) -> bool:
	return not (sx < -T * pad or sx > W + T * (pad - 1.0) or sy < -T * pad or sy > gh + T * (pad - 1.0))


## a nyomólapok jelei a helyes sorrendben (ezt mutatja a leláncolt láda fölötti jelsor)
static func _lap_sorrend(w: World) -> Array:
	var out: Array = []
	out.resize(w.lapok.size())
	out.fill(0)
	for l in w.lapok:
		var k := int(l["sor"])
		if k >= 0 and k < out.size():
			out[k] = int(l["jel"])
	return out


## a szikék és a korongok kirajzolt (sikló / forduló) állása: kulcs -> érték
static var _gep_anim := {}


## A zóna saját pályaelemei és a rejtvényszoba nyomólapjai. Minden elem a saját mezője fényével
## tűnik fel; a gépek állása a körszámból adódik (World.gep_fazis / szike_hely).
static func _gepek(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var cam: Vector2 = m.cam
	var tick: float = m.tick
	var k: float = minf(1.0, float(m.dt) / 90.0)
	for l in w.lapok:
		var la := seen_a(w, l["x"], l["y"])
		if la <= 0.01:
			continue
		var lx: float = (l["x"] - cam.x) * T
		var ly: float = (l["y"] - cam.y) * T
		if not _on_screen(lx, ly, W, gh):
			continue
		c.ga(la)
		Sprites2.nyomolap(c, lx, ly, T, int(l["jel"]), bool(l["le"]), tick)
		c.ga(1.0)
	for g in w.gepek:
		var gx: int = g["x"]
		var gy: int = g["y"]
		var dx: int = g["dx"]
		var dy: int = g["dy"]
		var n: int = g["n"]
		if not _on_screen((gx - cam.x) * T, (gy - cam.y) * T, W, gh, 9.0):
			continue
		match str(g["tip"]):
			"zsilip":
				var per: int = g["p"]
				var fz := w.gep_fazis(g)
				var fuj := fz >= per - 2
				var u := 1.0 if fuj else clampf(float(fz) / float(maxi(1, per - 3)), 0.0, 1.0)
				for i in n:
					var tx := gx + dx * i
					var ty := gy + dy * i
					var a := seen_a(w, tx, ty)
					if a <= 0.01:
						continue
					c.ga(a)
					Sprites2.zsilip(c, (tx - cam.x) * T, (ty - cam.y) * T, T, u, fuj, dx != 0, i == int(n / 2), tick)
					c.ga(1.0)
			"szike":
				for i in n:
					var tx := gx + dx * i
					var ty := gy + dy * i
					var a := seen_a(w, tx, ty)
					if a <= 0.01:
						continue
					c.ga(a)
					Sprites2.szike_sin(c, (tx - cam.x) * T, (ty - cam.y) * T, T, dx != 0, i == 0, i == n - 1)
					c.ga(1.0)
				# a penge lágyan siklik a mostani mezőjére
				var cel := w.szike_hely(g, w.turn)
				var kulcs := "s%d,%d,%d" % [gx, gy, int(g["ph"])]
				var most: Vector2 = _gep_anim.get(kulcs, Vector2(cel))
				if most.distance_to(Vector2(cel)) > 2.5:
					most = Vector2(cel)
				most += (Vector2(cel) - most) * k
				_gep_anim[kulcs] = most
				var pa := seen_a(w, cel.x, cel.y)
				if pa > 0.01:
					c.ga(pa)
					Sprites2.szike(c, (most.x - cam.x) * T, (most.y - cam.y) * T, T, tick)
					c.ga(1.0)
			"gubo":
				var a := seen_a(w, gx, gy)
				if a > 0.01:
					c.ga(a)
					Sprites2.gubo(c, (gx - cam.x) * T, (gy - cam.y) * T, T, int(g["all"]), tick)
					c.ga(1.0)
			"korong":
				var a := seen_a(w, gx, gy)
				if a <= 0.01:
					continue
				var per2: int = maxi(1, int(g["p"]))
				# ahányszor eddig fordult, annyi negyedfordulat; a rajz lágyan utoléri
				var cel_szog := floorf(float(w.turn + int(g["ph"]) + 1) / float(per2)) * PI * 0.5
				var kulcs2 := "k%d,%d" % [gx, gy]
				var szog: float = _gep_anim.get(kulcs2, cel_szog)
				if absf(cel_szog - szog) > PI:
					szog = cel_szog
				szog += (cel_szog - szog) * minf(1.0, float(m.dt) / 160.0)
				_gep_anim[kulcs2] = szog
				var izzas := (0.6 + 0.4 * sin(tick * 0.3)) if w.gep_fazis(g) == per2 - 2 else 0.0
				c.ga(a)
				Sprites2.korong(c, (gx + 0.5 - cam.x) * T, (gy + 0.5 - cam.y) * T, T, szog, izzas)
				c.ga(1.0)


# ══════════ 3. LÁNGOK, LÁDÁK, VESZÉLYZÓNÁK, SZÖRNYEK, HŐS ══════════
static func world_mid(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var p: Player = m.game.player
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var cam: Vector2 = m.cam
	var tick: float = m.tick
	var now: float = m.now_ms()
	var glow: Texture2D = m.tex_glow
	var z := Story.zone(w.dungeon_level)
	var lamp := Color(str(z["lamp"]))
	# fali lámpák lángja (lassan, nem kockánként lobog)
	for tor in w.torches:
		var a := seen_a(w, tor["x"], tor["y"])
		if a <= 0.01:
			continue
		var sx: float = (tor["x"] - cam.x) * T
		var sy: float = (tor["y"] - cam.y) * T
		if not _on_screen(sx, sy, W, gh, 2.0):
			continue
		var fl: float = 0.6 + 0.4 * sin(tick * 0.07 + tor["ph"])
		c.ga(a)
		# lámpatartó: vaskonzol + nyél (kész hálóból)
		c.blit("torch_h|%d" % int(T), func() -> void:
			c.fs("#2a2018"); c.rrect(T * 0.42, T * 0.36, T * 0.16, T * 0.36, T * 0.05); c.fill()
			c.fs("#4a3a24"); c.fill_rect(T * 0.46, T * 0.36, T * 0.06, T * 0.36)
			c.fs("#3a2e1e")
			c.poly([T * 0.30, T * 0.30, T * 0.70, T * 0.30, T * 0.62, T * 0.40, T * 0.38, T * 0.40])
			c.fs("#5a4830")
			c.poly([T * 0.30, T * 0.30, T * 0.70, T * 0.30, T * 0.68, T * 0.33, T * 0.32, T * 0.33]), sx, sy)
		# láng: három tónus a zóna lámpaszínében
		var fx0 := sx + T / 2
		var fy0 := sy + T * 0.30
		c.fs(Color(lamp.r * 0.75, lamp.g * 0.32, lamp.b * 0.12, 0.55 + 0.2 * fl))
		c.ell(fx0, fy0 - T * 0.03, 5.2, (8.4 + 3.6 * fl))
		c.fs(Color(lamp.r, lamp.g * (0.62 + 0.2 * fl), lamp.b * 0.3, 0.9))
		c.ell(fx0, fy0 - T * 0.04, 3.6, (6.0 + 2.6 * fl))
		c.fs(Color(1.0, 0.95, 0.78, 0.85))
		c.ell(fx0, fy0 - T * 0.06, 1.7, (2.6 + 1.2 * fl))
		c.ga(1.0)
	# élő pálya: gőzszelepek, fogaskerekek, csöpögő csövek, lüktető erek a falakon
	for d in w.decor:
		if not (d["type"] in Sprites2.ELO_DISZEK):
			continue
		var da := seen_a(w, d["x"], d["y"])
		if da <= 0.01:
			continue
		var dsx: float = (d["x"] - cam.x) * T
		var dsy: float = (d["y"] - cam.y) * T
		if not _on_screen(dsx, dsy, W, gh, 2.0):
			continue
		c.ga(da)
		Sprites2.prop(c, d["type"], dsx, dsy, T, tick, d["seed"])
		c.ga(1.0)
	# padlórácsok: a kitörés előtti körben felizzanak
	var vkind := Color(str(Data.HAZ_COL.get(Data.VENT_KIND.get(w.dungeon_level, "steam"), "#ffffff")))
	for v in w.vents:
		var va := seen_a(w, v["x"], v["y"])
		if va <= 0.01:
			continue
		var vsx: float = (v["x"] - cam.x) * T
		var vsy: float = (v["y"] - cam.y) * T
		if not _on_screen(vsx, vsy, W, gh):
			continue
		var fazis := (w.turn + int(v["ph"])) % Data.VENT_PERIOD
		c.ga(va)
		Sprites2.vent(c, vsx, vsy, T, vkind, 0.5 + 0.5 * sin(tick * 0.2) if fazis == Data.VENT_PERIOD - 3 else 0.0)
		c.ga(1.0)
	# a zóna saját pályaelemei (gőzzsilip, szike-sín, spóragubó, forgó korong) és a nyomólapok
	_gepek(m, c)
	# ereklye-talapzatok és döntési események
	for pd in w.pedestals:
		if pd["taken"]:
			continue
		var pda := seen_a(w, pd["x"], pd["y"])
		if pda > 0.01:
			c.ga(pda)
			Sprites2.pedestal(c, (pd["x"] - cam.x) * T, (pd["y"] - cam.y) * T, T, tick)
			c.ga(1.0)
	for ev in w.events:
		if ev["used"]:
			continue
		var eva := seen_a(w, ev["x"], ev["y"])
		if eva > 0.01:
			c.ga(eva)
			Sprites2.event_mark(c, (ev["x"] - cam.x) * T, (ev["y"] - cam.y) * T, T, tick)
			c.ga(1.0)
	# veszélyzónák: a robbanni készülő mező villogó kerete, illetve a savtócsa
	for h in w.hazards:
		var ha := seen_a(w, h["x"], h["y"])
		if ha <= 0.01:
			continue
		var x: float = (h["x"] - cam.x) * T
		var y: float = (h["y"] - cam.y) * T
		if not _on_screen(x, y, W, gh):
			continue
		var hc := Color(str(Data.HAZ_COL.get(h["kind"], "#ffffff")))
		if h["warn"]:
			var pu := 0.5 + 0.5 * sin(now * 0.02)
			c.fs(Color(1.0, 0.25, 0.15, (0.20 + 0.20 * pu) * ha)); c.fill_rect(x + 2, y + 2, T - 4, T - 4)
			c.ss(Color(1.0, 0.35 + 0.4 * pu, 0.2, 0.95 * ha)); c.lw(2.5)
			c.stroke_rect(x + 3, y + 3, T - 6, T - 6)
			c.ss(Color(hc.r, hc.g, hc.b, 0.9 * ha)); c.lw(2.0)
			var e := T * (0.18 + 0.06 * pu)
			c.line(x + T / 2 - e, y + T / 2 - e, x + T / 2 + e, y + T / 2 + e)
			c.line(x + T / 2 + e, y + T / 2 - e, x + T / 2 - e, y + T / 2 + e)
		elif h["kind"] == "spora":
			# spórafelhő: gomolygó pára (az utolsó körében halványul)
			c.ga(ha)
			Sprites2.sporafelho(c, x, y, T, tick, minf(1.0, float(h["ttl"]) / 2.0))
			c.ga(1.0)
		else:
			var bub := 0.5 + 0.5 * sin(tick * 0.1 + h["x"] * 1.7 + h["y"])
			c.ga(ha * minf(1.0, float(h["ttl"]) / 2.0))
			c.fs(Color(hc.r * 0.45, hc.g * 0.55, hc.b * 0.2, 0.75)); c.ell(x + T / 2, y + T * 0.56, T * 0.42, T * 0.30)
			c.fs(Color(hc.r, hc.g, hc.b, 0.8)); c.ell(x + T * 0.46, y + T * 0.52, T * 0.30, T * 0.19)
			c.fs(Color(1, 1, 0.8, 0.7)); c.circ(x + T * (0.36 + 0.3 * bub), y + T * (0.52 - 0.08 * bub), 2.0 + bub * 1.6)
			c.ga(1.0)
	# megtalált csapdák és titkos ajtók, szentélyek, kereskedő (mind kész hálóból)
	for tr in w.traps:
		if not tr["found"]:
			continue
		var ta := seen_a(w, tr["x"], tr["y"])
		if ta <= 0.01:
			continue
		var tsx: float = (tr["x"] - cam.x) * T
		var tsy: float = (tr["y"] - cam.y) * T
		if not _on_screen(tsx, tsy, W, gh):
			continue
		c.ga(ta)
		Sprites.trap(c, tr["type"], tsx, tsy, T, tr["sprung"])
		c.ga(1.0)
	for sd in w.secrets:
		if not sd["found"]:
			continue
		var sa := seen_a(w, sd["x"], sd["y"])
		if sa <= 0.01:
			continue
		var ssx: float = (sd["x"] - cam.x) * T
		var ssy: float = (sd["y"] - cam.y) * T
		if not _on_screen(ssx, ssy, W, gh):
			continue
		c.ga(sa)
		Sprites.secret_door(c, ssx, ssy, T)
		c.ga(1.0)
	for sh in w.shrines:
		var ha2 := seen_a(w, sh["x"], sh["y"])
		if ha2 <= 0.01:
			continue
		var hsx: float = (sh["x"] - cam.x) * T
		var hsy: float = (sh["y"] - cam.y) * T
		if not _on_screen(hsx, hsy, W, gh):
			continue
		c.ga(ha2)
		Sprites.shrine(c, hsx, hsy, T, sh["kind"], sh["used"], tick)
		c.ga(1.0)
	for sp in w.shops:
		var pa := seen_a(w, sp["x"], sp["y"])
		if pa <= 0.01:
			continue
		var psx: float = (sp["x"] - cam.x) * T
		var psy: float = (sp["y"] - cam.y) * T
		if not _on_screen(psx, psy, W, gh):
			continue
		c.ga(pa)
		Sprites.merchant(c, psx, psy, T, tick)
		c.ga(1.0)
	# feljegyzések (a Napló lapjai)
	for nt in w.notes:
		if nt["taken"]:
			continue
		var na := seen_a(w, nt["x"], nt["y"])
		if na <= 0.01:
			continue
		var nsx: float = (nt["x"] - cam.x) * T
		var nsy: float = (nt["y"] - cam.y) * T
		if not _on_screen(nsx, nsy, W, gh):
			continue
		c.ga(na)
		Sprites2.note(c, nsx, nsy, T, tick)
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
		if not _on_screen(sx, sy, W, gh):
			continue
		c.ga(ca)
		var gp := 0.18 + 0.16 * sin(tick * 0.08)
		c.tex(glow, Rect2(sx + T * 0.5 - T * 0.8, sy + T * 0.5 - T * 0.8, T * 1.6, T * 1.6), rgba(230, 170, 20, gp))
		c.fs("#3a2008"); c.rrect(sx + T * 0.13, sy + T * 0.34, T * 0.74, T * 0.48, 3); c.fill()
		c.fs("#6a3c16"); c.rrect(sx + T * 0.15, sy + T * 0.36, T * 0.70, T * 0.42, 3); c.fill()
		c.fs("#8a5222"); c.rrect(sx + T * 0.12, sy + T * 0.20, T * 0.76, T * 0.22, 4); c.fill()
		c.fs("#a8682c"); c.rrect(sx + T * 0.16, sy + T * 0.22, T * 0.68, T * 0.07, 2); c.fill()
		c.fs(Data.P["parchGold"])
		c.fill_rect(sx + T * 0.24, sy + T * 0.20, T * 0.07, T * 0.62); c.fill_rect(sx + T * 0.69, sy + T * 0.20, T * 0.07, T * 0.62)
		c.ss(Data.P["parchGold"]); c.lw(1.5)
		c.rrect(sx + T * 0.12, sy + T * 0.20, T * 0.76, T * 0.62, 3); c.stroke()
		c.fs("#ffe9a0"); c.circ(sx + T / 2, sy + T * 0.47, T * 0.075)
		c.fs("#3a2008"); c.circ(sx + T / 2, sy + T * 0.47, T * 0.03)
		if ch.get("zart", false):
			# a rejtvényszoba ládája: lánc és lakat, fölötte a megoldás jelei sorban
			Sprites2.lada_lanc(c, sx, sy, T)
			Sprites2.lada_jelek(c, sx, sy, T, _lap_sorrend(w), w.lapok_le(), tick)
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
		# támadáskor a szörny nekilendül a hősnek
		var ml := lendulet(mo.lunge)
		var sx := (mo.rx - cam.x) * T + ml * mo.lunge_dx * T * 0.38
		var sy := (mo.ry - cam.y) * T + ml * mo.lunge_dy * T * 0.38
		if not _on_screen(sx, sy, W, gh, 2.0):
			continue
		c.ga(ma)
		# főellenség: belépőkor és fázisváltáskor megnő, majd visszahúzódik
		var morph := 1.0
		var mt: float = now - mo.morph_ms
		if mo.morph_ms > 0.0 and mt >= 0.0 and mt < 900.0:
			morph = 1.0 + 0.45 * sin(mt / 900.0 * PI) * (1.0 - mt / 900.0 * 0.4)
		if mo.mini:
			c.tex(glow, Rect2(sx + T * 0.5 - T * 1.2, sy + T * 0.5 - T * 1.2, T * 2.4, T * 2.4), rgba(120, 200, 255, 0.28 + 0.14 * sin(tick * 0.07 + mo.seedv)))
		if mo.boss or mo.guard:
			var pl := (0.2 + 0.2 * sin(tick * 0.05)) * (1.0 if mo.boss else 0.6)
			var bc := Color(str(z["acc"])) if mo.boss else Color(1.0, 0.78, 0.16)
			if mo.boss and mo.phase == 2:
				bc = Color(1.0, 0.3, 0.2)
			c.tex(glow, Rect2(sx + T * 0.5 - T * 1.5, sy + T * 0.5 - T * 1.5, T * 3.0, T * 3.0), Color(bc.r, bc.g, bc.b, pl))
		elif mo.elite:
			c.tex(glow, Rect2(sx + T * 0.5 - T * 1.0, sy + T * 0.5 - T * 1.0, T * 2.0, T * 2.0), rgba(150, 255, 60, 0.26 + 0.14 * sin(tick * 0.09 + mo.seedv)))
		# találatkor a figura megrándul
		var since: float = now - mo.hit_ms
		var jolt := 0.0
		if since >= 0.0 and since < 140.0:
			jolt = (1.0 - since / 140.0) * 3.2 * sin(since / 140.0 * TAU * 2.0)
		c.save()
		_fordit(c, sx + T / 2, mo.rf)
		Figura.lep = mo.rx + mo.ry
		Figura.ido = tick + mo.seedv * 40.0
		# minden példány kicsit más: méret és árnyalat a szörny magjából (a főellenség és a mini-boss nem)
		var kulon := not (mo.boss or mo.mini)
		var vm: float = Data.VAR_MERET[int(mo.seedv * 7.0) % Data.VAR_MERET.size()] if kulon else 1.0
		var vt := (int(mo.seedv * 3.0) % Data.VAR_TONUS.size()) if kulon else 0
		Sprites.monster_cached(c, mo.key + ("#2" if mo.boss and mo.phase == 2 else ""), sx + T / 2 + jolt, sy + T / 2, T * 0.85 * morph * (1.25 if mo.mini else vm), tick, mo.seedv, vt)
		Figura.lep = 0.0
		c.restore()
		if mo.morph_ms > 0.0 and mt >= 0.0 and mt < 500.0:
			c.tex(glow, Rect2(sx - T * 0.6, sy - T * 0.6, T * 2.2, T * 2.2), Color(1, 1, 1, 0.8 * (1.0 - mt / 500.0)))
		if mo.burn > 0 or mo.corr > 0 or mo.bleed > 0:
			Sprites2.status_icons(c, sx + T * 0.2, sy - 12, mo.burn, mo.corr, mo.bleed, tick)
		if since >= 0.0 and since < 140.0:
			c.tex(glow, Rect2(sx - T * 0.1, sy - T * 0.1, T * 1.2, T * 1.2), Color(1, 1, 1, 0.75 * (1.0 - since / 140.0)))
		if mo.stun > 0:
			for i in 3:
				var sa2 := tick * 0.12 + i * 2.09
				c.ftxt("✦", sx + T / 2 + cos(sa2) * T * 0.3, sy + T * 0.08 + sin(sa2) * T * 0.08, "#ffe070", 11, "center")
		# életerő-csík (a főellenségé fent, külön sávon látszik)
		if not mo.boss and (mo.hp < mo.max_hp or mo.elite or mo.guard or mo.mini):
			var bw := T - 8
			var hw := maxf(1.0, bw * clampf((mo.hp_r if mo.hp_r >= 0.0 else float(mo.hp)) / mo.max_hp, 0.0, 1.0))
			c.fs("#140606"); c.fill_rect(sx + 3, sy - 5, bw + 2, 6)
			c.fs("#70c8ff" if mo.mini else ("#90e040" if mo.elite else (Data.P["legendary"] if mo.guard else "#e03c30"))); c.fill_rect(sx + 4, sy - 4, hw, 4)
			if mo.mini:
				c.ftxt_fit(mo.name, sx + T / 2, sy - 9, "#a0dcff", 10, T * 3.0, "center")
		c.ga(1.0)
	# a hős (siklás + előrelendülés támadáskor)
	var pl2 := lendulet(p.lunge)
	var lox := pl2 * p.lunge_dx * T * 0.34
	var loy := pl2 * p.lunge_dy * T * 0.34
	var px2 := (p.rx - cam.x) * T + lox
	var py2 := (p.ry - cam.y) * T + loy
	var pc: Color = Cv.col(p.col)
	pc.a = 0x40 / 255.0
	c.tex(glow, Rect2(px2 + T * 0.5 - T * 0.9, py2 + T * 0.5 - T * 0.9, T * 1.8, T * 1.8), pc)
	c.save()
	_fordit(c, px2 + T / 2, p.rf)
	Figura.lep = p.rx + p.ry
	Figura.ido = tick
	Sprites.hero_cached(c, p.cls, px2 + T / 2, py2 + T / 2, T * 0.72, tick, m.skins)
	Figura.lep = 0.0
	c.restore()
	var hs: float = now - p.hurt_ms
	if p.hurt_ms > 0.0 and hs < 180.0:
		c.tex(glow, Rect2(px2 - T * 0.2, py2 - T * 0.2, T * 1.4, T * 1.4), Color(1, 0.2, 0.15, 0.8 * (1.0 - hs / 180.0)))
	if p.poison > 0:
		c.tex(glow, Rect2(px2 - T * 0.1, py2 - T * 0.1, T * 1.2, T * 1.2), rgba(110, 220, 40, 0.3 + 0.15 * sin(tick * 0.15)))
	if p.rooted > 0:
		c.ss("#4a9a3a"); c.lw(2.5)
		for i in 4:
			var rx := px2 + T * (0.2 + i * 0.2)
			c.bp(); c.mt(rx, py2 + T); c.qt(rx + sin(tick * 0.1 + i) * 5, py2 + T * 0.75, rx + (1.5 - i) * 3, py2 + T * 0.55); c.stroke()
	if p.stun > 0:
		for i in 3:
			var sa3 := tick * 0.12 + i * 2.09
			c.ftxt("✦", px2 + T / 2 + cos(sa3) * T * 0.3, py2 + T * 0.05 + sin(sa3) * T * 0.08, "#c8f0e8", 12, "center")


# ══════════ 4. VARÁZSGÖMB, ROBBANÁSOK FÉNYE (additív réteg) ══════════
static func fx_add(m: Node, c: Cv) -> void:
	var cam: Vector2 = m.cam
	var now: float = m.now_ms()
	var orb: Texture2D = m.tex_orb
	var burst: Texture2D = m.tex_burst
	var glow: Texture2D = m.tex_glow
	for f in m.game.fx:
		var dl: float = f.get("delay", 0.0)
		if now - f["t0"] < dl:
			continue
		var p: float = clampf((now - f["t0"] - dl) / f["dur"], 0.0, 1.0)
		var ty: String = f["type"]
		if ty == "orb":
			# kék varázsgömb: izzó mag, fényudvar és szikrázó csóva
			var x: float = (f["x0"] + (f["x1"] - f["x0"]) * p - cam.x) * T + T / 2
			var y: float = (f["y0"] + (f["y1"] - f["y0"]) * p - cam.y) * T + T / 2
			var ddx: float = f["x1"] - f["x0"]
			var ddy: float = f["y1"] - f["y0"]
			var ln := maxf(0.0001, Vector2(ddx, ddy).length())
			for i in range(1, 6):
				var tx := x - ddx / ln * i * T * 0.16
				var tyy := y - ddy / ln * i * T * 0.16
				c.fs(rgba(80, 150, 255, 0.28 - i * 0.045))
				c.circ(tx, tyy, T * (0.16 - i * 0.018))
			var r := T * 0.55
			c.tex(orb, Rect2(x - r, y - r, r * 2, r * 2))
		elif ty == "mburst":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var r := T * (0.25 + p * 0.8)
			c.tex(burst, Rect2(x - r, y - r, r * 2, r * 2), Color(1, 1, 1, 1.0 - p))
			c.ss(rgba(140, 190, 255, 0.8 * (1 - p))); c.lw(2)
			for i in 6:
				var a := i / 6.0 * PI * 2 + p
				c.line(x + cos(a) * r * 0.4, y + sin(a) * r * 0.4, x + cos(a) * r, y + sin(a) * r)
		elif ty == "nova" or ty == "burst":
			# táguló fénygyűrű (képesség, fázisváltás) / egy mező kitörése
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var fc := Color(str(f.get("col", "#ffffff")))
			var R: float = T * float(f.get("r", 0.8)) * (0.25 + 0.75 * (1.0 - pow(1.0 - p, 3.0)))
			c.tex(glow, Rect2(x - R, y - R, R * 2, R * 2), Color(fc.r, fc.g, fc.b, 0.75 * (1.0 - p)))
		elif ty == "puff":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var fc := Color(str(f.get("col", "#ffffff")))
			var R: float = T * (0.9 if f.get("big", false) else 0.55) * (0.5 + p)
			c.tex(glow, Rect2(x - R, y - R, R * 2, R * 2), Color(fc.r, fc.g, fc.b, 0.5 * (1.0 - p)))
		elif ty == "trail":
			# félreugrás: a hős színében halványuló csóva
			var fc := Color(str(f.get("col", "#ffffff")))
			for i in 8:
				var u := i / 7.0
				var x: float = (f["x0"] + (f["x1"] - f["x0"]) * u - cam.x) * T + T / 2
				var y: float = (f["y0"] + (f["y1"] - f["y0"]) * u - cam.y) * T + T / 2
				var R: float = T * 0.5 * (0.5 + u * 0.5)
				c.tex(glow, Rect2(x - R, y - R, R * 2, R * 2), Color(fc.r, fc.g, fc.b, 0.55 * (1.0 - p) * (0.3 + u * 0.7)))


# ══════════ 5. NYÍL, ÁGYÚGOLYÓ, VÁGÁS, ROBBANÁS, SEBZÉSSZÁM + a hős körüli sötétítés ══════════
static func fx(m: Node, c: Cv) -> void:
	var pl: Player = m.game.player
	var cam: Vector2 = m.cam
	var now: float = m.now_ms()
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var nums: Array = []
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
				c.ss(rgba(255, 240, 200, 0.35)); c.lw(2); c.line(-26, 0, -9, 0)
				c.ss("#d4a84b"); c.lw(2.4)
				c.line(-10, 0, 8, 0)
				c.fs("#f4ecd4")
				c.poly([11, 0, 4, -4, 4, 4])
				c.restore()
			else:
				c.fs(rgba(255, 150, 30, 0.6 * (1 - p)))
				c.circ(x - (f["x1"] - f["x0"]) * 4, y - (f["y1"] - f["y0"]) * 4, 5)
				c.fs("#1c1c1c"); c.circ(x, y, 6)
				c.fs("#6a6a6a"); c.circ(x - 1.5, y - 1.5, 2)
		elif ty == "slash":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			c.save(); c.translate(x, y); c.rotate(-0.6 + p * 1.4)
			c.ss(rgba(255, 255, 255, 0.95 * (1 - p))); c.lw(4.5 * (1 - p) + 1)
			c.bp(); c.arc(0, 0, T * 0.55, -0.6, 0.8); c.stroke()
			c.ss(rgba(255, 220, 130, 0.6 * (1 - p))); c.lw(2)
			c.bp(); c.arc(0, 0, T * 0.66, -0.4, 0.6); c.stroke()
			c.restore()
		elif ty == "corpse":
			# a legyőzött szörny: összeroskad és elhalványul (a főellenség közben rázkódik)
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var boss: bool = f.get("boss", false)
			var kp := p if not boss else clampf((p - 0.75) / 0.25, 0.0, 1.0)
			if boss and p < 0.8:
				x += sin(now * 0.09) * 3.0
				y += cos(now * 0.11) * 2.0
			c.save(); c.translate(x, y + T * 0.38)
			c.scale(1.0 + 0.35 * kp, maxf(0.05, 1.0 - 0.85 * kp))
			if int(f.get("facing", 1)) < 0:
				c.scale(-1, 1)
			c.ga(1.0 - kp)
			Sprites.monster(c, str(f["key"]), 0, -T * 0.38, T * 0.85, 0.0, float(f.get("sd", 0.0)), false)
			c.ga(1.0)
			c.restore()
		elif ty == "bolt":
			# villámlánc: törtvonal két mező között
			var x0: float = (f["x0"] - cam.x) * T + T / 2
			var y0: float = (f["y0"] - cam.y) * T + T / 2
			var x1: float = (f["x1"] - cam.x) * T + T / 2
			var y1: float = (f["y1"] - cam.y) * T + T / 2
			for k in 2:
				c.ss(rgba(140, 210, 255, 0.95 * (1 - p)) if k == 0 else rgba(255, 255, 255, 0.95 * (1 - p))); c.lw(4.0 if k == 0 else 1.6)
				c.bp(); c.mt(x0, y0)
				for i in range(1, 6):
					var u := i / 6.0
					var jx := Data.rnd_seed(i * 3.1 + float(f["t0"]) * 0.01 + floorf(p * 6.0)) - 0.5
					c.lt(lerpf(x0, x1, u) + jx * T * 0.5, lerpf(y0, y1, u) + (Data.rnd_seed(i * 7.7 + floorf(p * 6.0)) - 0.5) * T * 0.5)
				c.lt(x1, y1); c.stroke()
		elif ty == "bite":
			# a szörny ütése: három vörös karmolás a hősön
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			c.ss(rgba(255, 70, 50, 0.9 * (1 - p))); c.lw(3 * (1 - p) + 1)
			for i in 3:
				var o := (i - 1) * T * 0.16
				c.line(x - T * 0.22 + o, y - T * 0.28, x + T * 0.02 + o, y + T * 0.28 * (0.3 + p))
		elif ty == "spin":
			# Forgószél: körbevágó penge
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var a0 := p * TAU * 1.2
			c.ss(rgba(255, 245, 200, 0.95 * (1 - p))); c.lw(5 * (1 - p) + 1.5)
			c.bp(); c.arc(x, y, T * 1.15, a0, a0 + 2.6); c.stroke()
			c.ss(rgba(255, 200, 90, 0.6 * (1 - p))); c.lw(3)
			c.bp(); c.arc(x, y, T * 1.35, a0 + 0.5, a0 + 2.3); c.stroke()
		elif ty == "nova":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var fc := Color(str(f.get("col", "#ffffff")))
			var R: float = T * float(f.get("r", 1.0)) * (1.0 - pow(1.0 - p, 3.0))
			c.ss(Color(fc.r, fc.g, fc.b, 0.9 * (1 - p))); c.lw(5 * (1 - p) + 1)
			c.bp(); c.arc(x, y, R, 0, 7); c.stroke()
		elif ty == "burst":
			# egy veszélyzóna kitörése: gőzoszlop, pengék vagy gyökerek
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var fc := Color(str(f.get("col", "#ffffff")))
			var kind := str(f.get("kind", "steam"))
			if kind == "root":
				c.ss(Color(0.25, 0.55, 0.2, 1.0 - p)); c.lw(3.5)
				for i in 4:
					var rx := x + (i - 1.5) * T * 0.2
					c.bp(); c.mt(rx, y + T * 0.45); c.qt(rx + (i - 1.5) * 6, y, rx + (1.5 - i) * 4, y - T * 0.5 * minf(1.0, p * 3.0)); c.stroke()
			elif kind == "blade":
				c.ss(Color(1, 1, 1, 1.0 - p)); c.lw(2.5)
				for i in 3:
					var a := -0.9 + i * 0.5
					c.line(x + cos(a) * T * 0.5, y + sin(a) * T * 0.5 - T * 0.2, x - cos(a) * T * 0.5, y - sin(a) * T * 0.5 + T * 0.2)
			else:
				for i in 4:
					c.fs(Color(fc.r, fc.g, fc.b, 0.5 * (1.0 - p)))
					c.circ(x + sin(i * 2.4 + p * 3.0) * T * 0.2, y + T * 0.3 - p * T * (0.5 + i * 0.2), T * (0.14 + p * 0.22))
		elif ty == "puff":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var fc := Color(str(f.get("col", "#ffffff")))
			var n := 12 if f.get("big", false) else 7
			var sp: float = T * (1.5 if f.get("big", false) else 0.8)
			for i in n:
				var a := i * 2.399 + float(f["t0"]) * 0.001
				var d := sp * (0.25 + 0.75 * Data.rnd_seed(i * 3.7 + float(f["x"]))) * (1.0 - pow(1.0 - p, 2.0))
				c.fs(Color(fc.r, fc.g, fc.b, 0.95 * (1.0 - p)))
				c.circ(x + cos(a) * d, y + sin(a) * d + p * p * T * 0.3, (3.6 - p * 2.6) * (1.3 if i % 3 == 0 else 1.0))
		elif ty == "drain":
			# vérátömlesztés / foltozás: lüktető pontsor két mező között
			var fc := Color(str(f.get("col", "#e03030")))
			for i in 7:
				var u := fmod(i / 7.0 + p, 1.0)
				var x: float = (f["x0"] + (f["x1"] - f["x0"]) * u - cam.x) * T + T / 2
				var y: float = (f["y0"] + (f["y1"] - f["y0"]) * u - cam.y) * T + T / 2 - sin(u * PI) * T * 0.3
				c.fs(Color(fc.r, fc.g, fc.b, 0.9 * (1.0 - p))); c.circ(x, y, 3.2)
		elif ty == "boom":
			var x: float = (f["x"] - cam.x) * T + T / 2
			var y: float = (f["y"] - cam.y) * T + T / 2
			var r := T * (0.3 + p * 0.9)
			c.fs(rgba(255, 200, 60, 0.35 * (1 - p))); c.circ(x, y, r * 0.8)
			c.ss(rgba(255, int(160 - p * 100), 20, 0.9 * (1 - p)))
			c.lw(5 * (1 - p) + 1)
			c.bp(); c.arc(x, y, r, 0, 7); c.stroke()
		elif ty == "dmgnum":
			nums.append([f, p])
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
	# sebzésszámok a sötétítés FÖLÖTT: kiugranak, aztán felfelé úszva elhalványulnak
	for e in nums:
		var f: Dictionary = e[0]
		var p: float = e[1]
		var big: bool = f.get("big", false)
		var x: float = (f["x"] - cam.x) * T + T / 2
		var y: float = (f["y"] + f.get("dy", 0.0) - cam.y) * T - p * 30 + 6
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - p * 6.0)
		var sz := (25.0 if big else 17.0) * pop
		c.ga(minf(1.0, (1.0 - p) * 2.2))
		c.ftxt(f["txt"], x + 1.5, y + 2, "#000000", sz, "center", true)
		c.ftxt(f["txt"], x, y, f.get("col", "#ff6050"), sz, "center", true)
		c.ga(1.0)
	overlay(m, c)


# ══════════ 6. A KÉPERNYŐRE VETÍTETT RÉTEG: részecskék, főellenség-sáv, feliratok ══════════
static var _ROMAN := ["", "I", "II", "III", "IV", "V"]


static func overlay(m: Node, c: Cv) -> void:
	var w: World = m.game.world
	var p: Player = m.game.player
	var W: float = m.W
	var gh: float = m.H - Data.HUD_H
	var tick: float = m.tick
	var now: float = m.now_ms()
	var z := Story.zone(w.dungeon_level)
	# a rázkódás csak a pályát mozgatja: ez a réteg a helyén marad
	c.save(); c.translate(-m.shake_off.x, -m.shake_off.y)
	# a zóna levegője: gőz, porszemek, spórák, parázs
	var fog := Color(str(z["fog"]))
	var part := str(z["part"])
	for i in (34 if bool(m.kep["reszecske"]) else 0):
		var s1 := Data.rnd_seed(i * 1.31 + 0.7)
		var s2 := Data.rnd_seed(i * 2.77 + 3.1)
		var x := 0.0
		var y := 0.0
		var r := 2.0
		var a := 0.3
		match part:
			"steam":
				var u := fmod(s2 + tick * (0.0016 + s1 * 0.0012), 1.0)
				x = s1 * W + sin(u * 6.0 + i) * 30
				y = gh * (1.05 - u * 1.1)
				r = 10 + u * 34 + s2 * 10
				a = 0.055 * sin(u * PI)
			"mote":
				x = fmod(s1 * W + tick * (0.10 + s2 * 0.12), W)
				y = s2 * gh + sin(tick * 0.012 + i) * 22
				r = 1.4 + s1 * 1.6
				a = 0.22 + 0.18 * sin(tick * 0.03 + i)
			"spore":
				var u2 := fmod(s2 + tick * (0.0010 + s1 * 0.0010), 1.0)
				x = s1 * W + sin(u2 * 9.0 + i * 2.0) * 44
				y = gh * (1.05 - u2 * 1.1)
				r = 1.8 + s2 * 2.4
				a = 0.5 * sin(u2 * PI)
			_:
				var u3 := fmod(s2 + tick * (0.0030 + s1 * 0.0030), 1.0)
				x = s1 * W + sin(u3 * 5.0 + i) * 18
				y = gh * (1.05 - u3 * 1.1)
				r = 1.2 + s1 * 2.0
				a = 0.75 * sin(u3 * PI)
		if a > 0.01:
			if part == "steam":
				# a gőz puha pamacs (fény-textúrából), nem éles szélű korong
				c.tex(m.tex_glow, Rect2(x - r * 2.4, y - r * 2.4, r * 4.8, r * 4.8), Color(fog.r, fog.g, fog.b, a * 1.6))
			else:
				c.fs(Color(fog.r, fog.g, fog.b, a)); c.circ(x, y, r)
	# teljes képernyős villanás (fázisváltás, főellenség halála)
	var fl: Dictionary = m.game.flash
	if not fl.is_empty():
		var ft: float = now - float(fl.get("t0", 0.0))
		var fd := float(fl.get("dur", 400.0))
		if ft >= 0.0 and ft < fd:
			var fc := Color(str(fl.get("col", "#ffffff")))
			c.fs(Color(fc.r, fc.g, fc.b, 0.55 * (1.0 - ft / fd))); c.fill_rect(0, 0, W, gh)
	# sérülés: vörös villanás; kevés életerő: lüktető vörös keret
	var hs: float = now - p.hurt_ms
	if p.hurt_ms > 0.0 and hs < 220.0:
		c.fs(rgba(200, 20, 10, 0.20 * (1.0 - hs / 220.0))); c.fill_rect(0, 0, W, gh)
	var hp_pct := float(p.hp) / maxf(1.0, p.max_hp)
	if p.alive and hp_pct < 0.3:
		var pu := 0.5 + 0.5 * sin(tick * 0.14)
		for i in 7:
			c.ss(rgba(220, 20, 10, (0.20 + 0.14 * pu) * (1.0 - i / 7.0))); c.lw(9)
			c.stroke_rect(i * 8 + 4, i * 8 + 4, W - i * 16 - 8, gh - i * 16 - 8)
	# a zóna urának életcsíkja (amint a hős találkozott vele)
	var b := w.boss()
	if b != null and b.met:
		var bw := minf(560.0, W * 0.5)
		var bx := (W - bw) / 2
		var by := 34.0
		var bc := "#ff5040" if b.phase == 2 else str(z["acc"])
		c.fs(rgba(8, 6, 4, 0.78)); c.rrect(bx - 14, by - 26, bw + 28, 54, 8); c.fill()
		c.ss(bc); c.lw(1.5); c.rrect(bx - 14, by - 26, bw + 28, 54, 8); c.stroke()
		c.ftxt_fit(b.name, W / 2, by - 6, bc, 16, bw - 80, "center")
		c.ftxt(Lang.T("boss.phase", b.phase), bx + bw, by - 7, Data.P["inkDark"], 11, "right")
		var pct := clampf(float(b.hp) / b.max_hp, 0.0, 1.0)
		c.fs("#1a0606"); c.rrect(bx, by + 2, bw, 16, 4); c.fill()
		if pct > 0.0:
			c.fs(bc); c.rrect(bx, by + 2, maxf(6.0, bw * pct), 16, 4); c.fill()
			c.fs(rgba(255, 255, 255, 0.22)); c.fill_rect(bx + 3, by + 4, maxf(1.0, bw * pct - 6), 4)
		# a fázishatár jele a csík közepén
		c.fs(rgba(255, 255, 255, 0.75)); c.fill_rect(bx + bw / 2 - 1, by, 2, 20)
		c.ftxt("%d / %d" % [maxi(0, b.hp), b.max_hp], W / 2, by + 15, "#ffffff", 11, "center", true)
	# nagy felirat: új zóna, főellenség neve, fázisváltás
	var bn: Dictionary = m.game.banner
	if not bn.is_empty():
		var bt: float = now - float(bn.get("t0", 0.0))
		var DUR := 3400.0
		if bt >= 0.0 and bt < DUR:
			var ba := minf(1.0, bt / 350.0) * minf(1.0, (DUR - bt) / 700.0)
			var cy := gh * 0.30
			var col := str(bn.get("col", "#ffd060"))
			c.ga(ba)
			var g := Cv.linear(0, cy - 70, 0, cy + 70)
			g.stop(0.0, rgba(0, 0, 0, 0.0)).stop(0.5, rgba(0, 0, 0, 0.72)).stop(1.0, rgba(0, 0, 0, 0.0))
			c.fs(g); c.fill_rect(0, cy - 70, W, 140)
			var n := int(bn.get("n", 0))
			if n > 0:
				MenuArt.ls_text(c, Lang.T("banner.act", _ROMAN[clampi(n, 0, 5)]), W / 2, cy - 28, Data.P["ink"], 13, 4.0, "center")
			var slide := (1.0 - minf(1.0, bt / 450.0)) * 30.0
			MenuArt.ls_text(c, Lang.T(str(bn.get("k", ""))).to_upper(), W / 2 + slide, cy + 8, col, 34, 3.0, "center")
			var lw2 := minf(360.0, W * 0.4) * minf(1.0, bt / 600.0)
			c.ss(col); c.lw(1.5); c.line(W / 2 - lw2 / 2, cy + 22, W / 2 + lw2 / 2, cy + 22)
			c.ftxt_fit(Lang.T(str(bn.get("s", ""))), W / 2, cy + 44, Data.P["ink"], 14, W - 80, "center")
			c.ga(1.0)
	c.restore()


# ══════════ AUTOMATA TÉRKÉP (Tab) ══════════
## A bejárt mezők egy 80×60-as képpé (textúrává) gyűlnek, amely CSAK új felfedezéskor frissül
## (lásd main.gd::_sync_map). Így a kirajzolás egyetlen textúra + néhány apró négyzet, és a
## réteg is csak akkor rajzolódik újra, ha tényleg változott a felderített terület.
const MAP_SCALE := 2.2
const MAP_PAD := 6.0


static func map_rect(m: Node) -> Rect2:
	var w := Data.MAP_W * MAP_SCALE
	var h := Data.MAP_H * MAP_SCALE
	return Rect2(10, 10, w + MAP_PAD * 2, h + MAP_PAD * 2)


static func minimap(m: Node, c: Cv) -> void:
	if not m.map_on or m.map_tex == null:
		return
	var w: World = m.game.world
	var p: Player = m.game.player
	var r := map_rect(m)
	c.fs(rgba(10, 8, 5, 0.82))
	c.rrect(r.position.x, r.position.y, r.size.x, r.size.y, 6); c.fill()
	c.ss(Data.P["hudBorder"]); c.lw(1.5)
	c.rrect(r.position.x, r.position.y, r.size.x, r.size.y, 6); c.stroke()
	var ox := r.position.x + MAP_PAD
	var oy := r.position.y + MAP_PAD
	c.tex(m.map_tex, Rect2(ox, oy, Data.MAP_W * MAP_SCALE, Data.MAP_H * MAP_SCALE))
	# lépcső (ha már látta) és a hős
	for i in w.rooms.size():
		var kind: String = w.room_kind[i] if i < w.room_kind.size() else ""
		if kind == "":
			continue
		var ct := Dungeon.center(w.rooms[i])
		if not w.is_exp(ct.x, ct.y):
			continue
		c.fs(Data.ROOM_KINDS[kind]["col"])
		c.circ(ox + (ct.x + 0.5) * MAP_SCALE, oy + (ct.y + 0.5) * MAP_SCALE, 2.2)
	var st := Dungeon.center(w.rooms[w.rooms.size() - 1])
	if w.is_exp(st.x, st.y):
		c.fs("#b0a0ff")
		c.circ(ox + (st.x + 0.5) * MAP_SCALE, oy + (st.y + 0.5) * MAP_SCALE, 2.6)
	c.fs(p.col)
	c.circ(ox + (p.x + 0.5) * MAP_SCALE, oy + (p.y + 0.5) * MAP_SCALE, 2.8)
	c.ftxt(Lang.T("map.hint", w.dungeon_level), r.position.x + r.size.x / 2, r.position.y + r.size.y + 12, Data.P["inkDark"], 9, "center")


# ══════════ HUD ══════════
## Alsó sáv: arckép + életerő, a három gyorsgomb (félreugrás, képesség, ital) lehűléssel,
## értékek és nyersanyagok, jobbra az üzenetnapló.
static func potions(p: Player) -> int:
	var n := 0
	for it in p.inventory:
		if it.subtype == "heal":
			n += 1
	return n


static func _slot(c: Cv, x: float, y: float, sz: float, key: String, icon: String, col: String, cd: int, cd_max: int, label: String, dim := false) -> void:
	var ready := cd <= 0 and not dim
	c.rrect_fill_c(x, y, sz, sz, 8, "#1a130a" if ready else "#0e0b08")
	c.ftxt(icon, x + sz / 2, y + sz * 0.62, col if ready else "#5a5046", sz * 0.46, "center")
	if cd > 0:
		var pct := clampf(float(cd) / maxf(1.0, cd_max), 0.0, 1.0)
		c.fs(Cv.rgba(0, 0, 0, 0.62)); c.rrect(x, y + sz * (1.0 - pct), sz, sz * pct, 6); c.fill()
		c.ftxt(str(cd), x + sz / 2, y + sz * 0.66, "#ffffff", sz * 0.42, "center", true)
	c.rrect_stroke_c(x, y, sz, sz, 8, 2.0 if ready else 1.2, col if ready else "#3a3026")
	# billentyű-címke a bal felső sarokban
	var kw := maxf(18.0, Cv.measure(key, 9, true) + 8)
	c.rrect_fill_c(x - 4, y - 6, kw, 15, 4, "#2e2210")
	c.rrect_stroke_c(x - 4, y - 6, kw, 15, 4, 1.0, Data.P["parchEdge"])
	c.ftxt(key, x - 4 + kw / 2, y + 5, Data.P["parchGold"], 9, "center", true)
	c.ftxt_fit(label, x + sz / 2, y + sz + 13, Data.P["ink"] if ready else Data.P["inkDark"], 9, sz + 22, "center")


static func hud(m: Node, c: Cv) -> void:
	var p: Player = m.game.player
	var w: World = m.game.world
	var W: float = m.W
	var H: float = m.H
	var y0 := H - Data.HUD_H
	var P := Data.P
	var z := Story.zone(w.dungeon_level)
	var g := Cv.linear(0, y0, 0, H)
	g.stop(0.0, "#1c140a").stop(1.0, "#0c0804")
	c.fs(g); c.fill_rect(0, y0, W, Data.HUD_H)
	c.fs(str(z["acc"])); c.fill_rect(0, y0, W, 2)
	c.fs(Cv.rgba(0, 0, 0, 0.5)); c.fill_rect(0, y0 + 2, W, 2)
	# ── arckép ──
	var pr := 36.0
	var pcx := 14 + pr
	var pcy := y0 + Data.HUD_H / 2.0 - 2
	c.fs("#0a0806"); c.circ(pcx, pcy, pr)
	c.fs(Color(Cv.col(p.col), 0.16)); c.circ(pcx, pcy, pr - 2)
	Sprites.hero_cached(c, p.cls, pcx, pcy + 3, pr * 1.25, 0.0, m.skins)
	c.ss(p.col); c.lw(2.5); c.bp(); c.arc(pcx, pcy, pr, 0, 7); c.stroke()
	c.rrect_fill_c(pcx - 22, pcy + pr - 10, 44, 17, 8, "#2e2210")
	c.rrect_stroke_c(pcx - 22, pcy + pr - 10, 44, 17, 8, 1.2, P["parchGold"])
	c.ftxt(Lang.T("hud.lv", p.plvl), pcx, pcy + pr + 3, P["parchGold"], 11, "center")
	# ── életerő, tapasztalat, életek ──
	var bx := pcx + pr + 14
	var bw := 232.0
	var hp_pct := clampf(float(p.hp) / p.max_hp, 0.0, 1.0)
	var xp_pct := clampf(float(p.xp) / p.xp_next, 0.0, 1.0)
	var hp_col := "#d83828" if hp_pct > 0.5 else ("#e87018" if hp_pct > 0.25 else "#ff3010")
	c.ftxt_fit(Lang.cls(p.cls), bx, y0 + 22, P["parchGold"], 14, 130)
	c.ftxt("♥".repeat(clampi(p.lives, 0, 6)), bx + bw, y0 + 22, "#e04050", 15, "right")
	c.rrect_fill_c(bx - 2, y0 + 29, bw + 4, 24, 6, "#000000")
	c.bar(bx, y0 + 31, bw, 20, hp_pct, hp_col, "#2a0808", 5)
	if hp_pct > 0.0:
		c.fs(Cv.rgba(255, 255, 255, 0.16)); c.fill_rect(bx + 3, y0 + 33, maxf(1.0, bw * hp_pct - 6), 5)
	c.ftxt(Lang.T("hud.hp", p.hp, p.max_hp), bx + bw / 2, y0 + 46, "#ffffff", 13, "center")
	c.bar(bx, y0 + 57, bw, 9, xp_pct, "#6a70e0", "#141428", 4)
	c.ftxt_fit(Lang.T("hud.xp", p.xp, p.xp_next), bx + bw / 2, y0 + 65, "#e0e0ff", 8, bw - 8, "center", true)
	# állapotok: méreg, gyökér, kábulat, regeneráció, életlopás
	var st: Array = []
	if p.poison > 0: st.append([Lang.T("hud.poison", p.poison), "#a0e040"])
	if p.rooted > 0: st.append([Lang.T("hud.rooted", p.rooted), "#70d060"])
	if p.stun > 0: st.append([Lang.T("hud.stun"), "#c8f0e8"])
	if p.regen > 0: st.append([Lang.T("hud.regen", p.regen), "#60d080"])
	if p.lifesteal > 0: st.append([Lang.T("hud.steal", int(roundf(p.lifesteal * 100))), "#e06070"])
	var sx := bx
	for e in st:
		var tw := Cv.measure(str(e[0]), 10) + 12
		if sx + tw > bx + bw + 40:
			break
		c.rrect_fill_c(sx, y0 + 76, tw, 18, 6, Color(Cv.col(e[1]), 0.16))
		c.ftxt(str(e[0]), sx + 6, y0 + 89, e[1], 10)
		sx += tw + 5
	# ── gyorsgombok ──
	var ax := bx + bw + 34
	var ss := 52.0
	var sy := y0 + 20
	_slot(c, ax, sy, ss, Lang.T("key.space_short"), "»", p.col, p.dash_cd, p.dash_cd_max, Lang.T("ab.dash"), p.rooted > 0)
	_slot(c, ax + 78, sy, ss, "Q", str(Data.SKILL_ICON[p.cls]), str(Data.SKILL_COL[p.cls]), p.skill_cd, p.skill_cd_max, Lang.T("ab." + str(Data.SKILL[p.cls])))
	# a Sebész kioperált szervei a képesség sarkában; Gőzköpeny: a feltöltött ütés jele
	if p.cls == "Sebész":
		c.rrect_fill_c(ax + 78 + ss - 14, sy + ss - 14, 22, 18, 6, "#10221e")
		c.ftxt(str(p.organs), ax + 78 + ss - 3, sy + ss, "#a0f0d8" if p.organs > 0 else "#6a6a6a", 12, "center", true)
	if p.steam_charge:
		c.ftxt("×2", ax + ss - 2, sy + ss - 2, "#ffffff", 12, "right", true)
	# ereklyék: kis jelvények a sáv fölött
	for i in p.relics.size():
		var rd: Dictionary = Relics.LIST[p.relics[i]]
		var rx := 16.0 + i * 34.0
		c.rrect_fill_c(rx, y0 - 36, 28, 28, 7, Cv.rgba(10, 8, 6, 0.85))
		c.rrect_stroke_c(rx, y0 - 36, 28, 28, 7, 1.4, rd["col"])
		c.ftxt(str(rd["ic"]), rx + 14, y0 - 16, rd["col"], 15, "center")
	var pots := potions(p)
	_slot(c, ax + 156, sy, ss, "E", "✚", "#50d070", 0, 1, Lang.T("ab.potion"), pots == 0)
	c.rrect_fill_c(ax + 156 + ss - 14, sy + ss - 14, 22, 18, 6, "#16280f")
	c.ftxt(str(pots), ax + 156 + ss - 3, sy + ss, "#9ce0a0" if pots > 0 else "#6a6a6a", 12, "center", true)
	# ── értékek, nyersanyag, zóna ──
	var cx2 := ax + 156 + ss + 40
	var mx := maxf(cx2 + 250, W * 0.64)
	var colw := mx - cx2 - 16
	var atk_txt := ("✦ %d" % p.mag) if p.cls == "Mágus" else ("⚔ %d" % p.atk)
	c.ftxt(atk_txt, cx2, y0 + 26, "#ffd060" if p.cls != "Mágus" else "#8cc4ff", 15)
	c.ftxt("🛡 %d" % p.def, cx2 + 74, y0 + 26, "#80a8e0", 15)
	c.ftxt("◉ %d" % p.gold, cx2, y0 + 50, P["parchGold"], 13)
	c.ftxt("☣ %d" % p.bio, cx2 + 74, y0 + 50, "#b0e060", 13)
	c.ftxt("⚙ %d" % p.rez, cx2 + 140, y0 + 50, "#e0a060", 13)
	c.ftxt_fit(Lang.T("hud.zone", w.dungeon_level, Data.MAX_LEVEL, Lang.T("zone." + str(z["id"]))) + "  ·  " + Lang.T("hud.emelet", w.emelet, Data.emeletek(w.dungeon_level)), cx2, y0 + 72, str(z["acc"]), 12, colw)
	if m.game.on_stair():
		if m.game.can_descend():
			var key_s: String = m.key_label(m.binds["stair"])
			c.ftxt_fit(Lang.T("hud.stair" if w.dungeon_level < Data.MAX_LEVEL else "hud.core", key_s), cx2, y0 + 92, "#ffe890", 12, colw)
		else:
			c.ftxt_fit(Lang.T("hud.stair_locked"), cx2, y0 + 92, "#ff8070", 12, colw)
	else:
		c.ftxt_fit(Lang.T("hud.keys", m.key_label(m.binds["inventory"])), cx2, y0 + 92, P["inkDark"], 10, colw)
	# ── üzenetnapló ──
	var mw := W - mx - 14
	if mw > 120:
		c.rrect_fill_c(mx - 8, y0 + 10, mw + 14, Data.HUD_H - 18, 8, Cv.rgba(0, 0, 0, 0.35))
		var msgs: Array = p.msgs.slice(maxi(0, p.msgs.size() - 5))
		for i in msgs.size():
			var last := i == msgs.size() - 1
			c.ga(0.45 + 0.55 * (float(i + 1) / msgs.size()))
			c.ftxt_fit(Lang.txt(msgs[i]["t"]), mx, y0 + 27 + i * 18, msgs[i]["c"], 12 if last else 11, mw)
			c.ga(1.0)

## A nekilendülés görbéje: a figura nem "odaugrik", hanem gyorsan kilendül és lágyan visszahúzódik.
## l: 1 -> 0 (a támadás óta eltelt idő); az eredmény 0 -> 1 -> 0.
static func lendulet(l: float) -> float:
	if l <= 0.0:
		return 0.0
	var e := 1.0 - l
	return sin(minf(1.0, e / 0.3) * PI * 0.5) if e < 0.3 else cos((e - 0.3) / 0.7 * PI * 0.5)


## Megfordulás: a figura a függőleges tengelye körül "átfordul" (rf: -1..1), nem pattan át tükörképbe.
static func _fordit(c: Cv, kx: float, rf: float) -> void:
	var s := rf if absf(rf) >= 0.12 else (0.12 if rf >= 0.0 else -0.12)
	if is_equal_approx(s, 1.0):
		return
	c.translate(kx, 0)
	c.scale(s, 1)
	c.translate(-kx, 0)
