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
	# a boltív mögötti vörös derengés mozdulatlan: elég egyszer kiszámolni a színátmenet hálóját
	c.blit("arch_glow|%d|%d|%d" % [int(roundf(arch_r)), int(roundf(spring)), int(roundf(floor_y))], func() -> void:
		var dg := Cv.radial(0, d_cy - spring - d_sz * 0.3, 8, d_sz * 1.2).stop(0, rgba(180, 45, 18, 0.32)).stop(1, rgba(80, 8, 8, 0))
		dg.seg = 30.0
		c.fs(dg); c.fill_rect(-arch_r, -arch_r, arch_r * 2, floor_y - spring + arch_r), W / 2, spring)
	MenuArt.dragon(c, W / 2, d_cy, d_sz, m.tick)
	MenuArt.fire(c, W / 2, d_cy - (11.4 * (d_sz / 30)), d_sz / 30, m.tick)


static var _ember_rnd: Array = []


static func menu_front(m: Node, c: Cv) -> void:
	var g := _menu_geo(m)
	var W: float = g["W"]
	var H: float = g["H"]
	var k: float = g["k"]
	var floor_y: float = g["floor_y"]
	var tick: float = m.tick
	# fáklyák (a textúrás fényudvarok egyben, utána a rajzolt részek: így kevesebb rajzhívás kell)
	var torch_x := [W * 0.18, W * 0.82]
	var torch_y := H * 0.36
	MenuArt.torch_glow(c, torch_x[0], torch_y, k, tick, 0, m.tex_menu_torch)
	MenuArt.torch_glow(c, torch_x[1], torch_y, k, tick, 2.4, m.tex_menu_torch)
	# fénytócsák a fáklyák alatt
	for tx in torch_x:
		c.tex(m.tex_glow, Rect2(tx - 180 * k, floor_y + 50 * k - 70 * k, 360 * k, 140 * k), rgba(200, 100, 20, 0.18))
	MenuArt.torch(c, torch_x[0], torch_y, k, tick, 0)
	MenuArt.torch(c, torch_x[1], torch_y, k, tick, 2.4)
	# hősök: előbb mind a három fénye és árnyéka (textúrák), utána mind a három figura
	var spread := W * 0.22
	var feet_y := H * 0.88
	var m_size := minf(110 * k, H * 0.2)
	var k_size := minf(135 * k, H * 0.24)
	_hero_glow(m, c, W / 2 - spread, feet_y, "#c070f0", m_size, k)
	_hero_glow(m, c, W / 2 + spread, feet_y, "#70d860", m_size, k)
	_hero_glow(m, c, W / 2, feet_y, "#70c8e8", k_size, k)
	Sprites.hero_cached(c, "Mágus", W / 2 - spread, feet_y - m_size * 0.44, m_size, tick, m.skins)
	c.save(); c.translate(W / 2 + spread, 0); c.scale(-1, 1); c.translate(-(W / 2 + spread), 0)
	Sprites.hero_cached(c, "Íjász", W / 2 + spread, feet_y - m_size * 0.44, m_size, tick, m.skins)
	c.restore()
	Sprites.hero_cached(c, "Lovag", W / 2, feet_y - k_size * 0.44, k_size, tick, m.skins)
	# parázs (a véletlen, de állandó értékek egyszer kiszámolva)
	if _ember_rnd.is_empty():
		for i in 55:
			_ember_rnd.append([0.18 + Data.rnd_seed_m(i * 3.7) * 0.65, Data.rnd_seed_m(i * 1.31),
				Data.rnd_seed_m(i * 7.1), 0.7 + Data.rnd_seed_m(i * 5.5) * 2.2, 145 + Data.rnd_seed_m(i) * 85])
	for i in 55:
		var e: Array = _ember_rnd[i]
		var ex := fposmod(e[1] * W + sin(tick * 0.02 + i) * 26 * k + W, W)
		var ey := H - fposmod(tick * 0.85 * e[0] + e[2] * H, H * 1.03)
		var al := 0.08 + 0.4 * absf(sin(tick * 0.05 + i))
		c.fs(rgba(255, int(e[4]), 45, al * 0.8))
		c.circ(ex, ey, e[3] * k)
	# vignetta
	var vr := maxf(W, H) * 0.8
	c.tex(m.tex_vignette, Rect2(W / 2 - vr, H * 0.5 - vr, vr * 2, vr * 2))
	# címszalag
	var bw := minf(W * 0.88, 580 * k)
	var bh := minf(168 * k, H * 0.24)
	var bx := (W - bw) / 2
	var by := H * 0.042
	# a címszalag mozdulatlan része (árnyék, háttér, keret, felső dísz) kész hálóból
	var bkey := "banner|%d|%d|%d" % [int(roundf(bw)), int(roundf(bh)), int(roundf(k * 64.0))]
	c.blit(bkey, func() -> void:
		c.soft_shadow(0, 0, bw, bh, 12 * k, rgba(0, 0, 0, 0.88), 36 * k, 10 * k)
		var bg2 := Cv.linear(0, 0, 0, bh).stop(0, "#33250f").stop(0.5, "#231a0b").stop(1, "#150f06")
		c.fs(bg2); c.rrect(0, 0, bw, bh, 12 * k); c.fill()
		c.ss("#d4a84b"); c.lw(2.8 * k); c.rrect(0, 0, bw, bh, 12 * k); c.stroke()
		c.ss(rgba(212, 168, 75, 0.3)); c.lw(1.2 * k)
		c.rrect(8 * k, 8 * k, bw - 16 * k, bh - 16 * k, 9 * k); c.stroke()
		MenuArt.ornament(c, 26 * k, 22 * k, bw - 52 * k, "#8a6a2e", k), bx, by)
	var tt := _title_geo(m, bw, bh, by, k)
	var tsz: float = tt["tsz"]
	var ty: float = tt["ty"]
	var tot: float = tt["tot"]
	# a cím izzó árnyéka
	c.tex(m.tex_glow, Rect2(W / 2 - tot / 2 - 40 * k, ty - tsz * 1.05, tot + 80 * k, tsz * 1.45), rgba(255, 160, 35, 0.22))
	MenuArt.ls_text(c, "KARD ÉS MÁGIA", W / 2 + 1.5 * k, ty + 1.5 * k, "#1a1005", tsz, tsz * 0.055, "center")
	# keresztbe tett kardok a cím két oldalán (mozdulatlanok)
	var half_t := tot / 2
	var skey := "swords|%d" % int(roundf(tsz * 0.78 * 8.0))
	c.blit(skey, func() -> void: MenuArt.crossed_swords(c, 0, 0, tsz * 0.78, "#c8a03a"), W / 2 - half_t - 40 * k, ty - tsz * 0.28)
	c.blit(skey, func() -> void: MenuArt.crossed_swords(c, 0, 0, tsz * 0.78, "#c8a03a"), W / 2 + half_t + 40 * k, ty - tsz * 0.28)
	c.ftxt("ROGUELIKE KALAND  ·  5 MÉLYSÉG  ·  3 HŐS", W / 2, by + bh * 0.84, "#9c8354", minf(16 * k, tsz * 0.28), "center")
	c.blit("orna2|%d|%d" % [int(roundf(bw - 52 * k)), int(roundf(k * 64.0))],
		func() -> void: MenuArt.ornament(c, 0, 0, bw - 52 * k, "#6a5222", k), bx + 26 * k, by + bh - 20 * k)


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
	# gombok — sorrend: (Folytatás) · Kaland kezdete · Irányítás · Kilépés
	var btn_w := minf(300 * k, W - 56)
	var btns := [
		{"t": "⚔  Kaland kezdete", "c": P["parchGold"], "bg": "#2e2210", "bd": P["parchGold"], "fn": m.go_diff},
		{"t": "✦  Kinézet bolt", "c": "#c9a6ff", "bg": "#1d1430", "bd": "#6a4aa8", "fn": func() -> void: m.open_bolt("menu")},
		{"t": "Irányítás", "c": P["ink"], "bg": "#241a0c", "bd": P["parchEdge"], "fn": func() -> void: m.set_state("help")},
		{"t": "Kilépés", "c": "#c08070", "bg": "#1e1008", "bd": "#6a3a2a", "fn": m.quit_app},
	]
	if SaveGame.has_save():
		btns.push_front({"t": "▶  Folytatás", "c": "#9ce0a0", "bg": "#16280f", "bd": "#5aa050", "fn": m.continue_game})
	# a gomboszlop magassága állandó (a képernyő ~40%-a), akárhány gomb van: így sosem lóg ki
	var n := btns.size()
	var gap := 10 * k
	var btn_h := minf(54 * k, (H * 0.40) / n - gap)
	var tot_h := n * btn_h + (n - 1) * gap
	var btn_y := clampf(H * 0.72 - tot_h, H * 0.26, H * 0.50)
	for i in n:
		var bx2 := (W - btn_w) / 2
		var by2 := btn_y + i * (btn_h + gap)
		if i == 0:
			c.soft_shadow(bx2, by2, btn_w, btn_h, 8, rgba(212, 168, 75, 0.45), 18 * k)
		c.panel(bx2, by2, btn_w, btn_h, btns[i]["bg"], btns[i]["bd"], 2, 8)
		c.ftxt_fit(btns[i]["t"], W / 2, by2 + btn_h * 0.63, btns[i]["c"], minf(17 * k, 17), btn_w - 28, "center")
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
		["Láda · Szentély · Kereskedő", "Sétálj rá: tárgyat választasz, áldást kérsz vagy aranyért vásárolsz"],
		["Tab: térkép  ·  K: kutatás", "Bejárt mezők kis térképen; titkos ajtók és rejtett csapdák felfedése"],
		["Szintlépés", "Három lap közül választhatsz képességet (1 / 2 / 3 vagy kattintás)"],
		["Mentés · Hang · Képernyő", "Esc: menü és mentés  ·  M: hang ki/be  ·  F11: teljes képernyő"],
	]
	var bind_rows := [
		["up", "Fel / Mozgás ↑"], ["down", "Le / Mozgás ↓"], ["left", "Bal / Mozgás ←"], ["right", "Jobb / Mozgás →"],
		["stair", "Lépcső (lejjebb)"], ["inventory", "Táska"], ["menu", "Menü / Vissza"],
	]
	var gap := 34.0 if H >= 700 else 28.0
	var head := 68 + info.size() * gap + 5   # az elválasztó vonalig
	var pw := minf(520, W - 24)
	var ph := minf(head + 31 + 7 * 36 + 6 + 34 + 12 + 44 + 16, H - 24)
	var row_h := clampf((ph - (head + 31) - (6 + 34 + 12 + 44 + 16)) / 7.0, 26, 36)
	var ox := (W - pw) / 2
	var oy := maxf(12, (H - ph) / 2)
	c.panel(ox, oy, pw, ph, P["parch"], P["parchGold"], 2, 10)
	c.orna(ox + 16, oy + 18, pw - 32, P["parchEdge"])
	c.ftxt("Irányítás & Billentyűk", W / 2, oy + 42, P["parchGold"], 18, "center")
	c.orna(ox + 16, oy + 52, pw - 32, P["parchEdge"])
	# az ismertető sorai halvány háttérsávon: tagoltabb, kevésbé zsúfolt
	for i in info.size():
		if i % 2 == 0:
			c.rrect_fill_c(ox + 12, oy + 56 + i * gap, pw - 24, gap - 4, 4, "#1c1408")
	for i in info.size():
		var ly := oy + 68 + i * gap
		c.ftxt(info[i][0], ox + 22, ly, P["parchGold"], 12)
		c.ftxt_fit(info[i][1], ox + 22, ly + 15, P["ink"], 10, pw - 44)
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
		Sprites.hero_cached(c, name, bx + bw2 / 2, by + bh * 0.23, minf(110, bh * 0.3), m.tick, m.skins)
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
	c.ftxt("Felszerelés & Táska", W / 2, oy + 30, P["parchGold"], 19, "center")
	c.orna(ox + 18, oy + 40, pw - 36, P["parchEdge"])
	# a hős képe a MOSTANI kinézettel (a boltban vett darabokkal együtt)
	var hb := 86.0
	c.rrect_fill_c(ox + 12, oy + 48, hb, hb, 6, "#1b1308")
	c.rrect_stroke_c(ox + 12, oy + 48, hb, hb, 6, 1.0, "#3d2e14")
	Sprites.hero_cached(c, p.cls, ox + 12 + hb / 2, oy + 48 + hb / 2 + hb * 0.06, hb * 0.66, tick, m.skins)
	# felszerelt tárgyak: fegyver, páncél, pajzs
	var rx0 := ox + 12 + hb + 10
	var rw0 := ox + pw - 12 - rx0
	var slots := [["⚔", p.weapon, "Nincs fegyver (puszta kéz)"], ["🛡", p.armor, "Nincs páncél"], ["⛨", p.shield, "Nincs pajzs"]]
	# Kötegbarát sorrend: előbb minden háttér, aztán minden ikon, végül minden felirat.
	# (A sorok nem érnek egymásba, így a kép ugyanaz, de sokkal kevesebb rajzhívás kell.)
	for i in 3:
		c.rrect_fill_c(rx0, oy + 50 + i * 28, rw0, 24, 4, "#1e1508")
	for i in 3:
		var it: Item = slots[i][1]
		if it:
			Sprites.item_glow(c, it, rx0 + 15, oy + 50 + i * 28 + 12, 19, tick)
	for i in 3:
		var it: Item = slots[i][1]
		if it:
			Sprites.item_shape(c, it, rx0 + 15, oy + 50 + i * 28 + 12, 19, tick)
	for i in 3:
		var sy := oy + 50 + i * 28
		var it: Item = slots[i][1]
		if it:
			var stats := it.short_stats(p.cls, p.mag)
			var sw := minf(Cv.measure(stats, 10), rw0 * 0.44)
			c.ftxt_fit(stats, rx0 + rw0 - 10, sy + 16, P["parchGold"], 10, sw, "right")
			c.ftxt_fit("%s %s" % [slots[i][0], it.label], rx0 + 30, sy + 16, it.border(), 11, rw0 - 44 - sw)
		else:
			c.ftxt_fit("%s %s" % [slots[i][0], slots[i][2]], rx0 + 30, sy + 16, P["inkDark"], 11, rw0 - 40)
	c.orna(ox + 18, oy + 134, pw - 36, "#241a0c")
	# arany és a megszerzett képességek
	c.ftxt("◉ %d" % p.gold, ox + 14, oy + 152, P["parchGold"], 12)
	var pl := Perks.labels(p)
	var gw := maxf(60.0, Cv.measure("◉ %d" % p.gold, 12) + 14)
	var ptxt := "Képességek: " + ("  ·  ".join(pl) if not pl.is_empty() else "még nincs — szintlépéskor választhatsz")
	c.ftxt_fit(ptxt, ox + 14 + gw, oy + 152, P["ink"] if not pl.is_empty() else P["inkDark"], 10, pw - 32 - gw)
	c.orna(ox + 18, oy + 162, pw - 36, "#241a0c")
	var items := p.inventory
	var list_y := oy + 172
	var row_h := 44.0
	var foot := 86.0
	var max_show := maxi(1, int((ph - (list_y - oy) - foot) / row_h))
	var max_scroll := maxi(0, items.size() - max_show)
	m.inv_scroll = clampi(m.inv_scroll, 0, max_scroll)
	var off: int = m.inv_scroll
	if items.is_empty():
		c.ftxt("Üres a táskád.", W / 2, list_y + 30, P["inkDark"], 13, "center")
	var shown := mini(items.size() - off, max_show)
	# 1. minden sor kerete (egyetlen kötegbe)
	for r in shown:
		var it: Item = items[off + r]
		var iy := list_y + r * row_h
		c.rrect_fill_c(ox + 10, iy, pw - 20, row_h - 6, 5, "#221808")
		c.rrect_stroke_c(ox + 10, iy, pw - 20, row_h - 6, 5, 1.5, it.border())
	# 2. minden ragyogás, majd minden ikon-alak
	for r in shown:
		Sprites.item_glow(c, items[off + r], ox + 30, list_y + r * row_h + (row_h - 6) / 2, row_h * 0.62, tick)
	for r in shown:
		Sprites.item_shape(c, items[off + r], ox + 30, list_y + r * row_h + (row_h - 6) / 2, row_h * 0.62, tick)
	# 3. minden felirat
	for r in shown:
		var idx := off + r
		var it: Item = items[idx]
		var iy := list_y + r * row_h
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
	var card_h := maxf(200.0, 132.0 + nmax * 17 + 16)
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
		c.rrect_fill_c(ix + iw / 2 - 34, iy2 + 12, 68, 68, 12, Color(gcol, 0.12))
		Sprites.item_icon(c, it, ix + iw / 2, iy2 + 46, 54, tick)
		c.ftxt_fit(it.label, ix + iw / 2, iy2 + 94, it.glow(), 13, iw - 16, "center")
		c.ftxt("[%s]" % it.rar()["label"], ix + iw / 2, iy2 + 109, it.border(), 10, "center")
		c.orna(ix + iw * 0.22, iy2 + 116, iw * 0.56, P["parchEdge"])
		var stats := it.stat_lines(p.cls, p.mag)
		for j in stats.size():
			c.ftxt_fit(stats[j], ix + iw / 2, iy2 + 132 + j * 17, P["ink"], 11, iw - 16, "center")
		m.add_hit(ix, iy2, iw, card_h, func() -> void:
			m.chest_ui["sel"] = i
			m.pick_chest_item())
	c.ftxt("Kattints a tárgyra, vagy ←/→ és Enter  ·  Esc: később", W / 2, oy + ph - 12, P["inkDark"], 10, "center")


# ══════════ SZINTLÉPÉS: KÉPESSÉGVÁLASZTÓ ══════════
static func perk_pick(m: Node, c: Cv) -> void:
	if m.perk_ui == null:
		return
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var p: Player = m.game.player
	var ids: Array = m.perk_ui["ids"]
	var sel: int = m.perk_ui["sel"]
	var n := maxi(1, ids.size())
	c.fs(rgba(0, 0, 0, 0.9)); c.fill_rect(0, 0, W, H)
	var pw := minf(700, W - 24)
	var card_h := minf(228.0, H - 190)
	var ph := 96 + card_h + 44
	var ox := (W - pw) / 2
	var oy := maxf(12, (H - ph) / 2)
	c.panel(ox, oy, pw, ph, P["parch"], P["parchGold"], 2, 10)
	c.ftxt("⬆ %d. szint — válassz képességet!" % p.plvl, W / 2, oy + 34, P["parchGold"], 18, "center")
	c.orna(ox + 16, oy + 46, pw - 32, P["parchEdge"])
	c.ftxt("A képességek összeadódnak, és a táskádban végig láthatók.", W / 2, oy + 68, P["inkDark"], 10, "center")
	var cw := (pw - 24 - (n - 1) * 12) / n
	for i in ids.size():
		var id: String = ids[i]
		var d := Perks.info(id)
		var cx := ox + 12 + i * (cw + 12)
		var cy := oy + 84
		var have: int = p.perk(id)
		var bd: String = d["col"]
		if i == sel:
			c.soft_shadow(cx, cy, cw, card_h, 8, Color(Cv.col(bd), 0.45), 14)
		c.panel(cx, cy, cw, card_h, "#1e1408", bd, 3.0 if i == sel else 1.6, 8)
		# jelvénymező az ikonnak: tisztább rangsor (ikon → név → leírás → lábjegyzet)
		c.rrect_fill_c(cx + cw / 2 - 24, cy + 16, 48, 48, 10, Color(Cv.col(bd), 0.16))
		c.ftxt(d["ic"], cx + cw / 2, cy + 51, bd, 28, "center")
		c.ftxt_fit(d["n"], cx + cw / 2, cy + 88, P["parchGold"], 15, cw - 16, "center")
		c.orna(cx + cw * 0.28, cy + 99, cw * 0.44, P["parchEdge"])
		var nsor := Cv.wrap_lines(d["d"], cw - 26, 11).size()
		c.wrap_text(d["d"], cx + cw / 2, cy + maxf(120.0, (card_h - 34 + 108 - nsor * 16) / 2.0), cw - 26, 11, P["ink"], "center")
		var foot := "Jelenleg: ×%d  (max %d)" % [have, int(d["max"])] if have > 0 else "Új képesség  (max %d)" % int(d["max"])
		c.ftxt_fit(foot, cx + cw / 2, cy + card_h - 30, P["inkDark"], 10, cw - 16, "center")
		c.ftxt("[%d]" % (i + 1), cx + cw / 2, cy + card_h - 12, bd, 12, "center")
		m.add_hit(cx, cy, cw, card_h, func() -> void: m.pick_perk(i))
	c.ftxt("Kattints egy lapra, vagy 1 / 2 / 3  ·  ←/→ és Enter", W / 2, oy + ph - 14, P["inkDark"], 10, "center")


# ══════════ KERESKEDŐ ══════════
static func shop(m: Node, c: Cv) -> void:
	if m.shop_ui == null:
		return
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var p: Player = m.game.player
	var tick: float = m.tick
	var stock: Array = m.shop_ui["shop"]["stock"]
	var n := maxi(1, stock.size())
	c.fs(rgba(0, 0, 0, 0.9)); c.fill_rect(0, 0, W, H)
	var pw := minf(660, W - 24)
	var card_h := minf(232.0, H - 190)
	var ph := 96 + card_h + 44
	var ox := (W - pw) / 2
	var oy := maxf(12, (H - ph) / 2)
	c.panel(ox, oy, pw, ph, P["parch"], "#60d080", 2, 10)
	c.ftxt("◉ Vándorkereskedő", W / 2, oy + 34, "#9ce0a0", 18, "center")
	c.orna(ox + 16, oy + 46, pw - 32, P["parchEdge"])
	c.ftxt("Aranyad: ◉ %d" % p.gold, W / 2, oy + 70, P["parchGold"], 13, "center")
	var cw := (pw - 24 - (n - 1) * 12) / n
	for i in stock.size():
		var e: Dictionary = stock[i]
		var it: Item = e["item"]
		var sold: bool = e["sold"]
		var price := int(e["price"])
		var afford: bool = p.gold >= price and not sold
		var bd: String = (it.border() if it != null else "#40c860") if not sold else "#4a4038"
		var cx := ox + 12 + i * (cw + 12)
		var cy := oy + 84
		c.panel(cx, cy, cw, card_h, "#1e1408", bd, 2.0, 8)
		if it != null:
			if not sold:
				Sprites.item_icon(c, it, cx + cw / 2, cy + 48, 50, tick)
			c.ftxt_fit(it.label, cx + cw / 2, cy + 92, it.glow() if not sold else P["inkDark"], 12, cw - 16, "center")
			var lines := it.stat_lines(p.cls, p.mag)
			for j in mini(lines.size(), 4):
				c.ftxt_fit(lines[j], cx + cw / 2, cy + 112 + j * 16, P["ink"], 10, cw - 16, "center")
		else:
			c.ftxt("✚", cx + cw / 2, cy + 60, "#40c860", 34, "center")
			c.ftxt_fit("Teljes gyógyulás", cx + cw / 2, cy + 92, "#9ce0a0", 12, cw - 16, "center")
			c.ftxt_fit("Az életerőd feltöltődik.", cx + cw / 2, cy + 112, P["ink"], 10, cw - 16, "center")
		var lbl := "ELFOGYOTT" if sold else ("◉ %d arany" % price)
		c.ftxt(lbl, cx + cw / 2, cy + card_h - 30, (P["parchGold"] if afford else P["inkDark"]) if not sold else "#7a6a58", 14, "center")
		if not sold and not afford:
			c.ftxt("nincs elég aranyad", cx + cw / 2, cy + card_h - 14, "#a05050", 9, "center")
		else:
			c.ftxt("[%d]" % (i + 1), cx + cw / 2, cy + card_h - 14, bd, 11, "center")
		m.add_hit(cx, cy, cw, card_h, func() -> void: m.buy_shop(i))
	c.ftxt("Kattints egy lapra, vagy 1 / 2 / 3  ·  Esc: továbbállsz", W / 2, oy + ph - 14, P["inkDark"], 10, "center")


# ══════════ KINÉZET BOLT (kozmetika — csak a külsőt változtatja) ══════════
## Bal oldalt a hős előnézete a mostani összeállítással, jobb oldalt a négy hely változatai.
## Minden méret a képernyőből számolódik, így 1280×800-on és 1024×768-on sem lóg ki semmi.
static func bolt(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var f: Fiok = m.fiok
	var ck: String = m.bolt_kaszt()
	var cls: String = Skins.KEY_CLS[ck]
	var sel_slot := clampi(int(m.bolt_ui["slot"]), 0, Skins.SLOTS.size() - 1)
	var sel_opt := int(m.bolt_ui["opt"])
	var valasztott: Dictionary = Skins.valasztas(m.skins, cls)
	c.fs("#0a0708"); c.fill_rect(0, 0, W, H)
	var mar := 14.0
	var hh := 52.0
	var top := 12.0 + hh + 10.0
	var boty := H - 34.0
	# ── fejléc ──
	c.panel_c(mar, 12, W - mar * 2, hh, "#1a1224", "#5c4488", 1.5, 8)
	var bw0 := 92.0
	c.panel(mar + 10, 20, bw0, hh - 16, "#241a0c", P["parchEdge"], 1.5, 6)
	c.ftxt("← Vissza", mar + 10 + bw0 / 2, 20 + (hh - 16) * 0.66, P["ink"], 11, "center")
	m.add_hit(mar + 10, 20, bw0, hh - 16, m.close_bolt)
	c.ftxt_fit("✦ Kinézet bolt", mar + 118, 12 + hh * 0.62, "#c9a6ff", 19, W * 0.26)
	var ebw := 148.0
	var ebx := W - mar - 58 - ebw   # a hang gomb helyét szabadon hagyva
	var eby := 20.0
	c.panel(ebx, eby, ebw, hh - 16, "#2e2210", P["parchGold"], 2, 6)
	c.ftxt("◉ Érmét veszek", ebx + ebw / 2, eby + (hh - 16) * 0.66, P["parchGold"], 12, "center")
	m.add_hit(ebx, eby, ebw, hh - 16, func() -> void: m.bolt_ui["erme"] = true)
	if f != null and f.betoltve:
		var et := ("◉ %d érme" % f.erme) if f.erme_ismert else "◉ … érme"
		c.ftxt_fit(et, ebx - 16, 12 + hh * 0.60, P["parchGold"], 16, W * 0.22, "right")
	else:
		c.ftxt_fit("Jelentkezz be a ParthLauncherben", ebx - 16, 12 + hh * 0.60, "#e0a030", 12, W * 0.34, "right")
	# ── bal oldal: a hős előnézete ──
	var lw := clampf(W * 0.28, 224.0, 330.0)
	var lh := boty - top
	c.panel_c(mar, top, lw, lh, "#140f10", "#3d3348", 1.5, 8)
	var tabw := (lw - 20 - 12) / 3.0
	for i in 3:
		var tx := mar + 10 + i * (tabw + 6)
		var on: bool = i == int(m.bolt_ui["cls"])
		var nm: String = Data.CLASS_ORDER[i]
		c.panel(tx, top + 10, tabw, 28, "#2e2210" if on else "#1a1408", Data.CLASSES[nm]["col"] if on else P["parchEdge"], 2 if on else 1, 5)
		c.ftxt_fit(nm, tx + tabw / 2, top + 29, P["parchGold"] if on else P["inkDark"], 12, tabw - 8, "center")
		m.add_hit(tx, top + 10, tabw, 28, func() -> void:
			m.bolt_ui["cls"] = i
			m.bolt_ui["slot"] = 0
			m.bolt_ui["opt"] = 0)
	# összefoglaló a négy helyről (alul), a maradék a figuráé
	var sum_h := 4.0 * 17.0 + 12.0
	var view_y := top + 46
	var view_h := lh - 46 - sum_h - 10
	var hs := minf(lw * 0.86, view_h / 1.30)
	var gcol: Color = Cv.col(Data.CLASSES[cls]["col"])
	gcol.a = 0.16
	c.tex(m.tex_glow, Rect2(mar + lw / 2 - hs * 0.8, view_y + view_h / 2 - hs * 0.8, hs * 1.6, hs * 1.6), gcol)
	Sprites.hero_cached(c, cls, mar + lw / 2, view_y + view_h / 2 + hs * 0.10, hs, m.tick, m.skins)
	c.orna(mar + 14, view_y + view_h + 4, lw - 28, "#3d3348")
	for i in Skins.SLOTS.size():
		var sl: String = Skins.SLOTS[i]
		var vv := str(valasztott.get(sl, ""))
		c.ftxt(Skins.SLOT_NEV[sl], mar + 16, view_y + view_h + 22 + i * 17, P["inkDark"], 10)
		c.ftxt_fit(Skins.nev(ck, sl, vv), mar + lw - 16, view_y + view_h + 22 + i * 17,
			P["parchGold"] if vv != "" else P["ink"], 10, lw - 84, "right")
	# ── jobb oldal: a négy hely változatai ──
	var rx := mar + lw + 12
	var rw := W - rx - mar
	var rgap := 8.0
	var row_h := (lh - rgap * 3) / 4.0
	for si in Skins.SLOTS.size():
		var slot: String = Skins.SLOTS[si]
		var ry := top + si * (row_h + rgap)
		var akt: bool = si == sel_slot
		c.panel_c(rx, ry, rw, row_h, "#151016" if not akt else "#1c1526", "#4a3f5c" if akt else "#302a38", 2 if akt else 1, 8)
		c.ftxt("%s  ·  %d érme" % [Skins.SLOT_NEV[slot], Skins.ar(slot)], rx + 12, ry + 19, P["parchGold"] if akt else P["inkDark"], 12)
		var opts: Array = m.bolt_opciok(ck, slot)
		var cnt := opts.size()
		var cgap := 7.0
		var cw := (rw - 20 - cgap * (cnt - 1)) / cnt
		var chh := row_h - 34
		var cy := ry + 27
		for oi in cnt:
			var v := str(opts[oi])
			var kulcs := Skins.kulcs(ck, slot, v)
			var megvan: bool = v == "" or (f != null and f.birtokol(kulcs))
			var felveve: bool = str(valasztott.get(slot, "")) == v
			var cx := rx + 10 + oi * (cw + cgap)
			var kivalasztott: bool = akt and oi == (sel_opt % maxi(1, cnt))
			var bd: String = "#7fe08a" if felveve else ("#8a72c8" if megvan else "#6a5a44")
			if kivalasztott:
				c.soft_shadow(cx, cy, cw, chh, 7, Color(Cv.col(bd), 0.40), 12)
			c.panel(cx, cy, cw, chh, "#241d16" if not felveve else "#16240f", bd, 2.5 if kivalasztott else 1.4, 7)
			Skins.resz_ikon(c, ck, slot, v, cx + cw / 2, cy + chh * 0.36, minf(cw * 0.62, chh * 0.62))
			c.ftxt_fit(Skins.nev(ck, slot, v), cx + cw / 2, cy + chh - 24, P["ink"] if not felveve else "#bff0b8", 11, cw - 10, "center")
			var lbl := ""
			var lc: Variant = P["inkDark"]
			if felveve:
				lbl = "✓ felveve"
				lc = "#7fe08a"
			elif megvan:
				lbl = "Felvesz"
				lc = P["parchGold"]
			else:
				lbl = "Megvásárlás (%d érme)" % Skins.ar(slot)
				lc = P["parchGold"] if (f != null and f.betoltve and f.erme >= Skins.ar(slot)) else "#a07850"
			c.ftxt_fit(lbl, cx + cw / 2, cy + chh - 8, lc, 10, cw - 8, "center")
			m.add_hit(cx, cy, cw, chh, func() -> void: m.bolt_valaszt(ck, slot, v))
	# ── üzenet / lábjegyzet ──
	var hint := "↑↓ hely  ·  ←→ darab  ·  Enter: felvesz / megvásárol  ·  Tab: másik hős  ·  Esc: vissza"
	if f != null and f.uzenet != "":
		c.ftxt_fit(f.uzenet, W / 2, H - 14, "#e08060" if f.uzenet_hiba else "#9ce0a0", 11, W - 40, "center")
	else:
		c.ftxt_fit(hint, W / 2, H - 14, P["inkDark"], 10, W - 40, "center")
	if bool(m.bolt_ui["erme"]):
		_erme_panel(m, c)


## „Érmét veszek”: a három Gumroad-csomag (a böngészőben nyílik meg)
static func _erme_panel(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	c.fs(rgba(0, 0, 0, 0.78)); c.fill_rect(0, 0, W, H)
	var pw := minf(420, W - 40)
	var ph := minf(300, H - 40)
	var ox := (W - pw) / 2
	var oy := (H - ph) / 2
	c.panel(ox, oy, pw, ph, P["parch"], P["parchGold"], 2, 10)
	c.ftxt("◉ Érmét veszek", W / 2, oy + 38, P["parchGold"], 18, "center")
	c.orna(ox + 20, oy + 50, pw - 40, P["parchEdge"])
	c.ftxt_fit("A vásárlás a böngészőben, a Gumroadon történik.", W / 2, oy + 72, P["inkDark"], 10, pw - 32, "center")
	var bh := 48.0
	for i in Fiok.GUMROAD.size():
		var e: Dictionary = Fiok.GUMROAD[i]
		var by := oy + 86 + i * (bh + 10)
		c.panel(ox + 20, by, pw - 40, bh, "#2e2210", P["parchGold"], 1.8, 7)
		c.ftxt("◉ %d érme" % int(e["erme"]), ox + 38, by + bh * 0.62, P["parchGold"], 14)
		c.ftxt("%s   [%d]" % [str(e["ar"]), i + 1], ox + pw - 38, by + bh * 0.62, P["ink"], 13, "right")
		m.add_hit(ox + 20, by, pw - 40, bh, func() -> void: Fiok.bolt_megnyit(i))
	c.ftxt("Esc / Enter: bezárás", W / 2, oy + ph - 14, P["inkDark"], 10, "center")
	m.add_hit(ox, oy, pw, 34, func() -> void: m.bolt_ui["erme"] = false)


# ══════════ JÁTÉK KÖZBENI MENÜ (Esc) ══════════
static func pause(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	c.fs(rgba(0, 0, 0, 0.85)); c.fill_rect(0, 0, W, H)
	var pw := minf(380, W - 24)
	var items := [
		["▶  Vissza a játékhoz", P["parchGold"], "#2e2210", m.close_pause],
		["✦  Kinézet bolt", "#c9a6ff", "#1d1430", func() -> void: m.open_bolt("pause")],
		["💾  Mentés és kilépés", "#9ce0a0", "#16280f", m.save_and_menu],
		["☠  Feladás (mentés törlése)", "#d08070", "#2a1008", m.abandon_run],
	]
	var bh := 50.0
	var ph := minf(74 + items.size() * (bh + 12) + 30, H - 24)
	var ox := (W - pw) / 2
	var oy := maxf(12, (H - ph) / 2)
	c.panel(ox, oy, pw, ph, P["parch"], P["parchGold"], 2, 10)
	c.ftxt("Szünet", W / 2, oy + 40, P["parchGold"], 20, "center")
	c.orna(ox + 20, oy + 52, pw - 40, P["parchEdge"])
	var bw := pw - 40
	for i in items.size():
		var by := oy + 74 + i * (bh + 12)
		var sel: bool = m.pause_sel == i
		c.panel(ox + 20, by, bw, bh, items[i][2], items[i][1] if sel else P["parchEdge"], 2.5 if sel else 1.5, 8)
		c.ftxt_fit("%s  [%d]" % [items[i][0], i + 1], W / 2, by + bh * 0.63, items[i][1], 14, bw - 24, "center")
		m.add_hit(ox + 20, by, bw, bh, items[i][3])
	c.ftxt("A szintváltás magától ment  ·  Esc: vissza", W / 2, oy + ph - 14, P["inkDark"], 10, "center")


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
