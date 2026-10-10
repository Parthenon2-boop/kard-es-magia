extends SceneTree
## Egyensúly-mérés: egy robotjátékos sokszor végigjátssza a kalandot, és kiírja, meddig jut.
##   godot --headless --path . -s res://tests/egyensuly.gd -- --n=30 --cls=lovag,magus,ijasz
## Kapcsolók (mind elhagyható):
##   --n=30                 futások száma kasztonként
##   --cls=lovag,magus,ijasz  mely kasztok (ékezet nélkül is: lovag / magus / ijasz / sebesz)
##   --diff=normal          nehézség (easy / normal / hard)
##   --mag=1000             a véletlen magja (ugyanaz a mag ugyanazt a futássort adja)
##   --reszlet              futásonként egy sor
##   --ki=fajl.jsonl        minden kész futás egy JSON-sorként a fájl végére kerül (hosszú mérés
##                          több részletben / több folyamatban is futtatható)
##   --kezd=N               az első N futás kihagyása (megszakadt mérés folytatása)
##   --osszesit=a.jsonl,b.jsonl   nem mér: a --ki fájlokból készít összesítést
##   --csak=N               csak az N. futás, a robot utolsó döntéseivel (hibakeresés)
## NEM része a run_tests.gd-nek: egy teljes kaland 12–15 ezer kör, kasztonként 30 futás
## 10–20 perc. A Műtőterem fejlesztései ki vannak kapcsolva (friss játékos), a mentés a
## tesztmappába megy.
##
## A robot egyszerű, de értelmes: a legközelebbi ellenségre megy és üt / lő, alacsony életerőnél
## gyógyitalt iszik, a jelzett csapás elől kilép vagy félreugrik, használja a kaszt képességét,
## szintlépéskor képességet választ, kinyitja a ládákat (a jobb felszerelést felveszi), rálép a
## szentélyre / eseményre / ereklye-talapzatra, megoldja a rejtvényszobát, kivárja a gőzzsilipet,
## bejárja az emeletet, és csak utána megy le. Nem csal: csak a már felderített mezőket ismeri.
## Amit egy ember jobban csinál: nem hátrál és nem cselez, a kereskedőnél keveset vesz.

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const KASZT_ALIAS := {"lovag": "Lovag", "magus": "Mágus", "ijasz": "Íjász", "sebesz": "Sebész"}
## melyik képességet választja a robot (elöl a legkívánatosabb)
const PERK_SORREND := {
	"Lovag": ["vamp", "vertezet", "szivossag", "eletero", "blokk", "regen", "dofes", "tulhevites", "epeholyag", "idegfonat", "kincs"],
	"Mágus": ["fokusz", "vamp", "eletero", "szivossag", "regen", "atuto", "tulhevites", "messzi", "epeholyag", "idegfonat", "kincs"],
	"Íjász": ["sasszem", "vamp", "eletero", "szivossag", "regen", "hosszuij", "gyorslab", "tulhevites", "epeholyag", "idegfonat", "kincs"],
	"Sebész": ["vamp", "eletero", "szivossag", "regen", "tulhevites", "epeholyag", "idegfonat", "kincs"],
}
## ennyi kör után egy emeleten a robot elakadtnak számít (a futás megszakad)
const KOR_PLAFON := 12000

const MW := Data.MAP_W
const MH := Data.MAP_H

var _dist := PackedInt32Array()
var _szulo := PackedInt32Array()
var _sor := PackedInt32Array()

# ── a robot állapota (emeletenként törlődik) ──
var ut: Array[Vector2i] = []      # a hátralévő útvonal mezői
var ut_cel := -1                  # az útvonal célmezője (index)
var ut_tipus := ""                # "targy" / "hatar" / "lepcso"
var ut_lepes := 0                 # hány lépést tett meg ezen az útvonalon
var bolt_volt := {}               # a már meglátogatott kereskedők
var kihagy := {}                  # elérhetetlen célok (index -> true)
var mellozott := {}               # szörnyek, amelyekhez nem lehet odajutni
var var_kor := 0                  # hány kört várt egyhuzamban
var uldoz: Mon = null             # akit éppen üldöz (akkor is, ha egy pillanatra eltűnt a szeme elől)
var uldoz_ut: Array[Vector2i] = []
var uldoz_lepes := 0
var uldoz_ossz := {}              # szörny -> hány kört töltött a megközelítésével (ütés nélkül)
var csak := -1                    # --csak=N: csak az N. futás (hibakereséshez)
var _vm := {}                     # a gépek veszélyes mezői ebben a körben
var _vm_kor := -1
var _vm_w: World = null
var kivar := 0                    # hány kört várt egy ütemre járó gép (zsilip, korong) előtt
var ut_var := 0                   # hány kört várt egy villogó mező előtt az útvonalon
var nyom: Array = []              # hibakeresés (--csak): az utolsó döntések


func _ny(g: Game, mit: String) -> void:
	if csak < 0:
		return
	nyom.append("%d:%d,%d %s" % [g.world.turn, g.player.x, g.player.y, mit])
	if nyom.size() > 24:
		nyom.pop_front()
var fo: Mon = null
var fo_rec := {}
var mini: Mon = null
var mini_rec := {}
var ital_db := 0
var reszlet := false


func _init() -> void:
	var n := 30
	var kasztok: Array = ["Lovag", "Mágus", "Íjász"]
	var diff := "normal"
	var mag := 1000
	var kezd := 0
	var ki_fajl := ""
	var osszesit := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = maxi(1, int(a.substr(4)))
		elif a.begins_with("--diff="): diff = a.substr(7)
		elif a.begins_with("--mag="): mag = int(a.substr(6))
		elif a == "--reszlet": reszlet = true
		elif a.begins_with("--csak="): csak = int(a.substr(7))
		elif a.begins_with("--kezd="): kezd = maxi(0, int(a.substr(7)))
		elif a.begins_with("--ki="): ki_fajl = a.substr(5)
		elif a.begins_with("--osszesit="): osszesit = a.substr(11)
		elif a.begins_with("--cls="):
			kasztok = []
			for k in a.substr(6).split(","):
				var kk := str(KASZT_ALIAS.get(k.to_lower(), k))
				if Data.CLASSES.has(kk):
					kasztok.append(kk)
	if not Data.DIFF.has(diff):
		diff = "normal"
	Meta.persist = false          # a mérés nem nyúl a játékos Műtőterem-állásához
	Meta.reset()                  # üres fejlesztések: friss játékos
	SaveGame.DIR = "user://_teszt_mentesek/"
	Lang.set_lang("hu")
	_dist.resize(MW * MH)
	_szulo.resize(MW * MH)
	_sor.resize(MW * MH)
	if osszesit != "":
		_osszesit(osszesit)
		quit(0)
		return
	print("══════ EGYENSÚLY-MÉRÉS: %d futás kasztonként, nehézség: %s, mag: %d ══════" % [n, diff, mag])
	print("  pályák: %d (%s) · láda-esély %.2f" % [Data.palyak(), str(Data.EMELET_DB), Data.LADA_ESELY])
	print("  PALYA_HP %s" % str(Data.PALYA_HP))
	print("  PALYA_ATK %s · főellenségek: %s" % [str(Data.PALYA_ATK), str(Data.BOSS_LVL.values().map(func(k: String) -> String: return "%s %d/%d" % [k, Data.MONS[k]["hp"], Data.MONS[k]["atk"]]))])
	var ossz_gyoz := 0
	var ossz := 0
	for cls in kasztok:
		var t0 := Time.get_ticks_msec()
		var futasok: Array = []
		for i in n:
			if (csak >= 0 and i != csak) or i < kezd:
				continue
			seed(mag + i * 7919 + hash(cls) % 1000)
			var r := egy_futas(str(cls), diff)
			futasok.append(r)
			if ki_fajl != "":
				r["i"] = i
				r["mag"] = mag
				var f := FileAccess.open(ki_fajl, FileAccess.READ_WRITE) if FileAccess.file_exists(ki_fajl) else FileAccess.open(ki_fajl, FileAccess.WRITE)
				if f != null:
					f.seek_end()
					f.store_line(JSON.stringify(r))
					f.close()
			if reszlet:
				print("  %s #%02d: %s · %d. szint · %d kör" % [cls, i + 1, _veg_szoveg(r), r["plvl"], r["korok"]])
		osszegzes(str(cls), futasok, Time.get_ticks_msec() - t0)
		for r in futasok:
			ossz += 1
			if r["gyozelem"]:
				ossz_gyoz += 1
	if kasztok.size() > 1:
		print("══════ MINDEN KASZT: %d / %d végigjátszás (%.1f%%) ══════" % [ossz_gyoz, ossz, 100.0 * ossz_gyoz / maxi(1, ossz)])
	SaveGame.erase_all()
	quit(0)


## A --ki=fájl kapcsolóval mentett futások (soronként egy JSON) összesítése: több részletben,
## több folyamatban futtatott mérés is összerakható (a fájlok vesszővel elválasztva).
func _osszesit(fajlok: String) -> void:
	var kaszt := {}
	var latott := {}
	for ut_ in fajlok.split(","):
		if not FileAccess.file_exists(ut_):
			print("  nincs ilyen fájl: ", ut_)
			continue
		for sor in FileAccess.get_file_as_string(ut_).split("\n"):
			if sor.strip_edges() == "":
				continue
			var j := JSON.new()
			if j.parse(sor) != OK or not (j.data is Dictionary):
				continue
			var r: Dictionary = j.data
			var kulcs := "%s|%d|%d" % [r["cls"], int(r.get("mag", 0)), int(r.get("i", 0))]
			if latott.has(kulcs):
				continue    # ugyanaz a futás kétszer (újraindított mérés)
			latott[kulcs] = true
			if not kaszt.has(r["cls"]):
				kaszt[r["cls"]] = []
			(kaszt[r["cls"]] as Array).append(r)
	var ossz := 0
	var gyoz := 0
	for cls in Data.CLASS_ORDER + Data.EXTRA_CLASSES:
		if not kaszt.has(cls):
			continue
		var l: Array = kaszt[cls]
		osszegzes(str(cls), l, 0)
		for r in l:
			ossz += 1
			if r["gyozelem"]:
				gyoz += 1
	print("══════ MINDEN KASZT: %d / %d végigjátszás (%.1f%%) ══════" % [gyoz, ossz, 100.0 * gyoz / maxi(1, ossz)])


# ══════════ EGY KALAND ══════════
func _szakasz(w: World) -> int:
	var s := 0
	for z in range(1, w.dungeon_level):
		s += Data.emeletek(z)
	return s + w.emelet


func _uj_emelet(g: Game) -> void:
	ut = []
	ut_cel = -1
	ut_tipus = ""
	bolt_volt = {}
	kihagy = {}
	mellozott = {}
	var_kor = 0
	uldoz = null
	uldoz_ut = []
	uldoz_lepes = 0
	uldoz_ossz = {}
	fo = null
	fo_rec = {}
	mini = null
	mini_rec = {}
	for m in g.world.mons:
		if m.boss:
			fo = m
		elif m.mini:
			mini = m


func egy_futas(cls: String, diff: String) -> Dictionary:
	Meta.reset()
	var g := Game.new()
	g.autosave = false
	g.start(cls, diff)
	var p := g.player
	var r := {"cls": cls, "gyozelem": false, "elakadt": false, "zona": 1, "emelet": 1, "szakasz": 1, "plvl": 1,
		"korok": 0, "ok": "", "fok": {}, "minik": {}, "szint_belepeskor": {}}
	ital_db = 0
	_uj_emelet(g)
	r["szint_belepeskor"]["1"] = [1, maxi(p.atk, p.mag), p.def, p.max_hp]
	var korok := 0
	var allo := 0
	while p.alive:
		var w := g.world
		var kor0 := w.turn
		_fuggok(g)
		if not p.alive:
			break
		if ut_tipus == "lepcso" and g.can_descend() and _nincs_latott(g):
			korok += w.turn
			_zar(r, g, true)
			if g.next_level():
				r["gyozelem"] = true
				break
			_uj_emelet(g)
			r["szint_belepeskor"][str(_szakasz(g.world))] = [p.plvl, maxi(p.atk, p.mag), p.def, p.max_hp]
			continue
		_lep(g)
		_figyel(r, g)
		g.fx.clear()
		g.shake = 0.0
		if w.turn == kor0:
			allo += 1
			if allo > 40:      # semmi nem történik: teljen egy kör (kutatás)
				g.search()
				allo = 0
		else:
			allo = 0
		if w.turn > KOR_PLAFON:
			r["elakadt"] = true
			if reszlet:
				var ls := ""
				for m in _latott(g):
					ls += " %s(%d,%d hp%d)" % [m.key, m.x, m.y, m.hp]
				print("    ELAKADT: hős %d,%d hp %d/%d gyökér %d · út: %s (%d) · lát:%s · mellőzött: %d · kihagy: %d" % [
					p.x, p.y, p.hp, p.max_hp, p.rooted, ut_tipus, ut.size(), ls, mellozott.size(), kihagy.size()])
				if csak >= 0:
					print("      nyom: ", " | ".join(nyom))
					var gs := ""
					for ge in w.gepek:
						if absi(int(ge["x"]) - p.x) < 9 and absi(int(ge["y"]) - p.y) < 9:
							gs += " %s(%d,%d n%d d%d,%d)" % [ge["tip"], ge["x"], ge["y"], ge["n"], ge["dx"], ge["dy"]]
					print("      cél: %d,%d · út: %s · gépek:%s · veszély: %s · ládák: %s" % [int(ut_cel / MH), ut_cel % MH, str(ut), gs,
						str(_veszely(g).keys().map(func(k: int) -> String: return "%d,%d" % [int(k / MH), k % MH])),
						str(w.chests.filter(func(c: Dictionary) -> bool: return not c["opened"] and absi(int(c["x"]) - p.x) < 9 and absi(int(c["y"]) - p.y) < 9).map(func(c: Dictionary) -> String: return "%d,%d%s" % [c["x"], c["y"], " zárt" if c.get("zart", false) else ""]))])
					print("      lapok: %s · szentély/esemény/talapzat a közelben: %s %s %s" % [str(w.lapok), str(w.shrines.filter(func(s: Dictionary) -> bool: return not s["used"])), str(w.events.filter(func(e: Dictionary) -> bool: return not e["used"])), str(w.pedestals)])
			break
	var w2 := g.world
	if not r["gyozelem"]:
		korok += w2.turn
		_zar(r, g, false)
	r["zona"] = w2.dungeon_level
	r["emelet"] = w2.emelet
	r["szakasz"] = _szakasz(w2)
	r["plvl"] = p.plvl
	r["korok"] = korok
	if not p.alive:
		if fo != null and fo.alive and fo.met:
			r["ok"] = "főellenség"
		elif mini != null and mini.alive and mini.awake and maxi(absi(mini.x - p.x), absi(mini.y - p.y)) <= 3:
			r["ok"] = "mini-boss"
		else:
			r["ok"] = "szörnyek"
		if reszlet and csak >= 0:
			# hibakeresés: az utolsó üzenetek (mi végzett a hőssel?)
			for uz in p.msgs:
				print("      · ", Lang.txt(uz["t"]))
	return r


## A főellenség / mini-boss elleni harc követése: mikor kezdődött, mikor és hogyan ért véget.
func _figyel(r: Dictionary, g: Game) -> void:
	var p := g.player
	var w := g.world
	if fo != null:
		if fo_rec.is_empty() and fo.met:
			fo_rec = {"plvl": p.plvl, "kor0": w.turn, "elet0": p.lives, "ital0": ital_db, "le": false, "tam": maxi(p.atk, p.mag), "ved": p.def, "mhp": p.max_hp, "keszlet": _italok(p)}
		if not fo_rec.is_empty() and not fo_rec["le"] and not fo.alive:
			fo_rec["le"] = true
			fo_rec["korok"] = w.turn - int(fo_rec["kor0"])
			fo_rec["hp"] = float(maxi(0, p.hp)) / p.max_hp
			fo_rec["elet"] = int(fo_rec["elet0"]) - p.lives
			fo_rec["ital"] = ital_db - int(fo_rec["ital0"])
			r["fok"][str(w.dungeon_level)] = fo_rec
	if mini != null:
		if mini_rec.is_empty() and mini.awake:
			mini_rec = {"plvl": p.plvl, "kor0": w.turn, "elet0": p.lives, "ital0": ital_db, "le": false, "tam": maxi(p.atk, p.mag), "ved": p.def, "mhp": p.max_hp, "keszlet": _italok(p)}
		if not mini_rec.is_empty() and not mini_rec["le"] and not mini.alive:
			mini_rec["le"] = true
			mini_rec["korok"] = w.turn - int(mini_rec["kor0"])
			mini_rec["hp"] = float(maxi(0, p.hp)) / p.max_hp
			mini_rec["elet"] = int(mini_rec["elet0"]) - p.lives
			mini_rec["ital"] = ital_db - int(mini_rec["ital0"])
			r["minik"]["%d/%d" % [w.dungeon_level, w.emelet]] = mini_rec


## Az emelet lezárása: a félbemaradt (elvesztett) harcok is bekerülnek a mérésbe.
func _zar(r: Dictionary, g: Game, _tovabb: bool) -> void:
	var p := g.player
	var w := g.world
	if fo != null and not fo_rec.is_empty() and not fo_rec["le"]:
		fo_rec["korok"] = w.turn - int(fo_rec["kor0"])
		fo_rec["hp"] = 0.0
		fo_rec["elet"] = int(fo_rec["elet0"]) - p.lives
		fo_rec["ital"] = ital_db - int(fo_rec["ital0"])
		fo_rec["maradt"] = float(maxi(0, fo.hp)) / fo.max_hp
		r["fok"][str(w.dungeon_level)] = fo_rec
	if mini != null and not mini_rec.is_empty() and not mini_rec["le"]:
		mini_rec["korok"] = w.turn - int(mini_rec["kor0"])
		mini_rec["hp"] = 0.0
		mini_rec["elet"] = int(mini_rec["elet0"]) - p.lives
		mini_rec["ital"] = ital_db - int(mini_rec["ital0"])
		r["minik"]["%d/%d" % [w.dungeon_level, w.emelet]] = mini_rec


# ══════════ VÁLASZTÁSOK (láda, képesség, ereklye, esemény, kereskedő) ══════════
func _italok(p: Player) -> int:
	var n := 0
	for it in p.inventory:
		if it.subtype == "heal":
			n += 1
	return n


func _fegyver_pont(p: Player, it: Item) -> float:
	if it == null:
		return 0.0
	var s := float(it.dmg)
	match p.cls:
		"Íjász":
			if it.reach > 0:
				s = it.dmg * (1.36 if it.subtype == "bow" else 1.0) + it.reach * 1.5
			else:
				s = it.dmg * 0.3
		"Lovag", "Sebész":
			s = it.dmg * (1.3 if it.reach == 0 else 1.1)
	return s + it.lifesteal * 40.0


func _vert_pont(it: Item) -> float:
	return 0.0 if it == null else float(it.def) + it.regen * 3.0


## Mennyit ér a hősnek egy tárgy (a ládából a nagyobb értékűt veszi el).
func _ertek(p: Player, it: Item) -> float:
	match it.slot:
		"weapon":
			var gy := _fegyver_pont(p, it) - _fegyver_pont(p, p.weapon)
			return 4.0 + gy * 2.0 if gy > 0.0 else 0.5
		"armor":
			var gy := _vert_pont(it) - _vert_pont(p.armor)
			return 4.0 + gy * 2.0 if gy > 0.0 else 0.5
		"shield":
			var gy := _vert_pont(it) - _vert_pont(p.shield)
			return 4.0 + gy * 2.0 if gy > 0.0 else 0.5
	match it.subtype:
		"heal": return 7.0 + (4.0 if _italok(p) < 2 else 0.0) + it.heal * 0.03
		"maxheal": return 9.0
		"atk_up": return 8.0 + it.atk_up * 0.5
		"def_up": return 7.0 + it.def_up * 0.5
		"fireball": return 5.0
	return 0.0


## A táska rendezése: a jobb felszerelést felveszi, a tekercseket felolvassa.
func _rendez(g: Game) -> void:
	var p := g.player
	for it in p.inventory.duplicate():
		match it.slot:
			"weapon":
				if _fegyver_pont(p, it) > _fegyver_pont(p, p.weapon):
					g.equip(it)
			"armor":
				if _vert_pont(it) > _vert_pont(p.armor):
					g.equip(it)
			"shield":
				if _vert_pont(it) > _vert_pont(p.shield):
					g.equip(it)
			_:
				if it.subtype == "atk_up" or it.subtype == "def_up":
					g.use_item(it)


func _fuggok(g: Game) -> void:
	var p := g.player
	g.pending_dialog = []
	g.pending_note = ""
	g.banner = {}
	Meta.uj_jelvenyek.clear()
	if g.pending_relic:
		g.pending_relic = false
		var rids := Relics.offer(p)
		if rids.is_empty():
			g.relic_fallback()
		else:
			g.take_relic(str(rids[0]))
	if g.pending_event != null:
		var e: Dictionary = g.pending_event
		g.pending_event = null
		var v := 0
		if str(e["kind"]) == "verautomata" and p.hp < p.max_hp * 0.6:
			v = 1
		g.event_choice(e, v)
	if g.pending_chest != null:
		var ch: Dictionary = g.pending_chest
		g.pending_chest = null
		var a := _ertek(p, ch["items"][0])
		var b := _ertek(p, ch["items"][1])
		g.take_chest_item(ch, 0 if a >= b else 1)
		_rendez(g)
	if g.pending_shop != null:
		var sh: Dictionary = g.pending_shop
		g.pending_shop = null
		_vasarol(g, sh)
	while g.pending_perks > 0:
		var ids := Perks.offer(p)
		if ids.is_empty():
			g.pending_perks = 0
			break
		var sorrend: Array = PERK_SORREND.get(p.cls, PERK_SORREND["Lovag"])
		var legjobb := str(ids[0])
		var hely := 999
		for id in ids:
			var h := sorrend.find(str(id))
			if h >= 0 and h < hely:
				hely = h
				legjobb = str(id)
		Perks.apply(p, legjobb)
		g.pending_perks -= 1


func _vasarol(g: Game, sh: Dictionary) -> void:
	var p := g.player
	bolt_volt[Dungeon.idx(sh["x"], sh["y"])] = true
	var stock: Array = sh["stock"]
	for i in stock.size():
		var s: Dictionary = stock[i]
		if s["sold"] or p.gold < int(s["price"]):
			continue
		if str(s["kind"]) == "heal":
			if p.hp < p.max_hp * 0.6:
				g.buy(sh, i)
		elif s["item"] != null and _ertek(p, s["item"]) >= 6.0:
			g.buy(sh, i)
	_rendez(g)


# ══════════ SEGÉDEK ══════════
## Melyik szörnyet érné a hős támadása, ha az (x, y) mezőről a (dx, dy) irányba indulna
## (lövés a lőtávon belül, különben a szomszédos mező ütése). null: senkit.
func _vonalban(g: Game, x: int, y: int, dx: int, dy: int) -> Mon:
	var w := g.world
	var rng := g.ranged_range()
	if rng >= 2:
		var mage := g.player.cls == "Mágus"
		for d in range(1, rng + 1):
			var tx := x + dx * d
			var ty := y + dy * d
			if w.blocked(tx, ty):
				break
			var m := w.mon_at(tx, ty)
			if m == null:
				continue
			if d == 1 and not mage:
				return m    # szomszédos: közelharc
			return m
		return null
	if w.blocked(x + dx, y + dy):
		return null
	return w.mon_at(x + dx, y + dy)


func _tamadhato_innen(g: Game, x: int, y: int) -> bool:
	for d in DIRS4:
		if _vonalban(g, x, y, d.x, d.y) != null:
			return true
	return false


func _szabad(g: Game, x: int, y: int) -> bool:
	var w := g.world
	return not w.blocked(x, y) and w.mon_at(x, y) == null and w.chest_at(x, y) == null


## Nincs a mezőn (ismert) veszély: jelzett csapás, tócsa, felfedezett csapda, bármi, amit a
## pálya saját elemei veszélyesnek jeleznek.
func _biztos(g: Game, x: int, y: int) -> bool:
	var w := g.world
	if w.hazard_at(x, y) != null:
		return false
	var t: Variant = w.trap_at(x, y)
	if t != null and t["found"] and not t["sprung"]:
		return false
	if _veszely(g).has(x * MH + y):
		return false
	return true


## a pálya gépeinek veszélyes mezői (körönként egyszer számoljuk ki)
func _veszely(g: Game) -> Dictionary:
	var w := g.world
	if _vm_w != w or _vm_kor != w.turn:
		_vm = w.veszely_mezok()
		_vm_w = w
		_vm_kor = w.turn
	return _vm


func _ugras_vege(g: Game, d: Vector2i) -> Vector2i:
	var p := g.player
	var nx := p.x
	var ny := p.y
	for i in p.dash_len:
		if not _szabad(g, nx + d.x, ny + d.y):
			break
		nx += d.x
		ny += d.y
	return Vector2i(nx, ny)


func _latott(g: Game) -> Array[Mon]:
	var out: Array[Mon] = []
	var w := g.world
	for m in w.mons:
		if m.alive and w.is_vis(m.x, m.y) and not mellozott.has(m):
			out.append(m)
	return out


func _nincs_latott(g: Game) -> bool:
	return _latott(g).is_empty()


func _tav(g: Game, m: Mon) -> int:
	return maxi(absi(m.x - g.player.x), absi(m.y - g.player.y))


## Szélességi keresés a hőstől a felderített mezőkön. A `celok` valamelyikéig megy; ha
## `hatar` igaz, a legközelebbi még felderítetlen (de járható) mezőig. `ovatos`: az ismert
## veszélyeket kerüli. Az útvonal a hős mezője nélkül, a céllal együtt jön vissza.
func _ut_keres(g: Game, celok: Dictionary, hatar: bool, ovatos: bool, szornyek: bool) -> Array[Vector2i]:
	var w := g.world
	var p := g.player
	var n := MW * MH
	var tilos := {}
	for c in w.chests:
		if not c["opened"]:
			tilos[c["x"] * MH + c["y"]] = true
	if szornyek:
		for m in w.mons:
			if m.alive and w.is_vis(m.x, m.y):
				tilos[m.x * MH + m.y] = true
	if ovatos:
		for t in w.traps:
			if t["found"] and not t["sprung"]:
				tilos[t["x"] * MH + t["y"]] = true
		for v in w.vents:
			tilos[v["x"] * MH + v["y"]] = true
		for h in w.hazards:
			tilos[h["x"] * MH + h["y"]] = true
		for k in _veszely(g):
			tilos[k] = true
	_dist.fill(-1)
	var start := p.x * MH + p.y
	_dist[start] = 0
	var fej := 0
	var veg := 0
	_sor[veg] = start
	veg += 1
	var talalt := -1
	while fej < veg and talalt < 0:
		var i := _sor[fej]
		fej += 1
		var y := i % MH
		for k in 4:
			var j := i + MH
			if k == 1:
				j = i - MH
			elif k == 2:
				if y + 1 >= MH:
					continue
				j = i + 1
			elif k == 3:
				if y <= 0:
					continue
				j = i - 1
			if j < 0 or j >= n or _dist[j] >= 0:
				continue
			var t := w.tiles[j]
			if t == Data.WALL or t == Data.SECRET:
				continue
			if celok.has(j):
				_szulo[j] = i
				talalt = j
				break
			if w.explored[j] == 0:
				if hatar and not kihagy.has(j):
					_szulo[j] = i
					talalt = j
					break
				continue
			if tilos.has(j):
				continue
			_dist[j] = _dist[i] + 1
			_szulo[j] = i
			_sor[veg] = j
			veg += 1
	var out: Array[Vector2i] = []
	if talalt < 0:
		return out
	var c := talalt
	while c != start:
		out.append(Vector2i(int(c / MH), c % MH))
		c = _szulo[c]
	out.reverse()
	return out


# ══════════ EGY DÖNTÉS ══════════
func _lep(g: Game) -> void:
	var p := g.player
	var w := g.world
	if p.stun > 0:
		g.do_move(p.dir_x, p.dir_y)   # kábult: a köre kimarad
		return
	if _kiter(g):
		return
	var latok := _latott(g)
	_gyogyit(g, latok)
	if not latok.is_empty():
		ut = []
		_ny(g, "harc (%d)" % latok.size())
		_harc(g, latok)
		return
	# akit az előbb még látott, azt nem felejti el: odamegy, ahol utoljára állt
	if uldoz != null and uldoz.alive and not uldoz_ut.is_empty() and p.rooted == 0 and not mellozott.has(uldoz):
		var k: Vector2i = uldoz_ut[0]
		if absi(k.x - p.x) + absi(k.y - p.y) == 1 and _szabad(g, k.x, k.y):
			uldoz_ut.remove_at(0)
			uldoz_lepes += 1
			if uldoz_lepes > 60:
				mellozott[uldoz] = true
			if g.do_move(k.x - p.x, k.y - p.y):
				return
	uldoz = null
	uldoz_ut = []
	_felderit(g)


## Jelzett csapás vagy tócsa a hős alatt: félreugrik (nem telik vele kör), vagy kilép belőle.
func _kiter(g: Game) -> bool:
	var p := g.player
	var w := g.world
	# csak a már jelzett csapás / tócsa elől tér ki; a gépek „nem tanácsos belépni” mezőin (pl. a
	# gőzzsilip közepén, átkelés közben) nem fordul vissza
	if w.hazard_at(p.x, p.y) == null or p.rooted > 0:
		return false
	var legjobb := Vector2i.ZERO
	var pont := 0.0
	var ugras := false
	# ha épp egy láda előtt áll, előbb kinyitja (nem telik vele kör), és csak utána lép el
	if not ut.is_empty() and absi(ut[0].x - p.x) + absi(ut[0].y - p.y) == 1:
		var lc: Variant = w.chest_at(ut[0].x, ut[0].y)
		if lc != null and not lc.get("zart", false):
			var cel := ut[0]
			ut = []
			return g.do_move(cel.x - p.x, cel.y - p.y)
	for d in DIRS4:
		var tx := p.x + d.x
		var ty := p.y + d.y
		if _szabad(g, tx, ty) and _biztos(g, tx, ty) and _vonalban(g, p.x, p.y, d.x, d.y) == null:
			var s := 2.0 if _tamadhato_innen(g, tx, ty) else 1.0
			if not ut.is_empty() and ut[0] == Vector2i(tx, ty):
				s = 4.0    # arra megy tovább, amerre amúgy is tartott
			if s > pont:
				pont = s
				legjobb = d
				ugras = false
		if p.dash_cd == 0:
			var q := _ugras_vege(g, d)
			if (q.x != p.x or q.y != p.y) and _biztos(g, q.x, q.y):
				var s2 := 3.0 if _tamadhato_innen(g, q.x, q.y) else 1.5
				if s2 > pont:
					pont = s2
					legjobb = d
					ugras = true
	if pont <= 0.0:
		return false
	_ny(g, "kitér %s ugrás=%s" % [str(legjobb), str(ugras)])
	ut = []
	if ugras:
		p.dir_x = legjobb.x
		p.dir_y = legjobb.y
		return g.dash()
	return g.do_move(legjobb.x, legjobb.y)


func _gyogyit(g: Game, latok: Array[Mon]) -> void:
	var p := g.player
	var nagy := 0
	for m in latok:
		nagy = maxi(nagy, m.atk)
	var hatar := maxf(p.max_hp * 0.42, nagy * 1.3)
	if latok.is_empty():
		hatar = p.max_hp * 0.42
	for i in 4:
		if p.hp > hatar or p.hp >= p.max_hp:
			return
		if g.quick_heal():
			ital_db += 1
			continue
		var elix: Item = null
		for it in p.inventory:
			if it.subtype == "maxheal":
				elix = it
				break
		if elix == null:
			return
		g.use_item(elix)
		ital_db += 1


func _harc(g: Game, latok: Array[Mon]) -> void:
	var p := g.player
	var w := g.world
	# tűzgömb-tekercs: ha sokan vannak, vagy erős ellenfél áll szemben
	var eros := false
	for m in latok:
		if m.boss or m.mini:
			eros = true
	if latok.size() >= 3 or eros:
		for it in p.inventory:
			if it.subtype == "fireball":
				g.use_item(it)
				return
	# a kaszt képessége
	if p.skill_cd == 0 and _kepesseg(g, latok):
		return
	# kit lehet innen megtámadni?
	var cel: Mon = null
	var irany := Vector2i.ZERO
	for d in DIRS4:
		var m := _vonalban(g, p.x, p.y, d.x, d.y)
		if m == null or mellozott.has(m):
			continue
		if cel == null or m.hp < cel.hp:
			cel = m
			irany = d
	if cel != null:
		uldoz_ossz.erase(cel)
		# az íjász közelről gyenge: ha tud, elugrik az ellenség mellől (a következő körben lő)
		if p.cls == "Íjász" and _tav(g, cel) <= 1 and p.dash_cd == 0 and p.rooted == 0 and g.ranged_range() >= 2:
			var el := Vector2i(-irany.x, -irany.y)
			var q := _ugras_vege(g, el)
			if absi(q.x - p.x) + absi(q.y - p.y) >= 2 and _biztos(g, q.x, q.y):
				p.dir_x = el.x
				p.dir_y = el.y
				if g.dash():
					return
		var_kor = 0
		g.do_move(irany.x, irany.y)
		return
	# senki nincs vonalban: odamegy, ahonnan a legközelebbi támadható
	var kozel: Mon = null
	if uldoz != null and uldoz.alive and uldoz in latok:
		kozel = uldoz    # nem kapkod: akit kinézett, azt üldözi tovább
	else:
		for m in latok:
			if kozel == null or _tav(g, m) < _tav(g, kozel) or (_tav(g, m) == _tav(g, kozel) and m.hp < kozel.hp):
				kozel = m
	# aki után túl sokáig hiába megy (nem lehet odajutni), azt békén hagyja
	uldoz_ossz[kozel] = int(uldoz_ossz.get(kozel, 0)) + 1
	if int(uldoz_ossz[kozel]) > 150:
		mellozott[kozel] = true
		uldoz = null
		g.search()
		return
	var rng := maxi(1, g.ranged_range())
	var celok := {}
	for d in DIRS4:
		for k in range(1, rng + 1):
			var tx := kozel.x + d.x * k
			var ty := kozel.y + d.y * k
			if w.blocked(tx, ty) or w.mon_at(tx, ty) != null:
				break
			if w.chest_at(tx, ty) == null:
				celok[tx * MH + ty] = true
	var u: Array[Vector2i] = []
	if p.rooted == 0 and not celok.is_empty():
		u = _ut_keres(g, celok, false, true, true)
		if u.is_empty():
			u = _ut_keres(g, celok, false, false, true)
	if u.is_empty():
		# nem lehet odajutni (vagy gyökerek fogják): vár egy kört
		var_kor += 1
		if var_kor > 25:
			mellozott[kozel] = true
			var_kor = 0
		g.search()
		return
	var_kor = 0
	if uldoz != kozel:
		uldoz = kozel
		uldoz_lepes = 0
	uldoz_ut = u.slice(1)
	g.do_move(u[0].x - p.x, u[0].y - p.y)


func _kepesseg(g: Game, latok: Array[Mon]) -> bool:
	var p := g.player
	var w := g.world
	match p.cls:
		"Lovag":
			var n := 0
			var nagy := false
			for m in latok:
				if _tav(g, m) <= 1:
					n += 1
					if m.hp > p.atk * 1.5 or m.boss or m.mini:
						nagy = true
			if n >= 2 or (n >= 1 and nagy):
				return g.skill()
		"Mágus":
			var n := 0
			var nagy := false
			for m in latok:
				if absi(m.x - p.x) <= 2 and absi(m.y - p.y) <= 2:
					n += 1
					if m.hp > p.mag or m.boss or m.mini:
						nagy = true
			if n >= 2 or (n >= 1 and nagy):
				return g.skill()
		"Íjász":
			var rng := maxi(4, g.ranged_range() + 1)
			var legjobb := Vector2i.ZERO
			var legtobb := 0
			for d in DIRS4:
				var n := 0
				var nagy := false
				for k in range(1, rng + 1):
					var tx := p.x + d.x * k
					var ty := p.y + d.y * k
					if w.blocked(tx, ty):
						break
					var m := w.mon_at(tx, ty)
					if m != null:
						n += 1
						if m.hp > p.atk or m.boss or m.mini:
							nagy = true
				if (n >= 2 or (n >= 1 and nagy)) and n > legtobb:
					legtobb = n
					legjobb = d
			if legtobb > 0:
				p.dir_x = legjobb.x
				p.dir_y = legjobb.y
				return g.skill()
		"Sebész":
			if p.organs > 0 and p.hp < p.max_hp * 0.6:
				return g.skill()
			for m in latok:
				if _tav(g, m) <= 1 and absi(m.x - p.x) + absi(m.y - p.y) == 1 and p.organs == 0:
					p.dir_x = m.x - p.x
					p.dir_y = m.y - p.y
					return g.skill()
	return false


## Nincs látható ellenség: ládák, szentély, talapzat, esemény, kereskedő, aztán a felderítetlen
## részek, végül a lépcső.
func _felderit(g: Game) -> void:
	var p := g.player
	var w := g.world
	# a megkezdett útvonal folytatása
	if not ut.is_empty():
		var ervenyes := true
		if ut_tipus == "hatar" and ut_lepes >= 4 and w.explored[ut_cel] == 1:
			ervenyes = false
		var k: Vector2i = ut[0]
		if absi(k.x - p.x) + absi(k.y - p.y) != 1 or w.blocked(k.x, k.y) or w.mon_at(k.x, k.y) != null:
			ervenyes = false
		elif ut.size() > 1 and w.chest_at(k.x, k.y) != null:
			ervenyes = false
		elif ut.size() > 1 and not _biztos(g, k.x, k.y):
			# a következő mező épp villog (egy kör múlva kitör, aztán szabad): megvárja, nem tervez újra
			var hz: Variant = w.hazard_at(k.x, k.y)
			if hz != null and hz["warn"] and ut_var < 3:
				ut_var += 1
				_ny(g, "vár a villogó mező előtt %s" % str(k))
				g.search()
				return
			ervenyes = false
		_ny(g, "követ %s érv=%s" % [str(k), str(ervenyes)])
		if ervenyes:
			ut.remove_at(0)
			ut_lepes += 1
			ut_var = 0
			if not g.do_move(k.x - p.x, k.y - p.y):
				ut = []
			return
		ut = []
	if p.rooted > 0:
		g.search()
		return
	# 1. hasznos dolgok, amiket a hős már látott
	var celok := {}
	for c in w.chests:
		if not c["opened"] and not c.get("zart", false) and w.is_exp(c["x"], c["y"]):
			celok[c["x"] * MH + c["y"]] = true
	for s in w.shrines:
		if not s["used"] and w.is_exp(s["x"], s["y"]):
			celok[s["x"] * MH + s["y"]] = true
	for e in w.pedestals:
		if not e["taken"] and w.is_exp(e["x"], e["y"]):
			celok[e["x"] * MH + e["y"]] = true
	for e in w.events:
		if not e["used"] and w.is_exp(e["x"], e["y"]):
			celok[e["x"] * MH + e["y"]] = true
	if p.gold >= 15:
		for s in w.shops:
			var sk: int = s["x"] * MH + s["y"]
			if not bolt_volt.has(sk) and w.is_exp(s["x"], s["y"]):
				celok[sk] = true
	for k2 in w.robot_celok():
		celok[k2] = true
	for k3 in kihagy:
		celok.erase(k3)
	celok.erase(p.x * MH + p.y)
	var u: Array[Vector2i] = []
	var tipus := "targy"
	if not celok.is_empty():
		u = _ut_keres(g, celok, false, true, false)
		if u.is_empty():
			u = _ut_keres(g, celok, false, false, false)
		if u.is_empty():
			for k4 in celok:
				kihagy[k4] = true    # egyik sem érhető el: többet nem próbálja
	# 2. a legközelebbi felderítetlen mező
	if u.is_empty():
		tipus = "hatar"
		u = _ut_keres(g, {}, true, true, false)
		if u.is_empty():
			u = _ut_keres(g, {}, true, false, false)
	# 3. a lépcső
	if u.is_empty():
		tipus = "lepcso"
		var st := Dungeon.center(w.rooms[w.rooms.size() - 1])
		if p.x == st.x and p.y == st.y:
			ut_tipus = "lepcso"
			if not g.can_descend():
				g.search()    # a zóna ura még él valahol: várunk
			return
		var lc := {st.x * MH + st.y: true}
		u = _ut_keres(g, lc, false, true, false)
		if u.is_empty():
			u = _ut_keres(g, lc, false, false, false)
	if u.is_empty():
		g.search()
		return
	# ütemre járó gép (gőzzsilip, forgó korong) állja az utat: kivárja, amíg szabad lesz
	var ek: int = u[0].x * MH + u[0].y
	if _veszely(g).get(ek, false) and not _veszely(g).has(p.x * MH + p.y) and kivar < 14:
		kivar += 1
		g.search()
		return
	kivar = 0
	_ny(g, "új út (%s): %s" % [tipus, str(u.slice(0, 4))])
	ut = u
	ut_tipus = tipus
	ut_cel = u[u.size() - 1].x * MH + u[u.size() - 1].y
	ut_lepes = 0
	var elso: Vector2i = ut[0]
	ut.remove_at(0)
	ut_lepes = 1
	if not g.do_move(elso.x - p.x, elso.y - p.y):
		kihagy[ut_cel] = true
		ut = []
		g.search()


# ══════════ ÖSSZEGZÉS ══════════
func _veg_szoveg(r: Dictionary) -> String:
	if r["gyozelem"]:
		return "VÉGIGJÁTSZOTTA"
	if r["elakadt"]:
		return "elakadt (%d. zóna %d. emelet)" % [r["zona"], r["emelet"]]
	return "elesett: %d. zóna %d. emelet (%s)" % [r["zona"], r["emelet"], r["ok"]]


func _atlag(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[int(b.size() / 2)])


func _harc_sor(nev: String, recs: Array, futas: int) -> String:
	var le: Array = []
	for x in recs:
		if x["le"]:
			le.append(x)
	var szint: Array = []
	var tam: Array = []
	var ved: Array = []
	var mhp: Array = []
	var keszlet: Array = []
	for x in recs:
		keszlet.append(x.get("keszlet", 0))
		szint.append(x["plvl"])
		tam.append(x["tam"])
		ved.append(x["ved"])
		mhp.append(x["mhp"])
	if recs.is_empty():
		return "  %-22s senki nem jutott el idáig" % nev
	var korok: Array = []
	var hp: Array = []
	var elet: Array = []
	var ital: Array = []
	var sertetlen := 0
	for x in le:
		korok.append(x["korok"])
		hp.append(float(x["hp"]) * 100.0)
		elet.append(x["elet"])
		ital.append(x["ital"])
		if float(x["hp"]) >= 0.8 and int(x["elet"]) <= 0 and int(x["ital"]) == 0:
			sertetlen += 1
	var maradt: Array = []
	for x in recs:
		if not x["le"]:
			maradt.append(float(x.get("maradt", 1.0)) * 100.0)
	var s := "  %-22s elérte %2d/%d · legyőzte %2d (%3.0f%%) · hős szintje átl. %4.1f" % [nev, recs.size(), futas, le.size(),
		100.0 * le.size() / recs.size(), _atlag(szint)]
	s += " (tám. %.0f · véd. %.0f [%.0f–%.0f] · max HP %.0f · %.1f gyógyital)" % [_atlag(tam), _atlag(ved), ved.min(), ved.max(), _atlag(mhp), _atlag(keszlet)]
	if not le.is_empty():
		s += " · harc: átl. %4.1f kör (medián %.0f) · HP a végén átl. %3.0f%% · elvesztett élet átl. %.2f · ital átl. %.1f · sértetlenül: %d" % [
			_atlag(korok), _median(korok), _atlag(hp), _atlag(elet), _atlag(ital), sertetlen]
	if not maradt.is_empty():
		s += " · a vesztes harcokban a főellenségnek átl. %.0f%% HP-ja maradt" % _atlag(maradt)
	return s


func osszegzes(cls: String, futasok: Array, ms: int) -> void:
	var n := futasok.size()
	var gyoz := 0
	var elak := 0
	var szakasz_db := Data.palyak()
	var elert := []
	elert.resize(szakasz_db + 2)
	elert.fill(0)
	var halal := {}
	var okok := {}
	var korok: Array = []
	var vegszint: Array = []
	for r in futasok:
		korok.append(r["korok"])
		vegszint.append(r["plvl"])
		if r["gyozelem"]:
			gyoz += 1
		elif r["elakadt"]:
			elak += 1
		else:
			var hk := "%d/%d" % [r["zona"], r["emelet"]]
			halal[hk] = int(halal.get(hk, 0)) + 1
			okok[r["ok"]] = int(okok.get(r["ok"], 0)) + 1
		for s in range(1, int(r["szakasz"]) + 1):
			elert[s] += 1
	print("────── %s: %d futás · %.0f mp ──────" % [cls, n, ms / 1000.0])
	print("  VÉGIGJÁTSZOTTA: %d / %d (%.1f%%)%s · átl. %.0f kör · átl. végső szint %.1f" % [gyoz, n, 100.0 * gyoz / n,
		(" · elakadt: %d" % elak) if elak > 0 else "", _atlag(korok), _atlag(vegszint)])
	# meddig jutott: emeletenként hányan érték el, és hányadik szinten léptek be
	var sor := "  elérte (zóna/emelet: futás, belépő szint):"
	var sor2 := "  a hős belépéskor (támadás/védelem[legkisebb–legnagyobb]/max. életerő, átlag):"
	var s := 0
	for z in range(1, Data.MAX_LEVEL + 1):
		for e in range(1, Data.emeletek(z) + 1):
			s += 1
			var szintek: Array = []
			var vedek: Array = []
			var tamok: Array = []
			var hpk: Array = []
			for r in futasok:
				if (r["szint_belepeskor"] as Dictionary).has(str(s)):
					var hb: Array = r["szint_belepeskor"][str(s)]
					szintek.append(hb[0])
					tamok.append(hb[1])
					vedek.append(hb[2])
					hpk.append(hb[3])
			sor += " %d/%d: %d (%.1f)" % [z, e, elert[s], _atlag(szintek)]
			if not vedek.is_empty():
				sor2 += " %d/%d: %.0f/%.0f[%.0f–%.0f]/%.0f" % [z, e, _atlag(tamok), _atlag(vedek), vedek.min(), vedek.max(), _atlag(hpk)]
	print(sor)
	print(sor2)
	var hl: Array = halal.keys()
	hl.sort()
	var hs := ""
	for k in hl:
		hs += " %s: %d" % [k, halal[k]]
	print("  hol esett el (zóna/emelet: db):%s" % (hs if hs != "" else " sehol"))
	print("  mi végzett vele: %s" % str(okok))
	for z in range(1, Data.MAX_LEVEL + 1):
		var recs: Array = []
		for r in futasok:
			if (r["fok"] as Dictionary).has(str(z)):
				recs.append(r["fok"][str(z)])
		print(_harc_sor("%d. %s" % [z, Lang.T("mon." + str(Data.BOSS_LVL[z]))], recs, n))
	for z in range(1, Data.MAX_LEVEL + 1):
		var recs: Array = []
		for r in futasok:
			for k in (r["minik"] as Dictionary):
				if str(k).begins_with("%d/" % z):
					recs.append(r["minik"][k])
		print(_harc_sor("%d. mini: %s" % [z, Lang.T("mini." + str(Data.MINI[z]))], recs, n))
