class_name StoryUI
extends RefCounted
## A történet képernyői: bevezető és befejezés (mozgó képsorok), párbeszéd a pálya fölött,
## megtalált feljegyzés, a Napló, és a Műtőterem (Nora és a Megnyúzott Próféta).

const TYPE_MS := 22.0     # egy betű ennyi idő alatt íródik ki
const SLIDE_MS := 9000.0  # egy képsor mozgásának hossza (a kép ennyi idő alatt úszik végig)

static var _art_cache := {}


static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Cv.rgba(r, g, b, a)


## Festett háttérkép (res://art/<név>.jpg), ha van; különben null, és a rajzolt változat látszik.
static func art_tex(art: String) -> Texture2D:
	if _art_cache.has(art):
		return _art_cache[art]
	var t: Texture2D = null
	var ut := "res://art/%s.jpg" % art
	if ResourceLoader.exists(ut):
		t = load(ut) as Texture2D
	_art_cache[art] = t
	return t


## Egy háttérkép kirakása lassú közelítéssel és úsztatással (a kép sosem áll).
## u: 0..1, a képsor előrehaladása; irany: melyik felé úszik.
static func art(c: Cv, name: String, x: float, y: float, w: float, h: float, tick: float, u: float, irany := 0) -> void:
	var t := art_tex(name)
	if t == null:
		Sprites2.scene(c, name, x, y, w, h, tick)
		return
	var ts := t.get_size()
	var zoom := 1.06 + 0.10 * u
	# a kép kitölti a keretet (levágva), és a nagyítás tartalékában úszik
	var sc := maxf(w / ts.x, h / ts.y) * zoom
	var vw := w / sc
	var vh := h / sc
	var fx := (ts.x - vw) * (0.5 + (0.5 - u) * 0.8 * (1.0 if irany % 2 == 0 else -1.0) * 0.5)
	var fy := (ts.y - vh) * (0.5 + (u - 0.5) * 0.6 * (1.0 if irany % 3 == 0 else -1.0) * 0.5)
	c.tex_region(t, Rect2(x, y, w, h), Rect2(clampf(fx, 0, ts.x - vw), clampf(fy, 0, ts.y - vh), vw, vh))
	# a festmény fölé élő réteg: felszálló gőz és parázs
	for i in 26:
		var s1 := Data.rnd_seed(i * 1.9 + 0.3)
		var s2 := Data.rnd_seed(i * 3.1 + 1.7)
		var uu := fmod(s2 + tick * (0.0012 + s1 * 0.0016), 1.0)
		var px := x + s1 * w + sin(uu * 6.0 + i) * 40
		var py := y + h * (1.05 - uu * 1.1)
		if i % 3 == 0:
			c.fs(rgba(255, 200, 110, 0.7 * sin(uu * PI))); c.circ(px, py, 1.6 + s1 * 1.6)
		else:
			c.fs(rgba(235, 235, 215, 0.05 * sin(uu * PI))); c.circ(px, py, 20 + uu * 60)


# ══════════ BEVEZETŐ / BEFEJEZÉS ══════════
static func cine(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var ci: Dictionary = m.cine_ui
	var slides: Array = ci["slides"]
	var i := clampi(int(ci["i"]), 0, slides.size() - 1)
	var sl: Dictionary = slides[i]
	var el: float = m.now_ms() - float(ci["t0"])
	c.fs("#050403"); c.fill_rect(0, 0, W, H)
	var th := clampf(H * 0.26, 170.0, 230.0)
	var ah := H - th
	art(c, str(sl["art"]), 0, 0, W, ah, m.tick, clampf(el / SLIDE_MS, 0.0, 1.0), i)
	# szélesvásznú keret + puha átmenet a szövegsáv felé
	c.fs("#050403"); c.fill_rect(0, 0, W, 26)
	var g := Cv.linear(0, ah - 120, 0, ah)
	g.stop(0.0, rgba(5, 4, 3, 0.0)).stop(1.0, rgba(5, 4, 3, 1.0))
	c.fs(g); c.fill_rect(0, ah - 120, W, 120)
	# beúszás feketéből minden képsor elején
	if el < 700.0:
		c.fs(rgba(5, 4, 3, 1.0 - el / 700.0)); c.fill_rect(0, 0, W, ah)
	# szöveg: betűnként íródik ki
	var txt := Lang.T(str(sl["k"]))
	var narr: bool = sl.get("narr", false)
	var shown := mini(txt.length(), int(maxf(0.0, el - 500.0) / TYPE_MS))
	var tw := minf(900.0, W - 80)
	var sz := 19.0 if narr else 17.0
	var lines := Cv.wrap_lines(txt, tw, sz)
	var ty := ah + maxf(22.0, (th - 46 - lines.size() * (sz + 8)) / 2.0) + sz
	var left := shown
	if narr:
		c.fs(P["parchGold"]); c.fill_rect((W - tw) / 2 - 18, ty - sz, 3, lines.size() * (sz + 8) - 4)
	for l in lines:
		if left <= 0:
			break
		var part := l.substr(0, left)
		c.ftxt(part, (W - tw) / 2, ty, "#f0dca8" if narr else P["ink"], sz)
		left -= l.length() + 1
		ty += sz + 8
	# lapjelző pontok + súgó
	for j in slides.size():
		c.fs(P["parchGold"] if j == i else "#4a3a20"); c.circ(W / 2 + (j - (slides.size() - 1) / 2.0) * 16, H - 34, 4.0 if j == i else 3.0)
	c.ftxt_fit(Lang.T("cine.hint"), W / 2, H - 12, P["inkDark"], 11, W - 60, "center")
	m.add_hit(0, 0, W, H, m.cine_next)


## kiírta-e már a teljes szöveget (Enter előbb ezt fejezi be, csak utána lapoz)
static func cine_done(m: Node) -> bool:
	var ci: Dictionary = m.cine_ui
	var sl: Dictionary = (ci["slides"] as Array)[int(ci["i"])]
	return (m.now_ms() - float(ci["t0"]) - 500.0) / TYPE_MS >= Lang.T(str(sl["k"])).length()


# ══════════ PÁRBESZÉD (a pálya fölött) ══════════
static func portrait(m: Node, c: Cv, who: String, cx: float, cy: float, sz: float) -> void:
	match who:
		"vane": Sprites.hero_cached(c, m.game.player.cls if m.game.player else "Lovag", cx, cy, sz, m.tick, m.skins)
		"nora": Sprites2.nora(c, cx, cy, sz, m.tick)
		"profeta": Sprites2.prophet(c, cx, cy, sz, m.tick)
		_: Sprites.monster(c, who, cx, cy, sz * 0.62, m.tick, 0.0, false)


static func who_name(who: String) -> String:
	match who:
		"vane": return Lang.T("who.vane")
		"nora": return Lang.T("npc.nora")
		"profeta": return Lang.T("npc.profeta")
	return Lang.T("mon." + who)


static func dialog(m: Node, c: Cv) -> void:
	if m.dialog_ui == null:
		return
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var lines: Array = m.dialog_ui["lines"]
	var i := clampi(int(m.dialog_ui["i"]), 0, lines.size() - 1)
	var who := str(lines[i][0])
	var txt := Lang.T(str(lines[i][1]))
	var el: float = m.now_ms() - float(m.dialog_ui["t0"])
	var hero := who == "vane"
	var col: String = m.game.player.col if hero else str(Story.zone(m.game.world.dungeon_level)["acc"])
	c.fs(rgba(0, 0, 0, 0.45)); c.fill_rect(0, 0, W, H)
	var pw := minf(860.0, W - 40)
	var ph := 170.0
	var ox := (W - pw) / 2
	var oy := H - Data.HUD_H - ph - 26
	c.soft_shadow(ox, oy, pw, ph, 12, Color(Cv.col(col), 0.5), 22)
	c.panel(ox, oy, pw, ph, "#14100a", col, 2.5, 12)
	# arckép: a hős balra, a szörny jobbra
	var pr := 62.0
	var pcx := (ox + 22 + pr) if hero else (ox + pw - 22 - pr)
	var pcy := oy + ph / 2
	c.fs("#0a0806"); c.circ(pcx, pcy, pr)
	c.fs(Color(Cv.col(col), 0.16)); c.circ(pcx, pcy, pr - 2)
	portrait(m, c, who, pcx, pcy + 4, pr * 1.3)
	c.ss(col); c.lw(2.5); c.bp(); c.arc(pcx, pcy, pr, 0, 7); c.stroke()
	var tx := (ox + 2 * pr + 44) if hero else (ox + 28)
	var tw := pw - 2 * pr - 76
	c.ftxt_fit(who_name(who), tx, oy + 36, col, 18, tw)
	c.orna(tx, oy + 48, minf(220.0, tw), P["parchEdge"])
	var shown := mini(txt.length(), int(el / TYPE_MS))
	var ty := oy + 76
	var left := shown
	for l in Cv.wrap_lines(txt, tw, 15):
		if left <= 0:
			break
		c.ftxt(l.substr(0, left), tx, ty, "#f0e4c8", 15)
		left -= l.length() + 1
		ty += 23
	if shown >= txt.length() and int(m.tick * 0.08) % 2 == 0:
		c.ftxt("▼", ox + pw - 26 if hero else ox + pw - 2 * pr - 66, oy + ph - 16, col, 14, "center")
	c.ftxt_fit(Lang.T("dlg.hint"), W / 2, oy + ph + 18, P["ink"], 11, pw, "center")
	m.add_hit(0, 0, W, H, m.dialog_next)


static func dialog_done(m: Node) -> bool:
	var lines: Array = m.dialog_ui["lines"]
	var txt := Lang.T(str(lines[int(m.dialog_ui["i"])][1]))
	return (m.now_ms() - float(m.dialog_ui["t0"])) / TYPE_MS >= txt.length()


# ══════════ MEGTALÁLT FELJEGYZÉS ══════════
static func _note_page(c: Cv, x: float, y: float, w: float, h: float, id: String, tick: float) -> void:
	var P := Data.P
	c.soft_shadow(x, y, w, h, 6, rgba(0, 0, 0, 0.8), 26, 6)
	c.fs("#e8dcb8"); c.rrect(x, y, w, h, 5); c.fill()
	c.fs("#d8c89c"); c.fill_rect(x, y + h - 26, w, 26)
	c.fs(rgba(120, 80, 30, 0.10)); c.ell(x + w * 0.8, y + h * 0.25, w * 0.16, h * 0.10, 0.4)
	c.fs(rgba(120, 30, 30, 0.14)); c.ell(x + w * 0.16, y + h * 0.82, w * 0.07, h * 0.04, -0.3)
	c.fs(Sprites2.REZ); c.fill_rect(x + w / 2 - 22, y - 7, 44, 16)
	var z := Story.zone(Story.note_zone(id))
	c.ftxt_fit(Lang.T("zone." + str(z["id"])).to_upper(), x + w / 2, y + 36, "#8a6a3a", 11, w - 60, "center")
	c.ftxt_fit(Lang.T("note." + id), x + w / 2, y + 64, "#3a2410", 20, w - 50, "center")
	c.ss("#8a6a3a"); c.lw(1); c.line(x + 40, y + 78, x + w - 40, y + 78)
	c.wrap_text(Lang.T("note." + id + ".d"), x + 36, y + 110, w - 72, 15, "#3a2a18")
	if tick < 0:
		return
	c.ftxt_fit(Lang.T("note.hint"), x + w / 2, y + h - 9, "#6a5230", 11, w - 30, "center")


static func note(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	c.fs(rgba(0, 0, 0, 0.82)); c.fill_rect(0, 0, W, H)
	var pw := minf(560.0, W - 40)
	var ph := minf(420.0, H - 60)
	c.ftxt_fit(Lang.T("note.found"), W / 2, (H - ph) / 2 - 18, Data.P["parchGold"], 15, pw, "center")
	_note_page(c, (W - pw) / 2, (H - ph) / 2, pw, ph, str(m.note_ui), m.tick)
	m.add_hit(0, 0, W, H, m.close_note)


# ══════════ NAPLÓ ══════════
static func journal(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	c.fs("#080604"); c.fill_rect(0, 0, W, H)
	art(c, "lombik", 0, 0, W, H, m.tick, 0.5)
	c.fs(rgba(6, 5, 4, 0.86)); c.fill_rect(0, 0, W, H)
	var found: Array = Meta.data()["notes"]
	c.ftxt(Lang.T("journal.title"), W / 2, 50, P["parchGold"], 26, "center")
	c.ftxt_fit(Lang.T("journal.count", found.size(), Story.NOTE_ORDER.size()), W / 2, 74, P["inkDark"], 12, W - 40, "center")
	var tot := minf(1040.0, W - 40)
	var lw := minf(330.0, tot * 0.36)
	var ox := (W - tot) / 2
	var oy := 96.0
	var rh := minf(50.0, (H - oy - 86) / Story.NOTE_ORDER.size())
	for i in Story.NOTE_ORDER.size():
		var id: String = Story.NOTE_ORDER[i]
		var have := id in found
		var sel: bool = m.journal_sel == i
		var z := Story.zone(Story.note_zone(id))
		var ry := oy + i * rh
		c.panel(ox, ry, lw, rh - 6, "#2e2210" if sel else "#16100a", (str(z["acc"]) if have else P["parchEdge"]) if sel else "#3a2c18", 2.0 if sel else 1.0, 6)
		c.fs(str(z["acc"]) if have else "#3a3026"); c.fill_rect(ox + 5, ry + 6, 4, rh - 18)
		c.ftxt_fit(Lang.T("note." + id) if have else Lang.T("journal.unknown"), ox + 20, ry + rh * 0.42, P["parchGold"] if have else P["inkDark"], 13, lw - 30)
		c.ftxt_fit(Lang.T("zone." + str(z["id"])), ox + 20, ry + rh * 0.42 + 15, str(z["acc"]) if have else "#4a4036", 10, lw - 30)
		m.add_hit(ox, ry, lw, rh - 6, func() -> void: m.journal_sel = i)
	var px := ox + lw + 24
	var pw := tot - lw - 24
	var ph := H - oy - 92
	var sid: String = Story.NOTE_ORDER[clampi(m.journal_sel, 0, Story.NOTE_ORDER.size() - 1)]
	if sid in found:
		_note_page(c, px, oy, pw, ph, sid, -1.0)
	else:
		c.panel(px, oy, pw, ph, "#120e08", "#3a2c18", 1.5, 8)
		c.ftxt("?", px + pw / 2, oy + ph / 2 - 10, "#3a2c18", 90, "center")
		c.wrap_text(Lang.T("journal.missing", Lang.T("zone." + Story.zone_id(Story.note_zone(sid)))), px + pw / 2, oy + ph / 2 + 50, pw - 80, 13, P["inkDark"], "center")
	# alsó gombok
	var by := H - 66.0
	var bw := 220.0
	c.panel(W / 2 - bw - 10, by, bw, 44, "#1c1408", P["parchEdge"], 1.5, 8)
	c.ftxt_fit(Lang.T("common.back"), W / 2 - bw / 2 - 10, by + 28, P["ink"], 14, bw - 16, "center")
	m.add_hit(W / 2 - bw - 10, by, bw, 44, m.close_journal)
	c.panel(W / 2 + 10, by, bw, 44, "#2e2210", P["parchGold"], 2, 8)
	c.ftxt_fit(Lang.T("journal.intro"), W / 2 + bw / 2 + 10, by + 28, P["parchGold"], 14, bw - 16, "center")
	m.add_hit(W / 2 + 10, by, bw, 44, func() -> void: m.start_cine("intro", "journal"))


# ══════════ A MŰTŐTEREM ══════════
static func _npc_panel(m: Node, c: Cv, x: float, y: float, w: float, h: float, npc: String, first_key: int) -> void:
	var P := Data.P
	var nora := npc == "nora"
	var col := "#e0a060" if nora else "#b0e060"
	var icon := "⚙" if nora else "☣"
	c.panel(x, y, w, h, rgba(16, 12, 8, 0.92), col, 2, 10)
	# arckép + név
	var pr := 44.0
	c.fs("#0a0806"); c.circ(x + 20 + pr, y + 20 + pr, pr)
	c.fs(Color(Cv.col(col), 0.14)); c.circ(x + 20 + pr, y + 20 + pr, pr - 2)
	portrait(m, c, npc, x + 20 + pr, y + 26 + pr, pr * 1.5)
	c.ss(col); c.lw(2); c.bp(); c.arc(x + 20 + pr, y + 20 + pr, pr, 0, 7); c.stroke()
	var tx := x + 2 * pr + 36
	c.ftxt_fit(Lang.T("npc." + npc), tx, y + 34, col, 17, w - 2 * pr - 50)
	c.ftxt_fit(Lang.T("npc." + npc + ".role"), tx, y + 52, P["inkDark"], 11, w - 2 * pr - 50)
	# amit mond (a történet állása szerint)
	var meta: Dictionary = Meta.data().duplicate()
	meta["just_bought_nora"] = m.hub_bought == "nora"
	meta["just_bought_prophet"] = m.hub_bought == "profeta"
	var line := Story.nora_line(meta) if nora else Story.prophet_line(meta)
	var lines := Cv.wrap_lines("„" + Lang.T(line) + "”", w - 2 * pr - 52, 11.5)
	for i in mini(lines.size(), 5):
		c.ftxt(lines[i], tx, y + 72 + i * 15, "#e0d0a8", 11.5)
	# fejlesztések
	var ry := y + 2 * pr + 54
	var rows: Array = []
	for id in Meta.ORDER:
		if Meta.UPGRADES[id]["npc"] == npc:
			rows.append(id)
	var rh := minf(76.0, (h - (2 * pr + 62)) / maxf(1.0, rows.size()))
	for i in rows.size():
		var id: String = rows[i]
		var d: Dictionary = Meta.UPGRADES[id]
		var lv := Meta.level(id)
		var mx: int = d["max"]
		var maxed := lv >= mx
		var can := Meta.can_buy(id)
		var yy := ry + i * rh
		c.panel(x + 12, yy, w - 24, rh - 8, "#1e160c" if can else "#120e08", str(d["col"]) if can else "#3a2c18", 1.6 if can else 1.0, 7)
		c.rrect_fill_c(x + 20, yy + 8, 38, rh - 24, 8, Color(Cv.col(d["col"]), 0.16))
		c.ftxt(str(d["ic"]), x + 39, yy + rh * 0.5 + 2, d["col"], 20, "center")
		var bw := 104.0
		var nw := w - 24 - 58 - bw - 20
		c.ftxt_fit(Lang.T("up." + id), x + 68, yy + 22, P["parchGold"], 13, nw - 60)
		# szint-pöttyök
		for j in mx:
			c.fs(str(d["col"]) if j < lv else "#3a3026"); c.circ(x + 68 + nw - 8 - (mx - 1 - j) * 11, yy + 17, 3.6)
		c.ftxt_fit(Lang.T("up." + id + ".d"), x + 68, yy + 40, P["ink"], 10.5, nw)
		c.ftxt_fit("[%d]" % (first_key + i), x + 68, yy + rh - 16, P["inkDark"], 9, 40)
		var bx := x + w - 12 - bw - 8
		if maxed:
			c.ftxt_fit(Lang.T("hub.max"), bx + bw / 2, yy + rh * 0.5 + 1, P["inkDark"], 12, bw, "center")
		else:
			c.panel(bx, yy + 10, bw, rh - 28, "#2e2210" if can else "#16100a", col if can else "#3a2c18", 1.6, 6)
			c.ftxt_fit("%s %d" % [icon, Meta.cost(id)], bx + bw / 2, yy + rh * 0.5 + 1, col if can else "#6a5a4a", 14, bw - 10, "center")
			m.add_hit(x + 12, yy, w - 24, rh - 8, func() -> void: m.hub_buy(id))


static func hub(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var d := Meta.data()
	c.fs("#080604"); c.fill_rect(0, 0, W, H)
	art(c, "lombik", 0, 0, W, H, m.tick, 0.5 + 0.5 * sin(m.tick * 0.002))
	c.fs(rgba(6, 6, 5, 0.66)); c.fill_rect(0, 0, W, H)
	MenuArt.ls_text(c, Lang.T("hub.title").to_upper(), W / 2, 50, P["parchGold"], 28, 4.0, "center")
	c.ftxt_fit(Lang.T("hub.sub"), W / 2, 74, P["ink"], 12, W - 300, "center")
	# nyersanyag (jobbra fent, a hang gomb mellett)
	c.rrect_fill_c(W - 300, 16, 230, 34, 8, rgba(0, 0, 0, 0.6))
	c.ftxt("☣ %d" % int(d["bio"]), W - 286, 39, "#b0e060", 16)
	c.ftxt("⚙ %d" % int(d["rez"]), W - 176, 39, "#e0a060", 16)
	c.ftxt_fit(Lang.T("hub.cur"), W - 185, 64, P["inkDark"], 10, 230, "center")
	var tot := minf(1180.0, W - 32)
	var gap := 16.0
	var mid := clampf(tot * 0.20, 190.0, 240.0)
	var pw := (tot - mid - 2 * gap) / 2
	var ox := (W - tot) / 2
	var oy := 96.0
	var ph := H - oy - 24
	_npc_panel(m, c, ox, oy, pw, ph, "nora", 1)
	_npc_panel(m, c, ox + pw + mid + 2 * gap, oy, pw, ph, "profeta", 5)
	# középen: a lombik körüli adatok és a gombok
	var cx := ox + pw + gap + mid / 2
	c.panel(cx - mid / 2, oy, mid, ph, rgba(10, 14, 14, 0.82), "#3a6a60", 1.5, 10)
	c.ftxt_fit(Lang.T("who.vane"), cx, oy + 34, "#a0f0d8", 20, mid - 16, "center")
	c.ftxt_fit(Lang.T("hub.vane"), cx, oy + 54, P["inkDark"], 11, mid - 16, "center")
	var stats := [
		[Lang.T("hub.st.runs"), str(int(d["runs"]))],
		[Lang.T("hub.st.deaths"), str(int(d["deaths"]))],
		[Lang.T("hub.st.wins"), str(int(d["wins"]))],
		[Lang.T("hub.st.kills"), str(int(d["kills"]))],
		[Lang.T("hub.st.deepest"), (Lang.T("zone." + Story.zone_id(int(d["deepest"]))) if int(d["deepest"]) > 0 else "—")],
		[Lang.T("hub.st.notes"), "%d / %d" % [(d["notes"] as Array).size(), Story.NOTE_ORDER.size()]],
	]
	for i in stats.size():
		var sy := oy + 90 + i * 40
		c.ftxt_fit(str(stats[i][0]), cx, sy, P["inkDark"], 10, mid - 20, "center")
		c.ftxt_fit(str(stats[i][1]), cx, sy + 17, P["ink"], 14, mid - 20, "center")
	var btns := [
		[Lang.T("hub.descend"), P["parchGold"], "#2e2210", m.go_diff],
		[Lang.T("menu.journal"), "#e0d0a8", "#1c1408", func() -> void: m.open_journal("hub")],
		[Lang.T("over.menu"), P["ink"], "#14100a", func() -> void: m.set_state("menu")],
	]
	var bh := 46.0
	for i in btns.size():
		var by := oy + ph - 16 - (btns.size() - i) * (bh + 10)
		if i == 0:
			c.soft_shadow(cx - mid / 2 + 12, by, mid - 24, bh, 8, rgba(212, 168, 75, 0.45), 16)
		c.panel(cx - mid / 2 + 12, by, mid - 24, bh, btns[i][2], btns[i][1], 2.2 if i == 0 else 1.4, 8)
		c.ftxt_fit(btns[i][0], cx, by + bh * 0.64, btns[i][1], 15 if i == 0 else 13, mid - 40, "center")
		m.add_hit(cx - mid / 2 + 12, by, mid - 24, bh, btns[i][3])


# ══════════ MENTÉSEK (több hely + felhő) ══════════
static func _datum(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%04d.%02d.%02d.  %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


static func saves(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var l: Array = SaveGame.list()
	var futo: bool = m.saves_back == "pause"
	c.fs(rgba(4, 4, 3, 0.94) if futo else "#080604"); c.fill_rect(0, 0, W, H)
	if not futo:
		art(c, "lombik", 0, 0, W, H, m.tick, 0.5)
		c.fs(rgba(6, 5, 4, 0.86)); c.fill_rect(0, 0, W, H)
	c.ftxt(Lang.T("saves.title"), W / 2, 48, P["parchGold"], 26, "center")
	# a felhő állapota: belépve a mentések a fiókhoz tartoznak, nem a géphez
	var fa: String = m.felho.allapot
	var fcol := "#8a8070"
	match fa:
		"kesz": fcol = "#80d0ff"
		"megy", "var": fcol = "#e0d080"
		"hiba": fcol = "#ff8070"
	var ftxt := Lang.T("cloud." + fa)
	if fa == "hiba" and Lang.has("cloud.hiba." + str(m.felho.hiba)):
		ftxt = Lang.T("cloud.hiba." + str(m.felho.hiba))
	c.ftxt_fit(ftxt, W / 2, 72, fcol, 12, W - 80, "center")
	var pw := minf(760.0, W - 32)
	var ox := (W - pw) / 2
	var oy := 92.0
	var alul := 78.0
	var rh := 74.0
	var lathato := maxi(1, int((H - oy - alul) / rh))
	var kezd := clampi(int(m.saves_sel) - lathato + 1, 0, maxi(0, l.size() - lathato))
	if l.is_empty():
		c.panel(ox, oy, pw, 120, "#120e08", "#3a2c18", 1.5, 8)
		c.ftxt_fit(Lang.T("saves.empty"), W / 2, oy + 66, P["inkDark"], 14, pw - 40, "center")
	for k in range(kezd, mini(l.size(), kezd + lathato)):
		var e: Dictionary = l[k]
		var y := oy + (k - kezd) * rh
		var sel: bool = m.saves_sel == k
		var arm: bool = m.saves_arm == str(e["id"])
		var z := Story.zone(int(e["zona"]))
		var cls := str(e["cls"])
		var ccol: String = Data.CLASSES[cls]["col"] if Data.CLASSES.has(cls) else "#c8a870"
		if sel:
			c.soft_shadow(ox, y, pw, rh - 8, 8, Color(Cv.col(z["acc"]), 0.35), 14)
		c.panel(ox, y, pw, rh - 8, "#221a0e" if sel else "#14100a", str(z["acc"]) if sel else "#3a2c18", 2.0 if sel else 1.0, 8)
		# a hős arcképe
		c.fs("#0a0806"); c.circ(ox + 40, y + 33, 26)
		c.fs(Color(Cv.col(ccol), 0.16)); c.circ(ox + 40, y + 33, 24)
		if Data.CLASSES.has(cls):
			Sprites.hero_cached(c, cls, ox + 40, y + 36, 34, m.tick, m.skins)
		c.ss(ccol); c.lw(1.6); c.bp(); c.arc(ox + 40, y + 33, 26, 0, 7); c.stroke()
		var tx := ox + 82
		var bw := 112.0
		var tw := pw - 82 - bw - 62 - 30
		var auto: bool = e["auto"]
		c.ftxt_fit(Lang.T("saves.auto") if auto else Lang.T("saves.manual"), tx, y + 24, "#9ce0a0" if auto else "#a0d0ff", 11, 150)
		c.ftxt_fit(_datum(int(e["ido"])), tx + 160, y + 24, P["inkDark"], 11, tw - 160)
		c.ftxt_fit(Lang.T("saves.row", Lang.cls(cls), int(e["plvl"]), Lang.T("zone." + str(z["id"]))), tx, y + 44, P["parchGold"], 14, tw)
		c.ftxt_fit(Lang.T("saves.row2", int(e["hp"]), int(e["max_hp"]), int(e["kor"]), Lang.T("diff." + str(e["nehezseg"]))), tx, y + 60, P["ink"], 10, tw)
		# felhő-jel: ez a mentés a fiókodban is megvan
		if m.felho.felhoben_van(str(e["id"]) + ".json"):
			c.ftxt("☁", ox + pw - bw - 62 - 14, y + 40, "#80d0ff", 18, "center")
		var bx := ox + pw - bw - 62
		c.panel(bx, y + 14, bw, 38, "#2e2210", P["parchGold"], 1.6, 6)
		c.ftxt_fit(Lang.T("saves.load"), bx + bw / 2, y + 38, P["parchGold"], 13, bw - 10, "center")
		c.panel(ox + pw - 54, y + 14, 44, 38, "#3a1008" if arm else "#1e0c08", "#ff6050" if arm else "#6a3a2a", 2.0 if arm else 1.2, 6)
		c.ftxt("✕" if not arm else "!", ox + pw - 32, y + 39, "#ff8070" if arm else "#c08070", 15, "center")
		m.add_hit(ox + pw - 54, y + 14, 44, 38, func() -> void:
			m.saves_sel = k
			m.saves_delete(k))
		m.add_hit(bx, y + 14, bw, 38, func() -> void: m.saves_load(k))
		m.add_hit(ox, y, pw, rh - 8, func() -> void:
			m.saves_sel = k
			m.saves_arm = "")
	if l.size() > lathato:
		c.ftxt_fit("%d – %d / %d" % [kezd + 1, mini(l.size(), kezd + lathato), l.size()], ox + pw, oy - 8, P["inkDark"], 10, 120, "right")
	# visszajelzés / megerősítés
	var by := H - 62.0
	if m.saves_arm != "":
		c.ftxt_fit(Lang.T("saves.confirm"), W / 2, by - 12, "#ff8070", 12, pw, "center")
	elif m.saves_msg != "":
		c.ftxt_fit(Lang.T(str(m.saves_msg)), W / 2, by - 12, "#9ce0a0", 12, pw, "center")
	# alsó gombok
	var gw := 220.0
	var gombok: Array = [[Lang.T("common.back"), P["ink"], "#1c1408", P["parchEdge"], m.close_saves]]
	if futo:
		gombok.append([Lang.T("saves.new"), "#9ce0a0", "#16280f", "#5aa050", m.save_snapshot])
	var gx := W / 2 - (gombok.size() * gw + (gombok.size() - 1) * 16) / 2
	for i in gombok.size():
		c.panel(gx + i * (gw + 16), by, gw, 42, gombok[i][2], gombok[i][3], 1.6, 8)
		c.ftxt_fit(str(gombok[i][0]), gx + i * (gw + 16) + gw / 2, by + 27, gombok[i][1], 13, gw - 14, "center")
		m.add_hit(gx + i * (gw + 16), by, gw, 42, gombok[i][4])
	c.ftxt_fit(Lang.T("saves.hint.run") if futo else Lang.T("saves.hint"), W / 2, H - 6, P["inkDark"], 10, W - 40, "center")