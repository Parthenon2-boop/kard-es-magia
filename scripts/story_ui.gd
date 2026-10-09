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
	if art.ends_with("_elo"):
		ut = "res://art/%s.png" % art
	if ResourceLoader.exists(ut):
		t = load(ut) as Texture2D
	_art_cache[art] = t
	return t


## Egy háttérkép kirakása lassú közelítéssel és úsztatással (a kép sosem áll).
## u: 0..1, a képsor előrehaladása; irany: melyik felé úszik.
static func art(c: Cv, name: String, x: float, y: float, w: float, h: float, tick: float, u: float, irany := 0, melyseg := false) -> void:
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
	# mélység: az előtér-réteg (res://art/<név>_elo.png, átlátszó háttérrel) nagyobb léptékben és
	# gyorsabban mozog, mint a háttér — ettől térbelinek hat a kép
	var elo := art_tex(name + "_elo")
	if elo != null:
		var es := elo.get_size()
		var ez := maxf(w / es.x, h / es.y) * (1.16 + 0.22 * u)
		var evw := w / ez
		var evh := h / ez
		var irx := 1.0 if irany % 2 == 0 else -1.0
		var efx := (es.x - evw) * clampf(0.5 + (0.5 - u) * 0.95 * irx, 0.0, 1.0)
		var efy := (es.y - evh) * clampf(0.62 + (u - 0.5) * 0.4, 0.0, 1.0)
		c.tex_region(elo, Rect2(x, y, w, h), Rect2(efx, efy, evw, evh))
	elif melyseg:
		_eloter(c, x, y, w, h, tick, u, irany)
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
	art(c, str(sl["art"]), 0, 0, W, ah, m.tick, clampf(el / SLIDE_MS, 0.0, 1.0), i, true)
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
		[Lang.T("hub.st.badges"), "%d / %d" % [(d["jelvenyek"] as Array).size(), Meta.JELVENYEK.size()]],
	]
	# jelvények: megszerezve színesek
	for i in Meta.JELVENYEK.size():
		var jv: String = Meta.JELVENYEK[i]
		var megvan := Meta.has_badge(jv)
		var jx := cx - (Meta.JELVENYEK.size() - 1) * 12.0 + i * 24.0
		c.fs("#2e2210" if megvan else "#14100a"); c.circ(jx, oy + 384, 10)
		c.ftxt(str(Meta.JELVENY_IKON[jv]), jx, oy + 389, "#ffe070" if megvan else "#3a3026", 12, "center")
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


# ══════════ EREKLYE-VÁLASZTÓ ══════════
static func relic_pick(m: Node, c: Cv) -> void:
	if m.relic_ui == null:
		return
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var p: Player = m.game.player
	var ids: Array = m.relic_ui["ids"]
	var sel: int = m.relic_ui["sel"]
	var n := maxi(1, ids.size())
	c.fs(rgba(0, 0, 0, 0.88)); c.fill_rect(0, 0, W, H)
	var pw := minf(360.0 * n + 40, W - 24)
	var card_h := minf(280.0, H - 190)
	var ph := 96 + card_h + 44
	var ox := (W - pw) / 2
	var oy := maxf(12, (H - ph) / 2)
	c.soft_shadow(ox, oy, pw, ph, 10, rgba(120, 210, 255, 0.4), 30)
	c.panel(ox, oy, pw, ph, "#0e141a", "#80d0ff", 2, 10)
	c.ftxt_fit(Lang.T("relic.title"), W / 2, oy + 34, "#a0dcff", 19, pw - 40, "center")
	c.orna(ox + 16, oy + 46, pw - 32, "#2a4a5a")
	c.ftxt_fit(Lang.T("relic.sub"), W / 2, oy + 68, P["inkDark"], 11, pw - 40, "center")
	var cw := (pw - 24 - (n - 1) * 12) / n
	for i in ids.size():
		var id: String = ids[i]
		var d := Relics.info(id)
		var cx := ox + 12 + i * (cw + 12)
		var cy := oy + 84
		var bd: String = d["col"]
		if i == sel:
			c.soft_shadow(cx, cy, cw, card_h, 8, Color(Cv.col(bd), 0.5), 16)
		c.panel(cx, cy, cw, card_h, "#12100c", bd, 3.0 if i == sel else 1.6, 8)
		var gl := 0.5 + 0.5 * sin(m.tick * 0.08 + i)
		c.tex(m.tex_glow, Rect2(cx + cw / 2 - 60, cy + 4, 120, 120), Color(Cv.col(bd), 0.20 + 0.14 * gl))
		c.rrect_fill_c(cx + cw / 2 - 30, cy + 22, 60, 60, 12, Color(Cv.col(bd), 0.18))
		c.ftxt(str(d["ic"]), cx + cw / 2, cy + 66, bd, 34, "center")
		c.ftxt_fit(str(d["n"]), cx + cw / 2, cy + 112, P["parchGold"], 16, cw - 16, "center")
		c.orna(cx + cw * 0.28, cy + 123, cw * 0.44, P["parchEdge"])
		c.wrap_text(str(d["d"]), cx + cw / 2, cy + 148, cw - 30, 12, P["ink"], "center")
		# együttműködés a meglévő ereklyékkel
		var egy := Relics.synergy_with(p, id)
		if not egy.is_empty():
			var nevek: Array = []
			for e in egy:
				nevek.append(Lang.T("relic." + str(e)))
			c.rrect_fill_c(cx + 10, cy + card_h - 62, cw - 20, 24, 6, Color(Cv.col("#80d0ff"), 0.14))
			c.ftxt_fit(Lang.T("relic.synergy", ", ".join(nevek)), cx + cw / 2, cy + card_h - 45, "#a0dcff", 11, cw - 30, "center")
		c.ftxt("[%d]" % (i + 1), cx + cw / 2, cy + card_h - 14, bd, 12, "center")
		m.add_hit(cx, cy, cw, card_h, func() -> void: m.pick_relic(i))
	c.ftxt_fit(Lang.T("relic.hint"), W / 2, oy + ph - 14, P["inkDark"], 10, pw - 30, "center")


# ══════════ DÖNTÉSI ESEMÉNY ══════════
static func event(m: Node, c: Cv) -> void:
	if m.event_ui == null:
		return
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var kind := str(m.event_ui["ev"]["kind"])
	var sel: int = m.event_ui["sel"]
	c.fs(rgba(0, 0, 0, 0.84)); c.fill_rect(0, 0, W, H)
	var pw := minf(640.0, W - 24)
	var ph := 360.0
	var ox := (W - pw) / 2
	var oy := maxf(12, (H - ph) / 2)
	c.soft_shadow(ox, oy, pw, ph, 10, rgba(255, 210, 110, 0.35), 28)
	c.panel(ox, oy, pw, ph, "#16110a", "#ffd870", 2, 10)
	Sprites2.event_mark(c, ox + 22, oy + 14, 64, m.tick)
	c.ftxt_fit(Lang.T("event." + kind), ox + 104, oy + 46, "#ffd870", 20, pw - 130)
	c.orna(ox + 104, oy + 58, pw - 130, P["parchEdge"])
	c.wrap_text(Lang.T("event." + kind + ".d"), ox + 30, oy + 108, pw - 60, 14, P["ink"])
	for i in 2:
		var by := oy + 190 + i * 70
		var on := sel == i
		c.panel(ox + 24, by, pw - 48, 58, "#2e2210" if on else "#1a140c", P["parchGold"] if on else P["parchEdge"], 2.5 if on else 1.2, 8)
		c.ftxt("[%d]" % (i + 1), ox + 44, by + 36, P["parchGold"], 14)
		var sorok := Cv.wrap_lines(Lang.T("event." + kind + (".a" if i == 0 else ".b")), pw - 130, 13)
		for j in mini(2, sorok.size()):
			c.ftxt(sorok[j], ox + 80, by + (36 if sorok.size() == 1 else 26 + j * 18), "#f0e4c8" if on else P["ink"], 13)
		m.add_hit(ox + 24, by, pw - 48, 58, func() -> void: m.pick_event(i))
	c.ftxt_fit(Lang.T("event.hint"), W / 2, oy + ph - 14, P["inkDark"], 10, pw - 30, "center")


# ══════════ NAPI KIHÍVÁS ══════════
static func daily(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var nap := Daily.nap()
	c.fs("#080604"); c.fill_rect(0, 0, W, H)
	art(c, "gorgona", 0, 0, W, H, m.tick, 0.5 + 0.5 * sin(m.tick * 0.0016), 1)
	c.fs(rgba(6, 5, 4, 0.82)); c.fill_rect(0, 0, W, H)
	MenuArt.ls_text(c, Lang.T("daily.title").to_upper(), W / 2, 56, "#ffd870", 28, 4.0, "center")
	c.ftxt(nap.replace("-", ". ") + ".", W / 2, 82, P["ink"], 14, "center")
	var tot := minf(900.0, W - 32)
	var ox := (W - tot) / 2
	var lw := tot * 0.46
	var oy := 108.0
	var ph := H - oy - 30
	# bal oldal: a szabályok, a mai legjobb, indulás
	c.panel(ox, oy, lw, ph, rgba(16, 12, 8, 0.92), "#b08a30", 2, 10)
	c.wrap_text(Lang.T("daily.desc"), ox + 22, oy + 40, lw - 44, 13, P["ink"])
	var best := Meta.napi_legjobb(nap)
	c.rrect_fill_c(ox + 18, oy + ph - 180, lw - 36, 64, 8, "#120e08")
	c.ftxt_fit(Lang.T("daily.best", best) if best > 0 else Lang.T("daily.none"), ox + lw / 2, oy + ph - 141, "#ffd870" if best > 0 else P["inkDark"], 16, lw - 60, "center")
	c.soft_shadow(ox + 18, oy + ph - 100, lw - 36, 52, 8, rgba(212, 168, 75, 0.45), 16)
	c.panel(ox + 18, oy + ph - 100, lw - 36, 52, "#2e2210", P["parchGold"], 2.2, 8)
	c.ftxt_fit(Lang.T("daily.start"), ox + lw / 2, oy + ph - 66, P["parchGold"], 17, lw - 60, "center")
	m.add_hit(ox + 18, oy + ph - 100, lw - 36, 52, m.daily_start)
	c.panel(ox + 18, oy + ph - 40, 120, 30, "#1c1408", P["parchEdge"], 1.2, 6)
	c.ftxt_fit(Lang.T("common.back"), ox + 78, oy + ph - 20, P["ink"], 11, 110, "center")
	m.add_hit(ox + 18, oy + ph - 40, 120, 30, func() -> void: m.set_state("menu"))
	# jobb oldal: a mai ranglista
	var rx := ox + lw + 16
	var rw := tot - lw - 16
	c.panel(rx, oy, rw, ph, rgba(16, 12, 8, 0.92), "#3a6a60", 2, 10)
	c.ftxt_fit(Lang.T("daily.top"), rx + rw / 2, oy + 32, "#a0f0d8", 17, rw - 30, "center")
	c.orna(rx + 18, oy + 44, rw - 36, "#2a4a44")
	var fa: String = m.fiok.napi_allapot
	if fa != "kesz":
		var k := "daily.loading"
		if fa == "nincs": k = "daily.login"
		elif fa == "hiba": k = "daily.error"
		c.wrap_text(Lang.T(k), rx + rw / 2, oy + ph * 0.4, rw - 50, 13, P["inkDark"], "center")
	elif m.fiok.napi_lista.is_empty():
		c.wrap_text(Lang.T("daily.empty"), rx + rw / 2, oy + ph * 0.4, rw - 50, 13, P["inkDark"], "center")
	else:
		var sor := minf(34.0, (ph - 70) / 20.0 * 1.6)
		for i in mini(m.fiok.napi_lista.size(), int((ph - 64) / sor)):
			var e: Dictionary = m.fiok.napi_lista[i]
			var y := oy + 58 + i * sor
			if e["en"]:
				c.rrect_fill_c(rx + 10, y, rw - 20, sor - 4, 6, Color(Cv.col("#ffd870"), 0.14))
			var hc: String = "#ffd870" if i == 0 else ("#d0d4dc" if i == 1 else ("#d09060" if i == 2 else P["ink"]))
			c.ftxt("%d." % (i + 1), rx + 22, y + sor * 0.62, hc, 13)
			c.ftxt_fit(str(e["nev"]), rx + 56, y + sor * 0.62, "#ffe9a0" if e["en"] else P["ink"], 13, rw * 0.36)
			var ks := str(e["kaszt"])
			var info := (Lang.cls(ks) if Data.CLASSES.has(ks) else "") + "  ·  " + (Lang.T("daily.won") if e["gyozelem"] else Lang.T("daily.zone", int(e["zona"])))
			c.ftxt_fit(info, rx + 60 + rw * 0.36, y + sor * 0.62, P["inkDark"], 10.5, rw * 0.30)
			c.ftxt(Lang.T("daily.points", int(e["pont"])), rx + rw - 18, y + sor * 0.62, hc, 13, "right")
	c.ftxt_fit(Lang.T("daily.hint"), W / 2, H - 10, P["inkDark"], 10, W - 40, "center")


## Rajzolt előtér-réteg a festmények elé (ha nincs külön festett): a kép két szélén és alján sötét
## csövek, szelepek, fogaskerekek és lelógó kábelek. Nagyobb léptékben és gyorsabban mozog, mint a
## háttér, ezért a kép térbelinek hat (közel – távol).
static func _eloter(c: Cv, x: float, y: float, w: float, h: float, tick: float, u: float, irany: int) -> void:
	var k := h / 400.0
	var ir := 1.0 if irany % 2 == 0 else -1.0
	var tol := (0.5 - u) * w * 0.10 * ir       # az előtér vízszintes úszása (a háttérénél jóval nagyobb)
	var lep := 1.0 + 0.10 * u                    # és közelít is
	var sot := Color(0.035, 0.028, 0.022, 0.96)
	var perem := Color(0.55, 0.36, 0.16, 0.55)   # meleg peremfény a széleken
	for oldal_v in [-1.0, 1.0]:
		var oldal: float = oldal_v
		var bx: float = (x if oldal < 0 else x + w) + tol
		# függőleges csőköteg a kép szélén
		for i in 3:
			var cw := (26.0 - i * 6.0) * k * lep
			var cx: float = (bx - (34.0 + i * 32.0) * k * lep) if oldal > 0 else (bx + (8.0 + i * 32.0) * k * lep)
			c.fs(sot); c.fill_rect(cx, y, cw, h)
			c.fs(perem); c.fill_rect(cx + (0.0 if oldal > 0 else cw - 2.0 * k), y, 2.0 * k, h)
			# karimák
			for j in 4:
				var jy := y + h * (0.12 + j * 0.24) + sin(i * 2.1 + j) * 14.0 * k
				c.fs(sot); c.fill_rect(cx - 4.0 * k, jy, cw + 8.0 * k, 10.0 * k)
				c.fs(perem); c.fill_rect(cx - 4.0 * k, jy, cw + 8.0 * k, 1.5 * k)
		# nagy fogaskerék félig a képen kívül
		var gx: float = bx - oldal * 10.0 * k
		var gy: float = y + h * (0.74 if oldal < 0 else 0.30)
		var gr := 70.0 * k * lep
		c.save(); c.translate(gx, gy); c.rotate(tick * 0.004 * oldal)
		c.fs(sot)
		for i in 12:
			var a := i / 12.0 * TAU
			c.poly([cos(a - 0.11) * gr, sin(a - 0.11) * gr, cos(a - 0.07) * gr * 1.2, sin(a - 0.07) * gr * 1.2,
				cos(a + 0.07) * gr * 1.2, sin(a + 0.07) * gr * 1.2, cos(a + 0.11) * gr, sin(a + 0.11) * gr])
		c.circ(0, 0, gr * 1.02)
		c.ss(perem); c.lw(2.0 * k); c.bp(); c.arc(0, 0, gr * 0.72, 0, TAU); c.stroke()
		c.restore()
	# lelógó kábelek felülről (lassan lengenek)
	c.ss(sot); c.lw(5.0 * k)
	for i in 5:
		var kx := x + w * (0.10 + i * 0.20) + tol * 1.4
		var leng := sin(tick * 0.012 + i * 1.7) * 10.0 * k
		c.bp(); c.mt(kx, y - 4); c.qt(kx + 70.0 * k + leng, y + (60.0 + (i % 3) * 34.0) * k, kx + 150.0 * k, y - 4); c.stroke()
	# alul korlát és szelepkerekek sziluettje
	var ay := y + h - 26.0 * k
	c.fs(sot); c.fill_rect(x, ay, w, 26.0 * k + 2)
	c.fs(perem); c.fill_rect(x, ay, w, 1.5 * k)
	for i in 9:
		var px := x + fposmod(i * w / 8.0 + tol * 1.6, w + 80.0 * k) - 40.0 * k
		c.fs(sot); c.fill_rect(px - 3.0 * k, ay - 30.0 * k, 6.0 * k, 32.0 * k)
		if i % 3 == 0:
			c.ss(sot); c.lw(5.0 * k); c.bp(); c.arc(px, ay - 40.0 * k, 13.0 * k, 0, TAU); c.stroke()
			c.line(px - 13.0 * k, ay - 40.0 * k, px + 13.0 * k, ay - 40.0 * k)
	c.fs(sot); c.fill_rect(x, ay - 14.0 * k, w, 4.0 * k)


# ══════════ BEÁLLÍTÁSOK (kép) ══════════
static func settings(m: Node, c: Cv) -> void:
	var W: float = m.W
	var H: float = m.H
	var P := Data.P
	var futo: bool = m.settings_back == "pause"
	c.fs(rgba(4, 4, 3, 0.94) if futo else "#080604"); c.fill_rect(0, 0, W, H)
	if not futo:
		art(c, "gorgona", 0, 0, W, H, m.tick, 0.5 + 0.5 * sin(m.tick * 0.0016), 1)
		c.fs(rgba(6, 5, 4, 0.84)); c.fill_rect(0, 0, W, H)
	var pw := minf(620.0, W - 24)
	var rh := minf(60.0, (H - 150) / 7.0)
	var ph := 84 + 7 * rh + 40
	var ox := (W - pw) / 2
	var oy := maxf(10, (H - ph) / 2)
	c.panel(ox, oy, pw, ph, P["parch"], P["parchGold"], 2, 10)
	c.ftxt_fit(Lang.T("set.title"), W / 2, oy + 38, P["parchGold"], 20, pw - 40, "center")
	c.orna(ox + 18, oy + 52, pw - 36, P["parchEdge"])
	var be := Lang.T("set.on")
	var ki := Lang.T("set.off")
	var meret: float = float(m.kep["meret"])
	var meret_txt := Lang.T("set.scale.auto", int(roundf(m.kep_auto() * 100.0))) if meret <= 0.0 else "%d%%" % int(roundf(meret * 100.0))
	var sorok := [
		[Lang.T("set.scale"), meret_txt, Lang.T("set.scale.d", int(roundf(m.kep_meret() * 100.0)))],
		[Lang.T("set.full"), be if m.kep["teljes"] else ki, Lang.T("set.full.d")],
		[Lang.T("set.vsync"), be if m.kep["vsync"] else ki, Lang.T("set.vsync.d")],
		[Lang.T("set.shake"), be if m.kep["razas"] else ki, Lang.T("set.shake.d")],
		[Lang.T("set.particles"), be if m.kep["reszecske"] else ki, Lang.T("set.particles.d")],
		[Lang.T("set.tempo"), Lang.T("set.tempo." + str(clampi(int(m.kep["tempo"]), 0, 2))), Lang.T("set.tempo.d")],
		[Lang.T("menu.controls"), "▶", Lang.T("set.controls.d")],
	]
	for i in sorok.size():
		var y := oy + 66 + i * rh
		var sel: bool = m.settings_sel == i
		c.panel(ox + 14, y, pw - 28, rh - 8, "#2e2210" if sel else "#1a140c", P["parchGold"] if sel else P["parchEdge"], 2.2 if sel else 1.0, 8)
		c.ftxt_fit(str(sorok[i][0]), ox + 30, y + rh * 0.40, P["parchGold"] if sel else P["ink"], 15, pw * 0.5)
		c.ftxt_fit(str(sorok[i][2]), ox + 30, y + rh * 0.40 + 17, P["inkDark"], 10.5, pw * 0.56)
		var vx := ox + pw - 150
		if i < 6:
			c.panel(vx - 62, y + rh * 0.5 - 20, 32, 32, "#241a0c", P["parchEdge"], 1.2, 6)
			c.ftxt("◀", vx - 46, y + rh * 0.5 + 1, P["parchGold"], 13, "center")
			m.add_hit(vx - 62, y + rh * 0.5 - 20, 32, 32, func() -> void:
				m.settings_sel = i
				m.kep_valt(i, -1))
			c.panel(vx + 88, y + rh * 0.5 - 20, 32, 32, "#241a0c", P["parchEdge"], 1.2, 6)
			c.ftxt("▶", vx + 104, y + rh * 0.5 + 1, P["parchGold"], 13, "center")
			m.add_hit(vx + 88, y + rh * 0.5 - 20, 32, 32, func() -> void:
				m.settings_sel = i
				m.kep_valt(i, 1))
			c.ftxt_fit(str(sorok[i][1]), vx + 29, y + rh * 0.5 + 2, "#ffe9a0", 14, 112, "center")
			m.add_hit(ox + 14, y, pw - 28, rh - 8, func() -> void: m.settings_sel = i)
		else:
			c.ftxt("▶", ox + pw - 46, y + rh * 0.5 + 1, P["parchGold"], 15, "center")
			m.add_hit(ox + 14, y, pw - 28, rh - 8, func() -> void: m.set_state("help"))
	c.ftxt_fit(Lang.T("set.hint"), W / 2, oy + ph - 14, P["inkDark"], 10, pw - 30, "center")
	c.panel(12, 12, 110, 40, "#1c1408", P["parchEdge"], 1.5, 6)
	c.ftxt_fit(Lang.T("common.back"), 67, 38, P["ink"], 12, 100, "center")
	m.add_hit(12, 12, 110, 40, m.close_settings)