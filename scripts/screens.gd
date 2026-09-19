class_name Screens
extends RefCounted
## Menük és felületek: főmenü (sárkányos borító), irányítás/billentyűszerkesztő, nehézség,
## hősválasztás, táska, láda-választó, játék vége, hang gomb.

static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Cv.rgba(r, g, b, a)


# ══════════ FŐMENÜ ══════════
static func _menu_geo(m: Node) -> Dictionary:
	var W: float = m.W
	var H: float = m.H
	var k := minf(W, H) / 600.0
	var floor_y := H * 0.78
	var arch_w := minf(W * 0.52, 420 * k)
	var arch_r := arch_w / 2
	var spring := floor_y - arch_w * 0.52
	return {"W": W, "H": H, "k": k, "floor_y": floor_y, "arch_r": arch_r, "spring": spring}


static func menu_bg(m: Node, c: Cv) -> void:
	MenuArt.static_bg(c, m.W, m.H, m.tex_grain)


## a sárkány a boltív belsejében (a réteg árnyalója vág a boltív alakjára)
static func menu_clip(m: Node, c: Cv) -> void:
	var g := _menu_geo(m)
	var W: float = g["W"]
	var arch_r: float = g["arch_r"]
	var spring: float = g["spring"]
	var floor_y: float = g["floor_y"]
	var k: float = g["k"]
	var mat: ShaderMaterial = m.clip_mat
	mat.set_shader_parameter("arch_c", Vector2(W / 2, spring))
	mat.set_shader_parameter("arch_r", arch_r)
	mat.set_shader_parameter("floor_y", floor_y)
	var d_sz := minf(arch_r * 1.85, 350 * k)
	var d_cy := spring + arch_r * 0.62
	var dg := Cv.radial(W / 2, d_cy - d_sz * 0.3, 8, d_sz * 1.2).stop(0, rgba(180, 45, 18, 0.32)).stop(1, rgba(80, 8, 8, 0))
	dg.seg = 30.0
	c.fs(dg); c.fill_rect(W / 2 - arch_r, spring - arch_r, arch_r * 2, floor_y - spring + arch_r)
	MenuArt.dragon(c, W / 2, d_cy, d_sz, m.tick)
	MenuArt.fire(c, W / 2, d_cy - (11.4 * (d_sz / 30)), d_sz / 30, m.tick)


static func menu_front(m: Node, c: Cv) -> void:
	var g := _menu_geo(m)
	var W: float = g["W"]
	var H: float = g["H"]
	var k: float = g["k"]
	var floor_y: float = g["floor_y"]
	var tick: float = m.tick
	# fáklyák
	var torch_x := [W * 0.18, W * 0.82]
	var torch_y := H * 0.36
	MenuArt.torch(c, torch_x[0], torch_y, k, tick, 0, m.tex_menu_torch)
	MenuArt.torch(c, torch_x[1], torch_y, k, tick, 2.4, m.tex_menu_torch)
	# fénytócsák a fáklyák alatt
	for tx in torch_x:
		c.tex(m.tex_glow, Rect2(tx - 180 * k, floor_y + 50 * k - 70 * k, 360 * k, 140 * k), rgba(200, 100, 20, 0.18))
	# hősök
	var spread := W * 0.22
	var feet_y := H * 0.88
	var m_size := minf(110 * k, H * 0.2)
	var k_size := minf(135 * k, H * 0.24)
	_hero_glow(m, c, W / 2 - spread, feet_y, "#c070f0", m_size, k)
	Sprites.hero_cached(c, "Mágus", W / 2 - spread, feet_y - m_size * 0.44, m_size, tick)
	_hero_glow(m, c, W / 2 + spread, feet_y, "#70d860", m_size, k)
	c.save(); c.translate(W / 2 + spread, 0); c.scale(-1, 1); c.translate(-(W / 2 + spread), 0)
	Sprites.hero_cached(c, "Íjász", W / 2 + spread, feet_y - m_size * 0.44, m_size, tick)
	c.restore()
	_hero_glow(m, c, W / 2, feet_y, "#70c8e8", k_size, k)
	Sprites.hero_cached(c, "Lovag", W / 2, feet_y - k_size * 0.44, k_size, tick)
	# parázs
	for i in 55:
		var sp := 0.18 + Data.rnd_seed_m(i * 3.7) * 0.65
		var ex := fposmod(Data.rnd_seed_m(i * 1.31) * W + sin(tick * 0.02 + i) * 26 * k + W, W)
		var ey := H - fposmod(tick * 0.85 * sp + Data.rnd_seed_m(i * 7.1) * H, H * 1.03)
		var al := 0.08 + 0.4 * absf(sin(tick * 0.05 + i))
		var er := (0.7 + Data.rnd_seed_m(i * 5.5) * 2.2) * k
		c.fs(rgba(255, int(145 + Data.rnd_seed_m(i) * 85), 45, al * 0.8))
		c.circ(ex, ey, er)
	# vignetta
	var vr := maxf(W, H) * 0.8
	c.tex(m.tex_vignette, Rect2(W / 2 - vr, H * 0.5 - vr, vr * 2, vr * 2))
	# címszalag
	var bw := minf(W * 0.88, 580 * k)
	var bh := minf(168 * k, H * 0.24)
	var bx := (W - bw) / 2
	var by := H * 0.042
	c.soft_shadow(bx, by, bw, bh, 12 * k, rgba(0, 0, 0, 0.88), 36 * k, 10 * k)
	var bg2 := Cv.linear(0, by, 0, by + bh).stop(0, "#33250f").stop(0.5, "#231a0b").stop(1, "#150f06")
	c.fs(bg2); c.rrect(bx, by, bw, bh, 12 * k); c.fill()
	c.ss("#d4a84b"); c.lw(2.8 * k); c.rrect(bx, by, bw, bh, 12 * k); c.stroke()
	c.ss(rgba(212, 168, 75, 0.3)); c.lw(1.2 * k)
	c.rrect(bx + 8 * k, by + 8 * k, bw - 16 * k, bh - 16 * k, 9 * k); c.stroke()
	MenuArt.ornament(c, bx + 26 * k, by + 22 * k, bw - 52 * k, "#8a6a2e", k)
	var tt := _title_geo(m, bw, bh, by, k)
	var tsz: float = tt["tsz"]
	var ty: float = tt["ty"]
	var tot: float = tt["tot"]
	# a cím izzó árnyéka
	c.tex(m.tex_glow, Rect2(W / 2 - tot / 2 - 40 * k, ty - tsz * 1.05, tot + 80 * k, tsz * 1.45), rgba(255, 160, 35, 0.22))
	MenuArt.ls_text(c, "KARD ÉS MÁGIA", W / 2 + 1.5 * k, ty + 1.5 * k, "#1a1005", tsz, tsz * 0.055, "center")
	# keresztbe tett kardok a cím két oldalán
	var half_t := tot / 2
	MenuArt.crossed_swords(c, W / 2 - half_t - 40 * k, ty - tsz * 0.28, tsz * 0.78, "#c8a03a")
	MenuArt.crossed_swords(c, W / 2 + half_t + 40 * k, ty - tsz * 0.28, tsz * 0.78, "#c8a03a")
	c.ftxt("ROGUELIKE KALAND  ·  5 MÉLYSÉG  ·  3 HŐS", W / 2, by + bh * 0.84, "#9c8354", minf(16 * k, tsz * 0.28), "center")
	MenuArt.ornament(c, bx + 26 * k, by + bh - 20 * k, bw - 52 * k, "#6a5222", k)


static func _title_geo(m: Node, bw: float, bh: float, by: float, k: float) -> Dictionary:
	var title := "KARD ÉS MÁGIA"
	var tsz := minf(48 * k, bw / 10)
	var tot := MenuArt.ls_width(title, tsz, tsz * 0.055)
	while tot > bw - 200 * k and tsz > 14:
		tsz -= 1
		tot = MenuArt.ls_width(title, tsz, tsz * 0.055)
	return {"tsz": tsz, "tot": tot, "ty": by + bh * 0.60}


## a hős körüli színes fény és a lába alatti árnyék (sugaras textúrával)
static func _hero_glow(m: Node, c: Cv, x: float, feet_y: float, glow: String, size: float, k: float) -> void:
	var gc: Color = Cv.col(glow)
	gc.a = 0x28 / 255.0
	var r := size * 0.9
	c.tex(m.tex_glow, Rect2(x - r, feet_y - size * 0.42 - r, r * 2, r * 2), gc)
	c.tex(m.tex_glow, Rect2(x - size * 0.44, feet_y + 6 * k - size * 0.10, size * 0.88, size * 0.20), rgba(0, 0, 0, 0.7))


## a cím arany színátmenettel (a réteg árnyalója színez)
static func menu_title(m: Node, c: Cv) -> void:
	var g := _menu_geo(m)
	var W: float = g["W"]
	var H: float = g["H"]
	var k: float = g["k"]
	var bw := minf(W * 0.88, 580 * k)
	var bh := minf(168 * k, H * 0.24)
	var by := H * 0.042
	var tt := _title_geo(m, bw, bh, by, k)
	var tsz: float = tt["tsz"]
	var ty: float = tt["ty"]
	var mat: ShaderMaterial = m.title_mat
	mat.set_shader_parameter("top", ty - tsz * 0.85)
	mat.set_shader_parameter("bot", ty + tsz * 0.18)
	MenuArt.ls_text(c, "KARD ÉS MÁGIA", W / 2, ty - 1 * k, Color.WHITE, tsz, tsz * 0.055, "center")


static func menu_top(m: Node, c: Cv) -> void:
	var g := _menu_geo(m)
	var W: float = g["W"]
	var H: float = g["H"]
	var k: float = g["k"]
	var P := Data.P
	# gombok
	var btn_w := minf(300 * k, W - 56)
	var btn_h := minf(54 * k, H * 0.085)
	var btn_y := H * 0.50
	var btns := [
		{"t": "⚔  Kaland kezdete", "c": P["parchGold"], "bg": "#2e2210", "bd": P["parchGold"], "fn": m.go_diff},
		{"t": "Irányítás", "c": P["ink"], "bg": "#241a0c", "bd": P["parchEdge"], "fn": func() -> void: m.set_state("help")},
	]
	for i in btns.size():
		var bx2 := (W - btn_w) / 2
		var by2 := btn_y + i * (btn_h + 14 * k)
		if i == 0:
			c.soft_shadow(bx2, by2, btn_w, btn_h, 8, rgba(212, 168, 75, 0.45), 18 * k)
		c.panel(bx2, by2, btn_w, btn_h, btns[i]["bg"], btns[i]["bd"], 2, 8)
		c.ftxt(btns[i]["t"], W / 2, by2 + btn_h * 0.62, btns[i]["c"], minf(17 * k, 17), "center")
		m.add_hit(bx2, by2, btn_w, btn_h, btns[i]["fn"])
	# sarokdíszek
	var fw := minf(100 * k, W * 0.1)
	MenuArt.flourish(c, 22 * k, 28 * k, fw, "#c8a03a", k, false)
	MenuArt.flourish(c, W - 22 * k, 28 * k, fw, "#c8a03a", k, true)
	MenuArt.flourish(c, 22 * k, H - 28 * k, fw, "#c8a03a", k, false)
	MenuArt.flourish(c, W - 22 * k, H - 28 * k, fw, "#c8a03a", k, true)
	# keret
	c.ss(rgba(212, 168, 75, 0.65)); c.lw(2.4 * k)
	c.stroke_rect(14 * k, 14 * k, W - 28 * k, H - 28 * k)
	c.ss(rgba(212, 168, 75, 0.22)); c.lw(1 * k)
	c.stroke_rect(22 * k, 22 * k, W - 44 * k, H - 44 * k)
	var hint := "♪ Háttérzene szól  ·  M vagy 🔊: hang ki/be  ·  F11: teljes képernyő" if m.audio.music_started else "♪ A háttérzene hamarosan indul...  ·  F11: teljes képernyő"
	c.ftxt(hint, W / 2, H - 10, P["inkDark"], minf(10 * k, 10), "center")


# ══════════ IRÁNYÍTÁS + BILLENTYŰSZERKESZTŐ ══════════
static func help(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	c.fs("#080604"); c.fill_rect(0, 0, W, H)
	var info := [
		["Mozgás / Támadás", "WASD vagy nyilak — tartsd lenyomva a folyamatos járáshoz"],
		["Íj / Ágyú / Varázsgömb", "Lő az irányba, ha szörny van a vonalban"],
		["Láda", "Sétálj rá, válassz a két tárgyból"],
		["Hang / Képernyő", "M: hang ki/be  ·  F11: teljes képernyő"],
	]
	var bind_rows := [
		["up", "Fel / Mozgás ↑"], ["down", "Le / Mozgás ↓"], ["left", "Bal / Mozgás ←"], ["right", "Jobb / Mozgás →"],
		["stair", "Lépcső (lejjebb)"], ["inventory", "Táska"], ["menu", "Menü / Vissza"],
	]
	var head := 68 + info.size() * 34 + 5   # az elválasztó vonalig
	var pw := minf(500, W - 24)
	var ph := minf(head + 31 + 7 * 36 + 6 + 34 + 12 + 44 + 16, H - 24)
	var row_h := clampf((ph - (head + 31) - (6 + 34 + 12 + 44 + 16)) / 7.0, 26, 36)
	var ox := (W - pw) / 2
	var oy := maxf(12, (H - ph) / 2)
	c.panel(ox, oy, pw, ph, P["parch"], P["parchGold"], 2, 10)
	c.orna(ox + 16, oy + 18, pw - 32, P["parchEdge"])
	c.ftxt("Irányítás & Billentyűk", W / 2, oy + 42, P["parchGold"], 18, "center")
	c.orna(ox + 16, oy + 52, pw - 32, P["parchEdge"])
	for i in info.size():
		var ly := oy + 68 + i * 34
		c.ftxt(info[i][0], ox + 20, ly, P["parchGold"], 12)
		c.ftxt_fit(info[i][1], ox + 20, ly + 15, P["ink"], 10, pw - 40)
	c.orna(ox + 16, oy + head, pw - 32, "#241a0c")
	c.ftxt("Testreszabható billentyűk", W / 2, oy + head + 19, P["inkDark"], 11, "center")
	var rows_y := oy + head + 31
	var btn_w := minf(110, pw * 0.3)
	var btn_x := ox + pw - btn_w - 16
	for i in bind_rows.size():
		var key: String = bind_rows[i][0]
		var label: String = bind_rows[i][1]
		var ry := rows_y + i * row_h
		var editing: bool = m.bind_edit == key
		c.fs("#3a2a0a" if editing else "#1c1408")
		c.rrect(ox + 10, ry, pw - 20, row_h - 4, 5); c.fill()
		c.ss(P["parchGold"] if editing else P["parchEdge"]); c.lw(2 if editing else 1)
		c.rrect(ox + 10, ry, pw - 20, row_h - 4, 5); c.stroke()
		c.ftxt(label, ox + 24, ry + row_h / 2 + 3, P["parchGold"] if editing else P["ink"], 11)
		var lbl: String = "[ nyomj egy billentyűt ]" if editing else m.key_label(m.binds[key])
		c.fs("#5a3a10" if editing else "#2a1e08"); c.rrect(btn_x, ry + 4, btn_w, row_h - 12, 5); c.fill()
		c.ss(P["parchGold"] if editing else P["parchEdge"]); c.lw(1.5); c.rrect(btn_x, ry + 4, btn_w, row_h - 12, 5); c.stroke()
		c.ftxt_fit(lbl, btn_x + btn_w / 2, ry + row_h / 2 + 4, "#ffd700" if editing else P["parchGold"], 8 if editing else 12, btn_w - 8, "center")
		m.add_hit(ox + 10, ry, pw - 20, row_h - 4, func() -> void: m.bind_edit = "" if m.bind_edit == key else key)
	# visszaállítás
	var reset_y := rows_y + bind_rows.size() * row_h + 6
	var rw := minf(220, pw - 40)
	var rh := 34.0
	var rx2 := ox + (pw - rw) / 2
	c.panel(rx2, reset_y, rw, rh, "#1e0808", "#8a2a2a", 1.5, 6)
	c.ftxt("↺ Alapértelmezett visszaállítás", W / 2, reset_y + 22, "#d06060", 10, "center")
	m.add_hit(rx2, reset_y, rw, rh, func() -> void: m.reset_binds())
	# vissza
	var bw2 := minf(200, pw - 40)
	var bh := 44.0
	var bx := (W - bw2) / 2
	var by := oy + ph - bh - 12
	c.panel(bx, by, bw2, bh, "#2e2210", P["parchGold"], 2, 8)
	c.ftxt("← Vissza", W / 2, by + 28, P["parchGold"], 14, "center")
	m.add_hit(bx, by, bw2, bh, m.close_help)
	if m.bind_edit != "":
		c.ftxt("Nyomj bármilyen billentyűt a hozzárendeléshez", W / 2, reset_y + rh + 11, P["inkDark"], 9, "center")


# ══════════ NEHÉZSÉG ══════════
static func diff_sel(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	c.fs("#080604"); c.fill_rect(0, 0, W, H)
	c.ftxt("Nehézség", W / 2, maxf(46, H * 0.1), P["parchGold"], 24, "center")
	var diffs := [["Könnyű", "Gyenge ellenségek", "#50a050"], ["Közepes", "Igazi kihívás", P["parchGold"]], ["Nehéz", "Kegyetlen mélység", "#d05040"]]
	var bw2 := minf(180, (W - 80) / 3)
	var bh := 190.0
	var start_x := (W - bw2 * 3 - 32) / 2
	var by := H * 0.22
	for i in 3:
		var label: String = diffs[i][0]
		var desc: String = diffs[i][1]
		var col: String = diffs[i][2]
		var bx := start_x + i * (bw2 + 16)
		var sel: bool = m.diff_sel == i
		c.panel(bx, by, bw2, bh, "#3a2810" if sel else "#1c1408", col if sel else P["parchEdge"], 2.5 if sel else 1.0, 8)
		c.ftxt(label, bx + bw2 / 2, by + 42, col if sel else P["ink"], 17, "center")
		c.ftxt_fit(desc, bx + bw2 / 2, by + 76, P["inkDark"], 11, bw2 - 12, "center")
		if sel:
			c.ftxt("✓ Kiválasztva", bx + bw2 / 2, by + bh - 20, col, 11, "center")
		m.add_hit(bx, by, bw2, bh, func() -> void:
			if m.diff_sel == i:
				m.char_sel = 0
				m.set_state("char")
			else:
				m.diff_sel = i)
	var cw := 240.0
	var ch := 50.0
	var cx2 := (W - cw) / 2
	var cy2 := by + bh + 30
	c.panel(cx2, cy2, cw, ch, "#2e2210", P["parchGold"], 2, 8)
	c.ftxt("Tovább  →", W / 2, cy2 + 32, P["parchGold"], 15, "center")
	m.add_hit(cx2, cy2, cw, ch, m.go_char)
	_back_btn(m, c, "menu")


static func _back_btn(m: Node, c: Cv, to: String) -> void:
	var P := Data.P
	c.panel(12, 12, 110, 40, "#1c1408", P["parchEdge"], 1.5, 6)
	c.ftxt("← Vissza", 12 + 55, 12 + 26, P["ink"], 12, "center")
	m.add_hit(12, 12, 110, 40, func() -> void: m.set_state(to))


# ══════════ HŐSVÁLASZTÁS ══════════
static func char_sel(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	c.fs("#080604"); c.fill_rect(0, 0, W, H)
	c.ftxt("Válassz Hőst", W / 2, maxf(44, H * 0.08), P["parchGold"], 24, "center")
	var n := Data.CLASS_ORDER.size()
	var bw2 := minf(200, (W - 100) / 3)
	var bh := minf(H * 0.6, 400)
	var start_x := (W - bw2 * 3 - 40) / 2
	var by := H * 0.14
	for i in n:
		var name: String = Data.CLASS_ORDER[i]
		var s: Dictionary = Data.CLASSES[name]
		var bx := start_x + i * (bw2 + 20)
		var sel: bool = m.char_sel == i
		c.panel(bx, by, bw2, bh, "#2e2210" if sel else "#1a1206", s["col"] if sel else P["parchEdge"], 2.5 if sel else 1.0, 10)
		Sprites.hero_cached(c, name, bx + bw2 / 2, by + bh * 0.24, minf(110, bh * 0.3), m.tick)
		c.ftxt(name, bx + bw2 / 2, by + bh * 0.46, P["parchGold"] if sel else P["ink"], 18, "center")
		var stats := [["♥ Életerő", s["hp"], "#d04030"],
			(["✦ Varázserő", s["mag"], "#6aa8ff"] if s["mag"] > 0 else ["⚔ Támadás", s["atk"], "#e09030"]),
			["🛡 Védelem", s["def"], "#5080d0"]]
		for j in 3:
			c.ftxt(stats[j][0], bx + 18, by + bh * 0.56 + j * 24, stats[j][2], 11)
			c.ftxt(str(stats[j][1]), bx + bw2 - 18, by + bh * 0.56 + j * 24, P["ink"], 12, "right")
		c.wrap_text(s["desc"], bx + bw2 / 2, by + bh * 0.80, bw2 - 30, 10, P["inkDark"], "center")
		if sel:
			c.ftxt("✓", bx + bw2 - 22, by + 26, s["col"], 18, "center")
		m.add_hit(bx, by, bw2, bh, func() -> void:
			if m.char_sel == i:
				m.start_game(Data.CLASS_ORDER[i], Data.DIFF_ORDER[m.diff_sel])
			else:
				m.char_sel = i)
	var sw := 260.0
	var sh := 52.0
	var sx3 := (W - sw) / 2
	var sy3 := by + bh + 24
	c.panel(sx3, sy3, sw, sh, "#2e2210", P["parchGold"], 2.5, 10)
	c.ftxt("⚔ Indulás!", W / 2, sy3 + 34, P["parchGold"], 17, "center")
	m.add_hit(sx3, sy3, sw, sh, func() -> void: m.start_game(Data.CLASS_ORDER[m.char_sel], Data.DIFF_ORDER[m.diff_sel]))
	_back_btn(m, c, "diff")


# ══════════ TÁSKA ══════════
static func inventory(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var p: Player = m.game.player
	var tick: float = m.tick
	c.fs(rgba(0, 0, 0, 0.88)); c.fill_rect(0, 0, W, H)
	var pw := minf(580, W - 20)
	var ph := minf(H - 30, 600)
	var ox := (W - pw) / 2
	var oy := (H - ph) / 2
	c.panel(ox, oy, pw, ph, P["parch"], P["parchEdge"], 2, 10)
	c.ftxt("Felszerelés & Táska", W / 2, oy + 30, P["parchGold"], 18, "center")
	c.orna(ox + 18, oy + 40, pw - 36, P["parchEdge"])
	# felszerelt tárgyak: fegyver, páncél, pajzs
	var slots := [["⚔", p.weapon, "Nincs fegyver (puszta kéz)"], ["🛡", p.armor, "Nincs páncél"], ["⛨", p.shield, "Nincs pajzs"]]
	for i in 3:
		var sy := oy + 52 + i * 26
		var it: Item = slots[i][1]
		c.fs("#1e1508"); c.rrect(ox + 12, sy, pw - 24, 22, 4); c.fill()
		if it:
			Sprites.item_icon(c, it, ox + 26, sy + 11, 18, tick)
			var stats := it.short_stats(p.cls, p.mag)
			var sw := minf(Cv.measure(stats, 10), (pw - 60) * 0.55)
			c.ftxt_fit(stats, ox + pw - 20, sy + 15, P["parchGold"], 10, sw, "right")
			c.ftxt_fit("%s %s" % [slots[i][0], it.label], ox + 40, sy + 15, it.border(), 11, pw - 60 - sw - 16)
		else:
			c.ftxt_fit("%s %s" % [slots[i][0], slots[i][2]], ox + 40, sy + 15, P["inkDark"], 11, pw - 60)
	c.orna(ox + 18, oy + 134, pw - 36, "#241a0c")
	var items := p.inventory
	var list_y := oy + 144
	var row_h := 44.0
	var foot := 86.0
	var max_show := maxi(1, int((ph - (list_y - oy) - foot) / row_h))
	var max_scroll := maxi(0, items.size() - max_show)
	m.inv_scroll = clampi(m.inv_scroll, 0, max_scroll)
	var off: int = m.inv_scroll
	if items.is_empty():
		c.ftxt("Üres a táskád.", W / 2, list_y + 30, P["inkDark"], 13, "center")
	for r in mini(items.size() - off, max_show):
		var idx := off + r
		var it: Item = items[idx]
		var iy := list_y + r * row_h
		c.fs("#221808"); c.rrect(ox + 10, iy, pw - 20, row_h - 6, 5); c.fill()
		c.ss(it.border()); c.lw(1.5); c.rrect(ox + 10, iy, pw - 20, row_h - 6, 5); c.stroke()
		Sprites.item_icon(c, it, ox + 30, iy + (row_h - 6) / 2, row_h * 0.62, tick)
		var key_txt := ("[%s]" % String.chr(65 + idx)) if idx < 26 else ""
		var action := "felvesz" if it.slot != "use" else "használ"
		var right := "%s %s" % [action, key_txt]
		var rw := Cv.measure(right, 9)
		c.ftxt(right, ox + pw - 22, iy + 16, P["inkDark"], 9, "right")
		c.ftxt_fit(it.label, ox + 54, iy + 16, it.glow(), 12, pw - 54 - 30 - rw - 12)
		c.ftxt_fit(it.short_stats(p.cls, p.mag), ox + 54, iy + 32, P["parchGold"], 10, pw - 54 - 30)
		m.add_hit(ox + 10, iy, pw - 20, row_h - 6, func() -> void: m.use_inv(idx))
	if items.size() > max_show:
		var more := "▲▼ görgetés  ·  %d–%d / %d tárgy" % [off + 1, off + mini(max_show, items.size() - off), items.size()]
		c.ftxt(more, W / 2, list_y + max_show * row_h + 10, P["inkDark"], 10, "center")
	var cw := minf(200, pw - 40)
	var ch2 := 46.0
	var cx2 := (W - cw) / 2
	var cy2 := oy + ph - ch2 - 12
	c.ftxt_fit("Kattints egy tárgyra (vagy nyomd meg a betűjét) a felvételhez / használathoz", W / 2, cy2 - 8, P["inkDark"], 9, pw - 30, "center")
	c.panel(cx2, cy2, cw, ch2, "#2e2210", P["parchGold"], 2, 8)
	c.ftxt("Bezárás", W / 2, cy2 + 30, P["parchGold"], 14, "center")
	m.add_hit(cx2, cy2, cw, ch2, func() -> void: m.set_state("play"))


# ══════════ LÁDA ══════════
static func chest(m: Node, c: Cv) -> void:
	if m.chest_ui == null:
		return
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var p: Player = m.game.player
	var tick: float = m.tick
	var ch: Dictionary = m.chest_ui["chest"]
	var sel: int = m.chest_ui["sel"]
	c.fs(rgba(0, 0, 0, 0.9)); c.fill_rect(0, 0, W, H)
	var pw := minf(580, W - 20)
	var nmax := 0
	for it in ch["items"]:
		nmax = maxi(nmax, (it as Item).stat_lines(p.cls, p.mag).size())
	var card_h := maxf(225.0, 122.0 + nmax * 17 + 14)
	var ph := 70 + card_h + 50
	var ox := (W - pw) / 2
	var oy := maxf(10, (H - ph) / 2)
	c.panel(ox, oy, pw, ph, P["parch"], P["parchGold"], 2, 10)
	c.ftxt("⚜ Láda! Válassz egyet:", W / 2, oy + 30, P["parchGold"], 16, "center")
	c.orna(ox + 16, oy + 40, pw - 32, P["parchEdge"])
	for i in 2:
		var it: Item = ch["items"][i]
		var iw := (pw - 36) / 2
		var ix := ox + 12 + i * (iw + 12)
		var iy2 := oy + 52
		var gcol: Color = Cv.col(it.glow())
		if i == sel:
			c.soft_shadow(ix, iy2, iw, card_h, 8, Color(gcol, 0.55), 14)
		c.panel(ix, iy2, iw, card_h, "#1e1408", it.border(), 3.0 if i == sel else 2.0, 8)
		Sprites.item_icon(c, it, ix + iw / 2, iy2 + 46, 54, tick)
		c.ftxt_fit(it.label, ix + iw / 2, iy2 + 88, it.glow(), 12, iw - 16, "center")
		c.ftxt("[%s]" % it.rar()["label"], ix + iw / 2, iy2 + 104, it.border(), 10, "center")
		var stats := it.stat_lines(p.cls, p.mag)
		for j in stats.size():
			c.ftxt_fit(stats[j], ix + iw / 2, iy2 + 122 + j * 17, P["ink"], 11, iw - 16, "center")
		m.add_hit(ix, iy2, iw, card_h, func() -> void:
			m.chest_ui["sel"] = i
			m.pick_chest_item())
	c.ftxt("Kattints a tárgyra, vagy ←/→ és Enter  ·  Esc: később", W / 2, oy + ph - 12, P["inkDark"], 10, "center")


# ══════════ JÁTÉK VÉGE ══════════
static func game_over(m: Node, c: Cv, won: bool) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	c.fs(rgba(0, 0, 0, 0.9)); c.fill_rect(0, 0, W, H)
	var pw := minf(440, W - 24)
	var ph := 250.0
	var ox := (W - pw) / 2
	var oy := (H - ph) / 2
	c.panel(ox, oy, pw, ph, "#1e1a08" if won else "#180808", P["parchGold"] if won else P["vein"], 2.5, 10)
	c.orna(ox + 18, oy + 20, pw - 36, P["parchEdge"] if won else "#5a1a1a")
	c.ftxt("⚜ GYŐZELEM ⚜" if won else "☠ ELESTÉL ☠", W / 2, oy + 62, P["parchGold"] if won else P["vein"], 26, "center")
	c.ftxt("Megölted a Sárkányt!" if won else "A sötétség elnyelt...", W / 2, oy + 98, P["ink"] if won else P["inkDark"], 14, "center")
	if m.game.world:
		var p: Player = m.game.player
		c.ftxt("Szint %d · Kör %d · Mélység %d/%d" % [p.plvl, m.game.world.turn, m.game.world.dungeon_level, Data.MAX_LEVEL], W / 2, oy + 126, P["inkDark"], 11, "center")
	var bw2 := minf(220, pw - 40)
	var bh := 50.0
	var bx := (W - bw2) / 2
	var by := oy + ph - bh - 18
	c.panel(bx, by, bw2, bh, "#2e2210", P["parchGold"], 2, 8)
	c.ftxt("Főmenü", W / 2, by + 32, P["parchGold"], 15, "center")
	m.add_hit(bx, by, bw2, bh, func() -> void: m.set_state("menu"))


# ══════════ HANG GOMB (jobb felső sarok) ══════════
static func mute_rect(m: Node) -> Rect2:
	return Rect2(m.W - 10 - 44, 10, 44, 44)


static func mute_button(m: Node, c: Cv) -> void:
	var r := mute_rect(m)
	var cx := r.position.x + 22
	var cy := r.position.y + 22
	c.fs(rgba(22, 14, 4, 0.85)); c.circ(cx, cy, 22)
	c.ss("#7a5a2a"); c.lw(2); c.bp(); c.arc(cx, cy, 21, 0, 7); c.stroke()
	c.ftxt("🔇" if m.audio.muted else "🔊", cx, cy + 7, "#d4a84b", 18, "center")
