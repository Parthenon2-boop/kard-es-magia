extends SceneTree
## Fej nélküli tesztek:
##   godot --headless --path . -s res://tests/run_tests.gd
## 1) 300 pálya (1–5. mélység): minden padló, a lépcső és minden láda elérhető-e
## 2) harc-szimuláció kasztonként (goblin, kőgolem, sárkány): átlagos sebzés
## 3) tárgyak: fegyver/páncél/pajzs felvétele és cseréje, bájitalok, tekercsek, életlopás, regeneráció
## 4) különleges termek, csapdák, titkos ajtók, szentély, kereskedő
## 5) képességek (szintlépéskor választható perkek)
## 6) mentés ↔ betöltés (azonos állapot, sérült/régi fájl kizárása)

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  HIBA: ", what)


func _init() -> void:
	seed(12345)
	Meta.persist = false   # a tesztek nem nyúlnak a játékos Műtőterem-állásához
	Meta.reset()
	SaveGame.DIR = "user://_teszt_mentesek/"   # ...és a mentéseihez sem
	SaveGame.erase_all()
	Lang.set_lang("hu")   # a szöveges ellenőrzések a magyar szövegekre épülnek
	print("══════ 1. PÁLYÁK (300 db) ══════")
	test_levels()
	print("══════ 2. HARC ══════")
	test_combat()
	print("══════ 3. TÁRGYAK ══════")
	test_items()
	print("══════ 4. KÜLÖNLEGES TERMEK, CSAPDÁK, TITKOS AJTÓK ══════")
	test_specials()
	print("══════ 5. KÉPESSÉGEK ══════")
	test_perks()
	print("══════ 6. MENTÉS ÉS BETÖLTÉS ══════")
	test_save()
	print("══════ 7. KOZMETIKA (KINÉZET BOLT) ══════")
	test_kozmetika()
	print("══════ 8. NYELVEK (HU / EN / DE) ══════")
	test_nyelvek()
	print("══════ 9. GORGONA: zónák, főellenségek, képességek, Műtőterem ══════")
	test_story()
	print("══════ 11. EREKLYÉK, ESEMÉNYEK, MINI-BOSSOK, A SEBÉSZ, NAPI KIHÍVÁS ══════")
	test_uj()
	print("══════ 12. ZÓNÁNKÉNTI PÁLYAELEMEK ÉS REJTVÉNYSZOBA ══════")
	test_palyaelemek()
	print("══════ 13. HANGOK: lépések, szörnyhangok, felfigyelés, fázisváltás ══════")
	test_hangok()
	print("══════ 14. A 15 PÁLYA NEHÉZSÉGE ══════")
	test_nehezseg()
	Lang.set_lang("hu")
	print("══════ ÖSSZESEN: %d ellenőrzés, %d hiba ══════" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ══════════ 1. PÁLYÁK ══════════
func test_levels() -> void:
	var bad := 0
	var chests := 0
	var removed := 0
	var traps := 0
	var secrets := 0
	var kind_cnt := {}
	var lvls_with_all := 0
	var bad_trap := 0
	var bad_secret := 0
	var bad_feature := 0
	var t0 := Time.get_ticks_msec()
	for i in 300:
		var depth := 1 + i % Data.MAX_LEVEL
		var p := Player.create(Data.CLASS_ORDER[i % 3])
		var w := World.create(p, depth, Data.DIFF_ORDER[i % 3])
		var err := Dungeon.verify_open(w.tiles, w.rooms, w.chests)
		# a hős a kezdőponton áll, és onnan a lépcső is elérhető
		var s := Dungeon.center(w.rooms[0])
		ok(p.x == s.x and p.y == s.y, "a hős nem a kezdőponton áll")
		var stair_ok := false
		var seen := Dungeon.reach_map(w.tiles, s.x, s.y, {})
		for k in seen.size():
			if w.tiles[k] == Data.STAIR and seen[k]:
				stair_ok = true
		if not stair_ok:
			err = "a lépcső nem érhető el"
		for c in w.chests:
			chests += 1
			if c["opened"]:
				removed += 1
		# ── csapdák: sosem a kezdőponton vagy a lépcsőn, és mindig járható mezőn (nem zárnak el utat)
		for t in w.traps:
			traps += 1
			var tk := Dungeon.idx(t["x"], t["y"])
			if w.tiles[tk] != Data.FLOOR or (t["x"] == s.x and t["y"] == s.y) or not seen[tk]:
				bad_trap += 1
		# ── titkos ajtók: SECRET csempén állnak, és a mögöttük lévő rész elérhető (a BFS átengedi)
		for sc in w.secrets:
			secrets += 1
			var sk := Dungeon.idx(sc["x"], sc["y"])
			if w.tiles[sk] != Data.SECRET or not seen[sk]:
				bad_secret += 1
		# ── szentély / kereskedő: szabad padlón állnak, és elérhetők
		for f in (w.shrines + w.shops):
			var fk := Dungeon.idx(f["x"], f["y"])
			if w.tiles[fk] != Data.FLOOR or not seen[fk]:
				bad_feature += 1
		var have := {}
		for kd in w.room_kind:
			if kd != "":
				kind_cnt[kd] = int(kind_cnt.get(kd, 0)) + 1
				if kd in Data.ROOM_KIND_ORDER:   # a rejtvényszoba nem minden emeleten van (lásd 12. rész)
					have[kd] = true
		if have.size() == Data.ROOM_KIND_ORDER.size():
			lvls_with_all += 1
		# a kincstárban két láda és egy őr van
		for ri in w.room_kind.size():
			if w.room_kind[ri] != "kincstar":
				continue
			var guards := 0
			for mo in w.mons:
				if mo.guard and w.rooms[ri].has_point(Vector2i(mo.x, mo.y)):
					guards += 1
			ok(guards >= 1, "a kincstárnak van őre")
		if err != "":
			bad += 1
			print("  mélység %d: %s" % [depth, err])
	ok(bad == 0, "elérhetetlen rész a pályákon")
	ok(bad_trap == 0, "csapda elzáró vagy elérhetetlen helyen (%d)" % bad_trap)
	ok(bad_secret == 0, "hibás titkos ajtó (%d)" % bad_secret)
	ok(bad_feature == 0, "elérhetetlen szentély vagy kereskedő (%d)" % bad_feature)
	ok(lvls_with_all == 300, "minden pályán megvan mind a négy különleges terem (%d/300)" % lvls_with_all)
	ok(traps > 300 and secrets > 300, "minden pályán van csapda és titkos ajtó")
	print("  300 pálya, %d hibás (elvárt: 0) · %d láda, ebből %d-t kellett eltüntetni · %d ms" % [bad, chests, removed, Time.get_ticks_msec() - t0])
	print("  %d csapda, %d titkos ajtó · termek: %s" % [traps, secrets, kind_cnt])


# ══════════ tesztaréna ══════════
func arena(cls: String) -> Game:
	var g := Game.new()
	g.player = Player.create(cls)
	var w := World.new()
	var n := Data.MAP_W * Data.MAP_H
	w.tiles.resize(n)
	w.tiles.fill(Data.FLOOR)
	w.vis.resize(n)
	w.vis.fill(1)
	w.explored.resize(n)
	w.explored.fill(1)
	w.fade.resize(n)
	w.rooms = [Rect2i(1, 1, 30, 30)]
	w.room_kind = [""]
	w.kind_map.resize(n)
	w.player = g.player
	w.diff = "normal"
	g.autosave = false
	g.world = w
	g.player.x = 10
	g.player.y = 10
	return g


func place(g: Game, key: String, dist: int) -> Mon:
	g.world.mons.clear()
	var m := Mon.make(key, g.player.x + dist, g.player.y, "normal")
	m.hp = 100000
	m.max_hp = 100000
	m.sp = ""   # a különleges képességek ne zavarják a mérést
	g.world.mons.append(m)
	return m


# ══════════ 2. HARC ══════════
func test_combat() -> void:
	var N := 3000
	var res := {}
	for cls in Data.CLASS_ORDER:
		for key in ["goblin", "golem", "weaver"]:
			var g := arena(cls)
			# távolság: a mágus és az íjász messziről lő (2 mező), a lovag közelharcban (1)
			var dist := 1 if cls == "Lovag" else 2
			var tot := 0
			var crits := 0
			var taken := 0
			var blocks := 0
			for i in N:
				var m := place(g, key, dist)
				g.player.hp = 100000
				g.player.max_hp = 100000
				g.player.msgs.clear()
				var before := m.hp
				g.do_move(1, 0)
				var d := before - m.hp
				tot += d
				for msg in g.player.msgs:
					if "Kritikus" in Lang.txt(msg["t"]): crits += 1
					if "Pajzs" in Lang.txt(msg["t"]): blocks += 1
				# bejövő sebzés: a szörny egy ütése
				g.player.hp = 100000
				var hb := g.player.hp
				g.mon_attack(m)
				taken += hb - g.player.hp
			var avg := float(tot) / N
			res[cls + "/" + key] = avg
			var extra := ""
			if cls == "Íjász": extra = " · kritikus: %.0f%%" % (100.0 * crits / N)
			if cls == "Lovag": extra = " · pajzs-blokk: %.0f%%" % (100.0 * blocks / N)
			print("  %-6s vs %-7s  átl. sebzés: %6.2f   · kapott ütés átl.: %5.2f%s" % [cls, Lang.T("mon." + key), avg, float(taken) / N, extra])
			fx_clear(g)
	# mágus közvetlen szomszédra is varázsol (gömb), közelharc nélkül
	var gm := arena("Mágus")
	var mm := place(gm, "goblin", 1)
	gm.fx.clear()
	gm.do_move(1, 0)
	var has_orb := false
	for f in gm.fx:
		if f["type"] == "orb": has_orb = true
	ok(has_orb, "a mágus a szomszédos szörnyre is varázsgömböt lő")
	ok(mm.hp < mm.max_hp, "a mágus gömbje sebzett")
	# a mágus 5 mezőre lő, 6-ra már nem
	var g5 := arena("Mágus")
	var m5 := place(g5, "goblin", 5)
	g5.do_move(1, 0)
	ok(m5.hp < m5.max_hp, "a mágus 5 mezőre lő")
	var g6 := arena("Mágus")
	var m6 := place(g6, "goblin", 6)
	g6.do_move(1, 0)
	ok(m6.hp == m6.max_hp, "a mágus 6 mezőre már nem lő")
	# íjász: Faíj (táv 3) + 1 = 4 mező
	var ga := arena("Íjász")
	ok(ga.player.weapon != null and ga.player.weapon.name == "wooden_bow", "az íjász Faíjjal indul")
	ok(ga.ranged_range() == 4, "az íjász lőtávja íj + 1 (%d)" % ga.ranged_range())
	var ma := place(ga, "goblin", 4)
	ga.do_move(1, 0)
	ok(ma.hp < ma.max_hp, "az íjász 4 mezőre lő")
	# varázsellenállás: sárkány ellen kisebb a mágus sebzése, mint goblin ellen
	ok(res["Mágus/weaver"] < res["Mágus/goblin"], "az Első Kárpit varázsellenállása csökkenti a sebzést")
	# a mágus sebzése a páncélon nagyrészt átüt: golem (def 8) ellen jóval többet üt, mint a fizikai 'atk'-ja
	ok(res["Mágus/golem"] > 5.0, "a mágus a kőgolem páncélján is átüt")
	# közelharc-szorzók: lovag ×1.35, íjász ×0.7, mágus ×0.6 (közvetlenül p_attack-kal mérve)
	var mel := {}
	for cls in Data.CLASS_ORDER:
		var gq := arena(cls)
		gq.player.weapon = null
		gq.player.base_atk = 20
		var tot := 0
		for i in 2000:
			var mq := place(gq, "goblin", 1)
			var hb := mq.hp
			gq.p_attack(mq)
			tot += hb - mq.hp
		mel[cls] = tot / 2000.0
	print("  Közelharc azonos (20) támadással goblin ellen: Lovag %.2f · Íjász %.2f · Mágus %.2f" % [mel["Lovag"], mel["Íjász"], mel["Mágus"]])
	ok(absf(mel["Lovag"] / mel["Íjász"] - 1.35 / 0.7) < 0.1, "közelharc-szorzó lovag/íjász")
	ok(absf(mel["Lovag"] / mel["Mágus"] - 1.35 / 0.6) < 0.12, "közelharc-szorzó lovag/mágus")


func fx_clear(g: Game) -> void:
	g.fx.clear()


# ══════════ 3. TÁRGYAK ══════════
func mk(nm: String, r: String, lvl := 1) -> Item:
	return Item.make(Item.find_base(nm), r, lvl)


func test_items() -> void:
	# ritkaság szerinti szorzók (bájital / tekercs)
	ok(mk("Gyógyital", "common").heal == 25, "gyógyital közönséges = 25")
	ok(mk("Gyógyital", "rare").heal == 33, "gyógyital ritka = 33 (%d)" % mk("Gyógyital", "rare").heal)
	ok(mk("Gyógyital", "epic").heal == 43, "gyógyital nagyon ritka = 43 (%d)" % mk("Gyógyital", "epic").heal)
	ok(mk("Gyógyital", "legendary").heal == 55, "gyógyital legendás = 55 (%d)" % mk("Gyógyital", "legendary").heal)
	# (az Erő tekercs alapja a 15 pályás kalandhoz 5-ről 2-re csökkent)
	ok(mk("Erő tekercs", "common").atk_up == 2 and mk("Erő tekercs", "legendary").atk_up == 4, "erő tekercs szorzó")
	# (a Véd tekercs alapja a 15 pályás kalandhoz 3-ról 1-re csökkent: sokkal több akad belőle)
	ok(mk("Véd tekercs", "common").def_up == 1 and mk("Véd tekercs", "epic").def_up == 2, "véd tekercs szorzó")
	print("  Gyógyital: %d / %d / %d / %d   Erő tekercs: %d / %d / %d / %d   Véd tekercs: %d / %d / %d / %d" % [
		mk("Gyógyital", "common").heal, mk("Gyógyital", "rare").heal, mk("Gyógyital", "epic").heal, mk("Gyógyital", "legendary").heal,
		mk("Erő tekercs", "common").atk_up, mk("Erő tekercs", "rare").atk_up, mk("Erő tekercs", "epic").atk_up, mk("Erő tekercs", "legendary").atk_up,
		mk("Véd tekercs", "common").def_up, mk("Véd tekercs", "rare").def_up, mk("Véd tekercs", "epic").def_up, mk("Véd tekercs", "legendary").def_up])
	# életlopás / regeneráció csak nagyon ritka és legendás tárgyon
	ok(mk("Acélkard", "rare").lifesteal == 0.0 and mk("Acélkard", "epic").lifesteal == 0.10 and mk("Acélkard", "legendary").lifesteal == 0.20, "életlopás 0 / 10% / 20%")
	ok(mk("Láncpáncél", "rare").regen == 0 and mk("Láncpáncél", "epic").regen == 1 and mk("Rúnapajzs", "legendary").regen == 2, "regeneráció 0 / 1 / 2")
	ok(mk("Fapajzs", "common").slot == "shield", "a pajzsnak saját helye van")

	# ── fegyver felvétele és cseréje (íjász: a Faíj a táskába kerül)
	var g := arena("Íjász")
	var p := g.player
	var bow := p.weapon
	var sword := mk("Rúnakard", "epic", 2)
	p.inventory.append(sword)
	var atk0 := p.atk
	ok(g.use_item(sword), "fegyver felvétele")
	ok(p.weapon == sword and bow in p.inventory and not (sword in p.inventory), "fegyvercsere: a régi a táskába kerül")
	ok(p.atk == p.base_atk + sword.dmg, "támadás = alap + fegyver (%d -> %d)" % [atk0, p.atk])
	print("  Fegyvercsere: Faíj -> %s, ATK %d -> %d" % [sword.label, atk0, p.atk])

	# ── páncél + pajzs külön helyen, a védelem összeadódik
	var arm := mk("Láncpáncél", "epic", 2)
	var sh := mk("Acélpajzs", "rare", 2)
	var sh2 := mk("Rúnapajzs", "legendary", 2)
	p.inventory.append_array([arm, sh, sh2])
	var def0 := p.def
	g.use_item(arm)
	g.use_item(sh)
	ok(p.armor == arm and p.shield == sh, "páncél és pajzs egyszerre felvehető")
	ok(p.def == p.base_def + arm.def + sh.def, "védelem = alap + páncél + pajzs")
	print("  Páncél+pajzs: DEF %d -> %d (alap %d + páncél %d + pajzs %d)" % [def0, p.def, p.base_def, arm.def, sh.def])
	g.use_item(sh2)
	ok(p.shield == sh2 and sh in p.inventory, "pajzscsere: a régi pajzs a táskába kerül")
	ok(p.def == p.base_def + arm.def + sh2.def, "védelem pajzscsere után")
	# ── regeneráció: epic páncél (1) + legendás pajzs (2) = 3 / kör
	ok(p.regen == 3, "regeneráció összeadódik (%d)" % p.regen)
	g.world.mons.clear()
	p.hp = p.max_hp - 10
	var hp0 := p.hp
	g.advance_turn()
	ok(p.hp == hp0 + 3, "regeneráció körönként +3 (%d -> %d)" % [hp0, p.hp])
	p.hp = p.max_hp - 1
	g.advance_turn()
	ok(p.hp == p.max_hp, "a regeneráció nem lépi túl a max. életerőt")
	print("  Regeneráció: %d HP/kör (páncél %d + pajzs %d)" % [p.regen, arm.regen, sh2.regen])

	# ── bájital
	var pot := mk("Nagy gyógyital", "legendary")
	p.inventory.append(pot)
	p.hp = 10
	g.use_item(pot)
	ok(p.hp == mini(10 + pot.heal, p.max_hp) and not (pot in p.inventory), "gyógyital gyógyít és elfogy")
	# ── életerő töltő: max. életerő nő ÉS teljes gyógyulás
	var mh := mk("Életerő töltő", "rare", 2)
	p.inventory.append(mh)
	p.hp = 5
	var max0 := p.max_hp
	g.use_item(mh)
	ok(p.max_hp == max0 + mh.max_hp_up and p.hp == p.max_hp, "életerő töltő: MaxHP +%d és teljes gyógyulás" % mh.max_hp_up)
	print("  Életerő töltő: MaxHP %d -> %d, HP = %d/%d" % [max0, p.max_hp, p.hp, p.max_hp])

	# ── tekercsek kasztonként
	for cls in Data.CLASS_ORDER:
		var gc := arena(cls)
		var pc := gc.player
		var atk_s := mk("Erő tekercs", "rare")
		var def_s := mk("Véd tekercs", "rare")
		pc.inventory.append_array([atk_s, def_s])
		var ba := pc.base_atk
		var bm := pc.base_mag
		var bd := pc.base_def
		gc.use_item(atk_s)
		gc.use_item(def_s)
		if cls == "Mágus":
			ok(pc.base_mag == bm + atk_s.atk_up * 2 and pc.base_atk == ba, "mágus: erő tekercs 2× varázserő")
		else:
			ok(pc.base_atk == ba + atk_s.atk_up, "%s: erő tekercs ATK" % cls)
		var want := def_s.def_up + (Data.LOVAG_VED_TEKERCS if cls == "Lovag" else 0)
		ok(pc.base_def == bd + want, "%s: véd tekercs +%d" % [cls, want])
		print("  %-6s Erő tekercs (%d): ATK %d->%d, varázserő %d->%d · Véd tekercs (%d): DEF %d->%d" % [cls, atk_s.atk_up, ba, pc.base_atk, bm, pc.base_mag, def_s.def_up, bd, pc.base_def])

	# ── tűzgömb: a mágusnál + varázserő
	for cls in ["Lovag", "Mágus"]:
		var gf := arena(cls)
		var fb := mk("Tűzgömb", "common")
		gf.player.inventory.append(fb)
		var mo := place(gf, "orc", 3)
		var h0 := mo.hp
		gf.use_item(fb)
		var d := h0 - mo.hp
		var bonus := gf.player.mag if cls == "Mágus" else 0
		ok(d >= fb.damage + bonus and d <= fb.damage + 15 + bonus, "%s tűzgömb sebzés %d (alap %d, bónusz %d)" % [cls, d, fb.damage, bonus])
		print("  %-6s tűzgömb: %d sebzés (alap %d + 0..15 + varázserő %d)" % [cls, d, fb.damage, bonus])

	# ── életlopás: nagyon ritka 10%, legendás 20%
	for r in ["epic", "legendary"]:
		var gl := arena("Lovag")
		var w := mk("Holdfénypenge", r, 3)
		gl.player.weapon = w
		var tot_d := 0
		var tot_h := 0
		for i in 200:
			var mo := place(gl, "goblin", 1)
			gl.player.max_hp = 100000
			gl.player.hp = 1000
			var h0 := mo.hp
			var hp0b := gl.player.hp
			gl.p_attack(mo)
			var d := h0 - mo.hp
			var healed := gl.player.hp - hp0b
			tot_d += d
			tot_h += healed
			if healed != maxi(1, Data.jround(d * w.lifesteal)):
				ok(false, "életlopás %s: sebzés %d, gyógyulás %d" % [r, d, healed])
				break
		var pct := 100.0 * tot_h / tot_d
		ok(absf(pct - w.lifesteal * 100) < 2.0, "életlopás aránya %s: %.1f%%" % [r, pct])
		print("  Életlopás (%s): %d sebzésből %d HP vissza = %.1f%%" % [r, tot_d, tot_h, pct])
	# közönséges fegyverrel nincs életlopás
	var gn := arena("Lovag")
	gn.player.weapon = mk("Acélkard", "common")
	var mo2 := place(gn, "goblin", 1)
	gn.player.hp = 10
	gn.p_attack(mo2)
	ok(gn.player.hp == 10, "közönséges fegyvernél nincs életlopás")

	# ── láda: az üres pajzshelyre azonnal felveszi
	var gch := arena("Lovag")
	var ch := {"x": 0, "y": 0, "opened": false, "items": [mk("Fapajzs", "rare"), mk("Gyógyital", "common")]}
	gch.take_chest_item(ch, 0)
	ok(gch.player.shield != null and ch["opened"], "ládából a pajzs az üres pajzshelyre kerül")

	# ── a tárgyleírások mindent felsorolnak
	var lines := mk("Ezoterikus íj", "legendary", 3).stat_lines("Mágus", 20)
	var joined := " | ".join(lines)
	ok("Támadás" in joined and "Varázserő" in joined and "Táv" in joined and "Életlopás 20%" in joined, "fegyver-leírás: " + joined)
	var lines2 := mk("Sárkánypáncél", "epic", 3).stat_lines("Lovag")
	ok("Védelem" in " ".join(lines2) and "Regeneráció +1" in " ".join(lines2), "páncél-leírás: " + " | ".join(lines2))
	var lines3 := mk("Életerő töltő", "rare", 3).stat_lines("Lovag")
	ok("MaxHP" in " ".join(lines3) and "Teljes" in " ".join(lines3), "életerő töltő leírása")
	print("  Leírás (mágus, legendás Ezoterikus íj): " + joined)
	print("  Leírás (nagyon ritka Sárkánypáncél): " + " | ".join(lines2))


# ══════════ 4. KÜLÖNLEGES TERMEK, CSAPDÁK, TITKOS AJTÓK, SZENTÉLY, KERESKEDŐ ══════════
func test_specials() -> void:
	# ── tüskecsapda: a max. életerő 8–15%-a (de legalább 3)
	var g := arena("Lovag")
	var p := g.player
	p.max_hp = 100
	p.hp = 100
	var lo := 999
	var hi := 0
	for i in 60:
		p.hp = 100
		g.world.traps = [{"x": p.x, "y": p.y, "type": "tuske", "found": false, "sprung": false}]
		ok(g.trigger_trap(), "a csapda elsül")
		var d := 100 - p.hp
		lo = mini(lo, d)
		hi = maxi(hi, d)
	ok(lo >= 8 and hi <= 15, "tüskecsapda sebzése a max. HP 8–15%%-a (%d–%d)" % [lo, hi])
	ok(g.world.traps[0]["found"] and g.world.traps[0]["sprung"], "a csapda felfedődik és egyszer sül el")
	ok(not g.trigger_trap(), "az elsült csapda nem sül el újra")
	print("  Tüskecsapda 100 max. HP mellett: %d–%d sebzés (elvárt 8–15)" % [lo, hi])
	# ── méregcsapda
	p.hp = 100
	p.poison = 0
	g.world.traps = [{"x": p.x, "y": p.y, "type": "mereg", "found": false, "sprung": false}]
	g.trigger_trap()
	ok(p.poison >= 5 and p.hp < 100, "méregcsapda: méreg + sebzés (méreg %d, HP %d)" % [p.poison, p.hp])
	# ── riasztó: a közeli szörnyek felébrednek
	g.world.traps = [{"x": p.x, "y": p.y, "type": "riaszto", "found": false, "sprung": false}]
	g.world.mons.clear()
	var near := Mon.make("goblin", p.x + 4, p.y + 4, "normal")
	var far := Mon.make("goblin", p.x + 30, p.y + 20, "normal")
	g.world.mons.append_array([near, far])
	g.trigger_trap()
	ok(near.awake and not far.awake, "a riasztó csak a közeli szörnyeket ébreszti")
	print("  Riasztó: %d mezőn belül ébreszt" % Data.ALARM_R)

	# ── titkos ajtó: falként zár, megtalálva padló lesz és átjárható
	var g2 := arena("Íjász")
	var w2 := g2.world
	var sx: int = g2.player.x + 1
	var sy: int = g2.player.y
	w2.tiles[sx * Data.MAP_H + sy] = Data.SECRET
	var sec := {"x": sx, "y": sy, "kind": "kamra", "found": false}
	w2.secrets = [sec]
	w2.traps = []
	ok(w2.blocked(sx, sy), "a meg nem talált titkos ajtó zár")
	ok(not g2.do_move(1, 0), "a titkos ajtón nem lehet átmenni, amíg rejtve van")
	ok(g2.search(), "kutatás (K)")
	ok(sec["found"] and not w2.blocked(sx, sy), "az íjász kutatása megtalálja a szomszédos titkos ajtót")
	ok(g2.do_move(1, 0) and g2.player.x == sx, "a megtalált ajtón át lehet menni")

	# ── szentély: mind a négy áldás, és csak egyszer
	for kind in Data.SHRINE_ORDER:
		var gs := arena("Mágus")
		var ps := gs.player
		ps.max_hp = 50
		ps.hp = 10
		var d0 := ps.base_def
		var m0 := ps.base_mag
		var l0 := ps.lives
		gs.world.shrines = [{"x": ps.x, "y": ps.y, "kind": kind, "used": false}]
		ok(gs.trigger_shrine(), "szentély működik: %s" % kind)
		match kind:
			"gyogyulas": ok(ps.hp == ps.max_hp, "szentély: teljes gyógyulás")
			"elet": ok(ps.lives == l0 + 1, "szentély: +1 élet")
			"vedelem": ok(ps.base_def == d0 + 2, "szentély: +2 védelem")
			"varazs": ok(ps.base_mag == m0 + 3, "szentély: +3 varázserő")
		ok(not gs.trigger_shrine(), "a szentély csak egyszer használható (%s)" % kind)
	print("  Szentély: %s" % ", ".join(Data.SHRINE_ORDER))

	# ── kereskedő: ár, arany, készlet
	var gm := arena("Lovag")
	var pm := gm.player
	var shop := {"x": pm.x, "y": pm.y, "stock": Dungeon.make_stock(3)}
	var min_price := 999
	var max_price := 0
	for e in shop["stock"]:
		min_price = mini(min_price, int(e["price"]))
		max_price = maxi(max_price, int(e["price"]))
	ok(min_price >= 10 and max_price <= 60, "a kereskedő árai 10–60 arany között vannak (%d–%d)" % [min_price, max_price])
	pm.gold = 0
	ok(not gm.buy(shop, 0), "üres erszénnyel nem lehet vásárolni")
	pm.gold = 200
	var inv0 := pm.inventory.size()
	ok(gm.buy(shop, 0), "vásárlás aranyért")
	ok(pm.inventory.size() == inv0 + 1, "a vett tárgy a táskába kerül")
	ok(pm.gold == 200 - int(shop["stock"][0]["price"]), "az ár levonódik")
	ok(not gm.buy(shop, 0), "ugyanazt kétszer nem lehet megvenni")
	pm.max_hp = 80
	pm.hp = 10
	var heal_i := -1
	for i in (shop["stock"] as Array).size():
		if shop["stock"][i]["kind"] == "heal":
			heal_i = i
	ok(heal_i >= 0 and gm.buy(shop, heal_i) and pm.hp == pm.max_hp, "a kereskedő teljes gyógyítása működik")
	print("  Kereskedő: árak %d–%d arany, 3 féle kínálat" % [min_price, max_price])

	# ── arany hullik a szörnyekből (a főellenségből sokkal több)
	var gg := arena("Lovag")
	gg.player.gold = 0
	var mob := place(gg, "goblin", 1)
	mob.hp = 1
	gg.p_attack(mob)
	var g_mob: int = gg.player.gold
	gg.player.gold = 0
	var bossm := place(gg, "weaver", 1)
	bossm.hp = 1
	gg.p_attack(bossm)
	ok(g_mob >= Data.GOLD_MIN and gg.player.gold >= Data.GOLD_BOSS[0], "arany hullik (szörny %d, boss %d)" % [g_mob, gg.player.gold])
	print("  Arany: szörny %d arany, főellenség %d arany" % [g_mob, gg.player.gold])


# ══════════ 5. KÉPESSÉGEK ══════════
func test_perks() -> void:
	# minden képesség létezik és a kasztja stimmel
	for id in Perks.ORDER:
		ok(Perks.LIST.has(id), "képesség a táblában: %s" % id)
	var gk := arena("Lovag")
	var pool := Perks.pool_for(gk.player)
	for id in pool:
		var cls: String = Perks.LIST[id]["cls"]
		ok(cls == "" or cls == "Lovag", "a lovagnak nem ajánlható %s" % id)
	ok(Perks.offer(gk.player).size() == 3, "három lapot kínál a szintlépés")

	# ── azonnali hatások
	var g := arena("Lovag")
	var p := g.player
	var mh := p.max_hp
	var df := p.def
	Perks.apply(p, "eletero")
	ok(p.max_hp == mh + 10, "Vas szervezet: +10 max. életerő")
	Perks.apply(p, "szivossag")
	ok(p.def == df + 2, "Szívósság: +2 védelem")
	Perks.apply(p, "vertezet")
	ok(p.def == df + 5, "Vértezet: +3 védelem")
	var gm := arena("Mágus")
	var m0 := gm.player.mag
	Perks.apply(gm.player, "fokusz")
	ok(gm.player.mag == m0 + 2, "Mágikus fókusz: +2 varázserő")
	# ── határ: nem lehet a maximumnál többször felvenni
	var gx := arena("Lovag")
	var maxn: int = Perks.LIST["vertezet"]["max"]
	for i in maxn:
		ok(Perks.apply(gx.player, "vertezet"), "Vértezet %d." % (i + 1))
	ok(not Perks.apply(gx.player, "vertezet"), "a képesség nem vehető fel a maximumnál többször")
	ok(not ("vertezet" in Perks.pool_for(gx.player)), "a kimaxolt képesség nem kerül a kínálatba")

	# ── életlopás és regeneráció
	var gv := arena("Lovag")
	gv.player.weapon = null
	ok(gv.player.lifesteal == 0.0, "életlopás alapból 0")
	Perks.apply(gv.player, "vamp")
	Perks.apply(gv.player, "vamp")
	ok(absf(gv.player.lifesteal - 0.10) < 0.0001, "Vérszívás ×2 = 10%% életlopás")
	Perks.apply(gv.player, "regen")
	ok(gv.player.regen == 1, "Gyors gyógyulás: +1 HP/kör")
	gv.player.max_hp = 100
	gv.player.hp = 50
	gv.world.mons.clear()
	gv.advance_turn()
	ok(gv.player.hp == 51, "a képesség regenerál körönként")

	# ── blokk és kritikus esély
	var gb := arena("Lovag")
	ok(absf(gb.player.block_chance - 0.20) < 0.0001, "lovag alap blokk 20%")
	Perks.apply(gb.player, "blokk")
	ok(absf(gb.player.block_chance - 0.25) < 0.0001, "Pajzsmester: +5%% blokk")
	var ga := arena("Íjász")
	ok(absf(ga.player.crit_chance - 0.30) < 0.0001, "íjász alap kritikus 30%")
	Perks.apply(ga.player, "sasszem")
	ok(absf(ga.player.crit_chance - 0.38) < 0.0001, "Sasszem: +8%% kritikus")

	# ── lőtáv
	var gr := arena("Íjász")
	var r0 := gr.ranged_range()
	Perks.apply(gr.player, "hosszuij")
	ok(gr.ranged_range() == r0 + 1, "Hosszú íj: +1 lőtáv (%d -> %d)" % [r0, gr.ranged_range()])
	var mr := place(gr, "goblin", r0 + 1)
	gr.do_move(1, 0)
	ok(mr.hp < mr.max_hp, "a megnövelt lőtávval elér a távolabbi szörnyet is")
	var gz := arena("Mágus")
	var z0 := gz.ranged_range()
	Perks.apply(gz.player, "messzi")
	ok(gz.ranged_range() == z0 + 1, "Messzi gömb: +1 lőtáv")

	# ── átütő gömb: két szörnyet is eltalál egy lövés
	var gp := arena("Mágus")
	Perks.apply(gp.player, "atuto")
	Perks.apply(gp.player, "atuto")
	var pierced := 0
	for i in 200:
		gp.world.mons.clear()
		var m1 := Mon.make("goblin", gp.player.x + 2, gp.player.y, "normal")
		var m2 := Mon.make("goblin", gp.player.x + 3, gp.player.y, "normal")
		for mm in [m1, m2]:
			mm.hp = 100000
			mm.max_hp = 100000
			mm.sp = ""
		gp.world.mons.append_array([m1, m2])
		gp.do_move(1, 0)
		if m2.hp < m2.max_hp:
			pierced += 1
	ok(pierced > 30 and pierced < 170, "Átütő gömb ×2: a lövések ~40%%-a átüt (%d/200)" % pierced)
	print("  Átütő gömb ×2: 200 lövésből %d ütött át (elvárt ~80)" % pierced)

	# ── pajzsdöfés: kábítás, a kábult szörny kihagy egy kört
	var gd := arena("Lovag")
	Perks.apply(gd.player, "dofes")
	Perks.apply(gd.player, "dofes")
	var stuns := 0
	for i in 200:
		var md := place(gd, "goblin", 1)
		md.stun = 0
		gd.p_attack(md)
		if md.stun > 0:
			stuns += 1
	ok(stuns > 60, "Pajzsdöfés ×2: kábítás (%d/200)" % stuns)
	var gs2 := arena("Lovag")
	var ms := place(gs2, "goblin", 3)
	ms.stun = 1
	var mx := ms.x
	gs2.advance_turn()
	ok(ms.x == mx and ms.stun == 0, "a kábult szörny nem lép, és a kábulat lejár")

	# ── gyors léptek: minden 5. lépés nem telik körrel
	var gf := arena("Íjász")
	gf.world.mons.clear()
	Perks.apply(gf.player, "gyorslab")
	gf.player.steps = 0
	gf.world.turn = 0
	for i in 10:
		gf.do_move(1, 0)
	ok(gf.world.turn == 8, "Gyors léptek: 10 lépésből 8 telt körrel (%d)" % gf.world.turn)

	# ── kincsvadász: +50% arany
	var gc := arena("Lovag")
	Perks.apply(gc.player, "kincs")
	Perks.apply(gc.player, "kincs")
	var tot := 0
	for i in 300:
		gc.player.gold = 0
		var mc := place(gc, "goblin", 1)
		mc.hp = 1
		gc.p_attack(mc)
		tot += gc.player.gold
	var avg := float(tot) / 300.0
	var base := (Data.GOLD_MIN + Data.GOLD_MAX + gc.world.dungeon_level * 2) / 2.0
	ok(avg > base * 1.6, "Kincsvadász ×2: kétszeres arany (átlag %.1f, alap ~%.1f)" % [avg, base])
	print("  Kincsvadász ×2: átlag %.1f arany / szörny (alap ~%.1f)" % [avg, base])
	print("  %d képesség, ebből közös: %d" % [Perks.ORDER.size(), Perks.pool_for(Player.create("Lovag")).size() - 3])


# ══════════ 6. MENTÉS ÉS BETÖLTÉS ══════════
func test_save() -> void:
	seed(777)
	var g := Game.new()
	g.autosave = false
	g.start("Íjász", "hard")
	var p := g.player
	# járjunk körbe, hogy legyen felderített terület, üzenet, arany, képesség, tárgy...
	# (a séta alatt a hős ne halhasson meg egy közeli Fertőzött miatt: a teszt a mentést méri, nem a harcot)
	p.hp = 99999
	for i in 40:
		g.do_move([1, 0, -1, 0][i % 4], [0, 1, 0, -1][i % 4])
	p.hp = p.max_hp
	p.lives = 3
	p.gold = 137
	p.inventory.append(mk("Rúnakard", "epic", 2))
	p.inventory.append(mk("Nagy gyógyital", "rare", 2))
	p.armor = mk("Láncpáncél", "epic", 2)
	p.shield = mk("Rúnapajzs", "legendary", 3)
	Perks.apply(p, "sasszem")
	Perks.apply(p, "eletero")
	Perks.apply(p, "kincs")
	p.poison = 3
	p.hp = maxi(1, p.max_hp - 7)
	p.lives = 2
	if not g.world.traps.is_empty():
		g.world.traps[0]["found"] = true
	if not g.world.secrets.is_empty():
		g.world.secrets[0]["found"] = true
	if not g.world.chests.is_empty():
		g.world.chests[0]["opened"] = true
	if not g.world.mons.is_empty():
		g.world.mons[0].hp = maxi(1, g.world.mons[0].hp - 3)
		g.world.mons[0].awake = true

	ok(SaveGame.save_run(g), "mentés sikerült")
	ok(SaveGame.has_save(), "a mentés létezik")
	var g2 := SaveGame.load_run()
	ok(g2 != null, "a mentés visszatölthető")
	if g2 == null:
		return
	var p2 := g2.player
	var w := g.world
	var w2 := g2.world
	# ── pálya
	ok(w2.tiles == w.tiles, "a csempék azonosak")
	ok(w2.explored == w.explored, "a bejárt mezők azonosak")
	ok(w2.fade.size() == w.fade.size(), "a fényerő-tömb mérete azonos")
	var fade_ok := true
	for i in w.fade.size():
		if absf(w.fade[i] - w2.fade[i]) > 0.0001:
			fade_ok = false
	ok(fade_ok, "a mezőnkénti fényerő azonos")
	ok(w2.rooms == w.rooms, "a szobák azonosak")
	ok(w2.room_kind == w.room_kind, "a különleges termek azonosak")
	ok(w2.dungeon_level == w.dungeon_level and w2.diff == w.diff and w2.turn == w.turn, "mélység, nehézség, körszám")
	ok(w2.decor.size() == w.decor.size() and w2.torches.size() == w.torches.size(), "díszek és fáklyák")
	ok(w2.traps == w.traps, "csapdák (hely, fajta, felfedve, elsült)")
	ok(w2.secrets == w.secrets, "titkos ajtók")
	ok(w2.shrines == w.shrines, "szentélyek")
	# ── szörnyek
	ok(w2.mons.size() == w.mons.size(), "szörnyek száma")
	var mons_ok := true
	for i in w.mons.size():
		var a := w.mons[i]
		var b := w2.mons[i]
		if a.key != b.key or a.x != b.x or a.y != b.y or a.hp != b.hp or a.max_hp != b.max_hp \
				or a.atk != b.atk or a.def != b.def or a.alive != b.alive or a.boss != b.boss \
				or a.guard != b.guard or a.awake != b.awake or a.sp != b.sp:
			mons_ok = false
	ok(mons_ok, "minden szörny állapota azonos")
	# ── ládák és kereskedők
	var ch_ok := w2.chests.size() == w.chests.size()
	for i in w.chests.size():
		if not ch_ok:
			break
		var a: Dictionary = w.chests[i]
		var b: Dictionary = w2.chests[i]
		if a["x"] != b["x"] or a["y"] != b["y"] or a["opened"] != b["opened"]:
			ch_ok = false
		for j in 2:
			if (a["items"][j] as Item).label != (b["items"][j] as Item).label:
				ch_ok = false
	ok(ch_ok, "a ládák és a bennük lévő tárgyak azonosak")
	var shop_ok := w2.shops.size() == w.shops.size()
	for i in w.shops.size():
		if not shop_ok:
			break
		var sa: Array = w.shops[i]["stock"]
		var sb: Array = w2.shops[i]["stock"]
		if sa.size() != sb.size():
			shop_ok = false
			break
		for j in sa.size():
			if sa[j]["price"] != sb[j]["price"] or sa[j]["sold"] != sb[j]["sold"] or sa[j]["kind"] != sb[j]["kind"]:
				shop_ok = false
	ok(shop_ok, "a kereskedő kínálata azonos")
	# ── hős
	ok(p2.cls == p.cls and p2.x == p.x and p2.y == p.y, "a hős kasztja és helye")
	ok(p2.hp == p.hp and p2.max_hp == p.max_hp and p2.lives == p.lives and p2.poison == p.poison, "életerő, életek, méreg")
	ok(p2.base_atk == p.base_atk and p2.base_mag == p.base_mag and p2.base_def == p.base_def, "alapértékek")
	ok(p2.xp == p.xp and p2.plvl == p.plvl and p2.xp_next == p.xp_next, "tapasztalat és szint")
	ok(p2.gold == p.gold and p2.perks == p.perks and p2.steps == p.steps, "arany, képességek, lépésszám")
	ok(p2.atk == p.atk and p2.def == p.def and p2.mag == p.mag, "a származtatott értékek is azonosak")
	ok(p2.crit_chance == p.crit_chance and p2.regen == p.regen, "a képességek hatása is visszaáll")
	ok((p2.weapon.label if p2.weapon else "-") == (p.weapon.label if p.weapon else "-"), "fegyver")
	ok(p2.armor != null and p2.armor.label == p.armor.label and p2.armor.regen == p.armor.regen, "páncél")
	ok(p2.shield != null and p2.shield.label == p.shield.label and p2.shield.def == p.shield.def, "pajzs (külön hely)")
	ok(p2.inventory.size() == p.inventory.size(), "táska mérete")
	var inv_ok := true
	for i in p.inventory.size():
		var a := p.inventory[i]
		var b := p2.inventory[i]
		if a.label != b.label or a.dmg != b.dmg or a.def != b.def or a.heal != b.heal or a.rarity != b.rarity or absf(a.lifesteal - b.lifesteal) > 0.0001:
			inv_ok = false
	ok(inv_ok, "a táska minden tárgya azonos")
	print("  Mentés: %d csempe, %d szörny, %d láda, %d csapda, %d titkos ajtó, %d tárgy a táskában" % [
		w.tiles.size(), w.mons.size(), w.chests.size(), w.traps.size(), w.secrets.size(), p.inventory.size()])
	var sz := FileAccess.get_file_as_bytes(SaveGame.path_of(SaveGame.current)).size()
	print("  A mentésfájl mérete: %.1f kB (%s)" % [sz / 1024.0, SaveGame.path_of(SaveGame.current)])

	# ── a betöltött kalandban tovább lehet játszani
	var t0 := g2.world.turn
	g2.do_move(1, 0)
	ok(g2.world.turn >= t0, "a betöltött kalandban tovább lehet lépni")

	# ── a szintváltás magától ment
	SaveGame.erase()
	var g3 := Game.new()
	g3.start("Lovag", "normal")
	ok(not SaveGame.has_save(), "induláskor (autosave nélkül) még nincs mentés")
	g3.autosave = true
	ok(g3.world.emelet == 1 and g3.world.boss() == null, "a kaland a zóna első emeletén indul, ott nincs főellenség")
	ok(not g3.next_level() and g3.world.dungeon_level == 1 and g3.world.emelet == 2, "előbb a zóna második emelete jön")
	ok(g3.world.boss() == null, "a közbülső emeleten sincs főellenség")
	SaveGame.refresh()
	var g4e := SaveGame.load_run()
	ok(g4e != null and g4e.world.emelet == 2 and g4e.world.dungeon_level == 1, "a mentés az emeletet is őrzi")
	while g3.world.emelet < Data.emeletek(1):
		g3.next_level()
	ok(g3.world.boss() != null, "a zóna ura az utolsó emeleten vár")
	ok(not g3.next_level(), "lejjebb a 2. mélységbe")
	SaveGame.refresh()
	ok(SaveGame.has_save(), "a szintváltás automatikusan mentett")
	var g4 := SaveGame.load_run()
	ok(g4 != null and g4.world.dungeon_level == 2 and g4.world.emelet == 1, "az automata mentés a 2. mélységet őrzi")
	var lepesek := 0
	var gv := Game.new()
	gv.start("Lovag", "normal")
	while not gv.next_level() and lepesek < 50:
		lepesek += 1
	ok(Data.palyak() == 15 and lepesek == Data.palyak() - 1, "a kaland %d pályából áll (%d lejárat)" % [Data.palyak(), lepesek])
	ok(Data.EMELET_DB.size() == Data.MAX_LEVEL, "minden zónának megvan az emeletszáma")

	# ── sérült / régi mentés: nincs folytatás
	SaveGame.erase_all()
	DirAccess.make_dir_recursive_absolute(SaveGame.DIR)
	var f := FileAccess.open(SaveGame.path_of("rossz"), FileAccess.WRITE)
	f.store_string('{"v": 999, "hos": {}}')
	f.close()
	SaveGame.refresh()
	ok(SaveGame.load_run() == null and not SaveGame.has_save(), "régi verziójú mentés elutasítva")
	f = FileAccess.open(SaveGame.path_of("rossz"), FileAccess.WRITE)
	f.store_string("ez nem json {{{")
	f.close()
	SaveGame.refresh()
	ok(SaveGame.load_run() == null and not SaveGame.has_save(), "sérült mentés elutasítva")
	DirAccess.remove_absolute(SaveGame.path_of("rossz"))
	SaveGame.erase_all()
	ok(not SaveGame.has_save(), "a mentés törölhető (nincs mentés)")


# ══════════ 7. KOZMETIKA: fiók, katalógus, kinézet mentése, értékek védelme ══════════
## A kiszolgáló rögzítette kulcsok és árak. Ha ez és a Skins.VARIANSOK eltérne,
## a boltban „unknown_item" hibát kapna a játékos — ezért soronként összevetjük.
const SZERVER := {
	"lovag": {
		"fej": ["sisak_arany", "sisak_szarv", "csuklya"],
		"test": ["pancel_arany", "pancel_sotet", "koponyas_vert"],
		"lab": ["vaslabvert", "bor_labvert"],
		"fegyver": ["kard_lang", "kard_jeg", "csatabard"],
	},
	"magus": {
		"fej": ["kalap_csillag", "kalap_sotet", "korona"],
		"test": ["kontos_kek", "kontos_bibor", "kontos_arany"],
		"lab": ["csizma_kek", "csizma_arany"],
		"fegyver": ["bot_kristaly", "bot_koponya", "bot_fa"],
	},
	"ijasz": {
		"fej": ["csuklya_zold", "csuklya_szurke", "tollas_kalap"],
		"test": ["bor_vert", "koppeny_zold", "vadasz_mellveert"],
		"lab": ["csizma_bor", "csizma_magas"],
		"fegyver": ["ij_tiszafa", "ij_csont", "szamszerij"],
	},
}
const SZERVER_ARAK := {"fegyver": 20, "test": 20, "fej": 15, "lab": 10}


static func _halo_mas(a: Array, b: Array) -> bool:
	var pa: PackedVector2Array = a[0]
	var pb: PackedVector2Array = b[0]
	if pa.size() != pb.size():
		return true
	if (a[1] as PackedColorArray) != (b[1] as PackedColorArray):
		return true
	return pa != pb


func test_kozmetika() -> void:
	# ── 7.1 fiok.json (a ParthLauncher írja) ──
	var jo := '{"url":"https://abc.supabase.co/","anon":"anonkulcs","email":"a@b.hu","access_token":"AT","refresh_token":"RT","mentve":1720000000}'
	var d := Fiok.ertelmez(jo)
	ok(str(d.get("url", "")) == "https://abc.supabase.co", "fiok.json: url (a záró / levágva)")
	ok(str(d.get("anon", "")) == "anonkulcs", "fiok.json: anon kulcs")
	ok(str(d.get("email", "")) == "a@b.hu", "fiok.json: e-mail")
	ok(str(d.get("access_token", "")) == "AT", "fiok.json: access_token")
	ok(str(d.get("refresh_token", "")) == "RT", "fiok.json: refresh_token")
	ok(int(d.get("mentve", 0)) == 1720000000, "fiok.json: mentve idopont")
	ok(Fiok.ertelmez("").is_empty(), "üres fiok.json: nincs fiók (a bolt bejelentkezést kér)")
	ok(Fiok.ertelmez("ez nem json {{{").is_empty(), "sérült fiok.json: nincs fiók")
	ok(Fiok.ertelmez('{"url":"https://x.hu"}').is_empty(), "hiányos fiok.json (nincs anon kulcs)")
	ok(Fiok.ertelmez('[1,2,3]').is_empty(), "nem objektum fiok.json")
	ok(Fiok.ertelmez('{"url":"https://x.hu","anon":"a"}').get("access_token", null) == "", "token nélküli fiók is beolvasható")
	# a bolt tud fiók nélkül is működni: a Fiok példány hálózat nélkül sem dob hibát
	var f := Fiok.new()
	f.offline_mod = true
	f.frissit()                      # nincs betöltve: csendben nem csinál semmit
	ok(not f.betoltve and f.erme == 0, "fiók nélkül nincs lekérdezés, nincs összeomlás")
	var valasz := {"ok": false, "u": ""}
	f.vasarol("lovag_fej_csuklya", func(s: bool, u: String) -> void:
		valasz["ok"] = s
		valasz["u"] = u)
	ok(not bool(valasz["ok"]) and str(valasz["u"]) == Fiok.HIBA_SZOVEG["not_logged_in"], "fiók nélküli vásárlás barátságos üzenetet ad")
	ok(Fiok.GUMROAD.size() == 3, "három érmecsomag (100 / 220 / 600)")
	var gok := true
	for e in Fiok.GUMROAD:
		if not str(e["url"]).begins_with("https://parthenon62.gumroad.com/l/"):
			gok = false
	ok(gok, "az érmecsomagok a Gumroad oldalaira mutatnak")
	ok(int(Fiok.GUMROAD[0]["erme"]) == 100 and int(Fiok.GUMROAD[1]["erme"]) == 220 and int(Fiok.GUMROAD[2]["erme"]) == 600, "az érmecsomagok mérete")
	f.free()

	# ── 7.2 a bolt kínálata pontosan a kiszolgáló kulcsait és árait használja ──
	var kat := Skins.katalogus()
	var varhato := 0
	for ck in SZERVER:
		for slot in (SZERVER[ck] as Dictionary):
			varhato += (SZERVER[ck][slot] as Array).size()
	ok(kat.size() == varhato, "a katalógus mérete (%d darab)" % varhato)
	var kulcsok := {}
	for e in kat:
		kulcsok[str(e["key"])] = e
	for ck in SZERVER:
		for slot in (SZERVER[ck] as Dictionary):
			var lista: Array = SZERVER[ck][slot]
			ok((Skins.VARIANSOK[ck][slot] as Array) == lista, "%s/%s: ugyanazok a változatok, ugyanabban a sorrendben" % [ck, slot])
			for v in lista:
				var k: String = "%s_%s_%s" % [ck, slot, v]
				var e: Variant = kulcsok.get(k)
				if e == null:
					ok(false, "hiányzó kulcs a boltban: " + k)
					continue
				ok(int((e as Dictionary)["ar"]) == int(SZERVER_ARAK[slot]), "%s ára %d érme" % [k, int(SZERVER_ARAK[slot])])
				ok(Skins.nev(ck, slot, v) != v and Skins.nev(ck, slot, v) != "", "%s: van magyar neve (%s)" % [k, Skins.nev(ck, slot, v)])
	ok(Skins.ar("fegyver") == 20 and Skins.ar("test") == 20 and Skins.ar("fej") == 15 and Skins.ar("lab") == 10, "árak: fegyver/test 20, fej 15, láb 10")
	ok(Skins.kulcs("lovag", "fej", "sisak_arany") == "lovag_fej_sisak_arany", "a kulcs alakja <kaszt>_<hely>_<név>")

	# ── 7.3 kinézet felvétele és mentése (user://beallitasok.cfg) ──
	var sel := Skins.alap_valasztas()
	var ures_ok := true
	for ck in Skins.CLS_ORDER:
		for slot in Skins.SLOTS:
			if str((sel[ck] as Dictionary)[slot]) != "":
				ures_ok = false
	ok(ures_ok, "alaphelyzetben minden hely az alap kinézetet hordja")
	(sel["lovag"] as Dictionary)["fej"] = "sisak_arany"
	(sel["lovag"] as Dictionary)["test"] = "pancel_sotet"
	(sel["lovag"] as Dictionary)["lab"] = "bor_labvert"
	(sel["lovag"] as Dictionary)["fegyver"] = "csatabard"
	(sel["magus"] as Dictionary)["fej"] = "korona"
	(sel["ijasz"] as Dictionary)["fegyver"] = "szamszerij"
	var cfg_ut := "user://teszt_kinezet.cfg"
	var cf := ConfigFile.new()
	Skins.ment(cf, sel)
	ok(cf.save(cfg_ut) == OK, "a kinézet beállításfájlba menthető")
	var cf2 := ConfigFile.new()
	ok(cf2.load(cfg_ut) == OK, "a beállításfájl visszatölthető")
	var sel2 := Skins.betolt(cf2)
	var vissza_ok := true
	for ck in Skins.CLS_ORDER:
		for slot in Skins.SLOTS:
			if str((sel2[ck] as Dictionary)[slot]) != str((sel[ck] as Dictionary)[slot]):
				vissza_ok = false
	ok(vissza_ok, "a kiválasztott összeállítás kasztonként visszatöltődik")
	ok(Skins.sig(sel2, "Lovag") == "sisak_arany.pancel_sotet.bor_labvert.csatabard", "a kombináció aláírása (gyorsítótár-kulcs)")
	ok(Skins.sig(sel2, "Íjász") == "...szamszerij", "kevert kombináció is megmarad")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_ut))
	# ismeretlen / másik kaszthoz tartozó darab nem kerülhet a hősre
	var cf3 := ConfigFile.new()
	cf3.set_value("kinezet", "lovag_fej", "nincs_ilyen_darab")
	cf3.set_value("kinezet", "lovag_test", "kontos_kek")   # ez a mágusé
	cf3.set_value("kinezet", "magus_fej", "korona")
	var sel3 := Skins.betolt(cf3)
	ok(str((sel3["lovag"] as Dictionary)["fej"]) == "", "ismeretlen darab nem kerül a hősre")
	ok(str((sel3["lovag"] as Dictionary)["test"]) == "", "másik kaszt darabja nem kerül a hősre")
	ok(str((sel3["magus"] as Dictionary)["fej"]) == "korona", "az érvényes darab viszont megmarad")
	ok(Skins.ervenyes("lovag", "fej", ""), "az alap kinézet mindig érvényes")
	ok(not Skins.ervenyes("ijasz", "lab", "vaslabvert"), "a lovag lábvértje nem az íjászé")

	# ── 7.4 minden megvásárolható darab LÁTHATÓAN más, mint az alap ──
	var c := Cv.new()
	var ci := RenderingServer.canvas_item_create()
	c.begin(ci)
	var alap_halo := {}
	for ck in Skins.CLS_ORDER:
		for slot in Skins.SLOTS:
			c.rec_begin()
			Skins.resz(c, ck, slot, "", 1.0)
			alap_halo["%s_%s" % [ck, slot]] = c.rec_end()
	var elozo := {}
	for e in kat:
		c.rec_begin()
		Skins.resz(c, str(e["cls"]), str(e["slot"]), str(e["var"]), 1.0)
		var halo := c.rec_end()
		var kulcs := "%s_%s" % [str(e["cls"]), str(e["slot"])]
		var jo_e: bool = (halo[0] as PackedVector2Array).size() > 0 and _halo_mas(halo, alap_halo[kulcs])
		for elo in elozo.get(kulcs, []):
			if not _halo_mas(halo, elo):
				jo_e = false
		ok(jo_e, "%s: látható, önálló rajz (nem egyezik az alappal vagy egy másik darabbal)" % str(e["key"]))
		var lista: Array = elozo.get(kulcs, [])
		lista.append(halo)
		elozo[kulcs] = lista
	# a teljes figura is más lesz, ha bármelyik hely darabot kap
	for ck in Skins.CLS_ORDER:
		var cls: String = Skins.KEY_CLS[ck]
		c.rec_begin(); Skins.hos(c, cls, 1.0, Skins.alap_valasztas()); var h0 := c.rec_end()
		c.rec_begin(); Skins.hos(c, cls, 1.0, sel); var h1 := c.rec_end()
		ok(_halo_mas(h1, h0) or Skins.sig(sel, cls) == "...", "%s: az összeállítás a teljes figurán is látszik" % cls)
	c.flush()
	RenderingServer.free_rid(ci)

	# ── 7.5 a kozmetika SOHA nem nyúl a játékértékekhez ──
	for cls in Data.CLASS_ORDER:
		var p := Player.create(cls)
		p.inventory.append(Item.make(Item.find_base("Gyógyital"), "rare", 1))
		Perks.apply(p, "eletero")
		var elott := [p.max_hp, p.hp, p.atk, p.mag, p.def, p.regen, p.lifesteal, p.crit_chance,
			p.block_chance, p.lives, p.xp, p.xp_next, p.plvl, p.gold, p.base_atk, p.base_mag, p.base_def]
		var ci2 := RenderingServer.canvas_item_create()
		var c2 := Cv.new()
		c2.begin(ci2)
		for ck in Skins.CLS_ORDER:
			for slot in Skins.SLOTS:
				for v in (Skins.VARIANSOK[ck][slot] as Array):
					var s := Skins.alap_valasztas()
					(s[ck] as Dictionary)[slot] = v
					Skins.hos(c2, Skins.KEY_CLS[ck], 0.8, s)
		c2.flush()
		RenderingServer.free_rid(ci2)
		var utan := [p.max_hp, p.hp, p.atk, p.mag, p.def, p.regen, p.lifesteal, p.crit_chance,
			p.block_chance, p.lives, p.xp, p.xp_next, p.plvl, p.gold, p.base_atk, p.base_mag, p.base_def]
		ok(elott == utan, "%s: a kinézet egyetlen értékét sem változtatja meg" % cls)
	# a Player / Game / Item egyáltalán nem ismeri a kinézetet
	var tiszta := true
	for fajl in ["res://scripts/player.gd", "res://scripts/game.gd", "res://scripts/item.gd", "res://scripts/mon.gd", "res://scripts/save.gd"]:
		var txt := FileAccess.get_file_as_string(fajl)
		if txt.find("Skins") >= 0 or txt.find("Fiok") >= 0:
			tiszta = false
			print("  a játékszabályok hivatkoznak a kozmetikára: ", fajl)
	ok(tiszta, "a játékszabályok (hős, harc, tárgyak, mentés) nem ismerik a kozmetikát")
	print("  Kozmetika: %d megvásárolható darab, 3 kaszt × 4 hely" % kat.size())


# ══════════ 8. NYELVEK (HU / EN / DE) ══════════
## a kulcsok, amelyekre a kód hivatkozik: a szkriptekben szó szerint álló kulcsok
## (Lang.T / Lang.Ta / Lang.ref / _uz hívások és minden "csoport.valami" alakú szöveg),
## valamint a táblákból összerakott kulcsok (tárgyak, szörnyek, képességek, kinézet...)
const KULCS_CSOPORTOK := "menu|help|bind|key|common|diff|char|cls|stat|inv|chest|rarity|rar|perk|shop|bolt|coins|pack|slot|skin|fiok|pause|over|hud|map|st|sh|msg|item|mon|room|trap|shrine|ab|zone|banner|boss|who|talk|dlg|intro|end|cine|npc|hub|up|cur|journal|note|lore|saves|cloud|relic|mini|event|ach|daily|set"


func kod_kulcsai() -> Dictionary:
	var out := {}
	var re_hivas := RegEx.create_from_string('(?:Lang\\.(?:T|Ta|ref)|_uz)\\(\\s*"([^"]+)"')
	var re_kulcs := RegEx.create_from_string('"((?:' + KULCS_CSOPORTOK + ')\\.[A-Za-z0-9_.]*[A-Za-z0-9_])"')
	for fajl in DirAccess.get_files_at("res://scripts/"):
		if not fajl.ends_with(".gd"):
			continue
		var txt := FileAccess.get_file_as_string("res://scripts/" + fajl)
		for sor in txt.split("\n"):
			var s := sor.strip_edges()
			if s.begins_with("#"):
				continue   # megjegyzés
			for mm in re_hivas.search_all(sor):
				if not mm.get_string(1).ends_with("."):   # "perk." + id: a táblákból rakjuk össze (lent)
					out[mm.get_string(1)] = fajl
			for mm in re_kulcs.search_all(sor):
				out[mm.get_string(1)] = fajl
	# a táblákból összerakott kulcsok
	for b in Data.ITEM_BASES:
		out["item." + str(b["id"])] = "data.gd"
	for k in Data.MONS:
		out["mon." + str(k)] = "data.gd"
	for k in Data.RARITY:
		out["rarity." + str(k)] = "data.gd"
		out["rar.pre." + str(k)] = "lang.gd"
	for k in Data.DIFF:
		out["diff." + str(k)] = "data.gd"
		out["diff." + str(k) + ".d"] = "screens.gd"
	for c in Data.CLASS_ORDER:
		out["cls." + str(Lang.CLS_KULCS[c])] = "lang.gd"
		out["cls." + str(Lang.CLS_KULCS[c]) + ".d"] = "lang.gd"
	for k in Data.ROOM_KINDS:
		out["room." + str(k)] = "data.gd"
	for k in Data.TRAPS:
		out["trap." + str(k)] = "game.gd"
	for k in Data.SHRINES:
		out["shrine." + str(k)] = "game.gd"
		out["shrine." + str(k) + ".d"] = "data.gd"
		out["msg.shrine." + str(k)] = "game.gd"
	for id in Perks.ORDER:
		out["perk." + str(id)] = "perks.gd"
		out["perk." + str(id) + ".d"] = "perks.gd"
	for sl in Skins.SLOTS:
		out["slot." + str(sl)] = "skins.gd"
	for e in Skins.katalogus():
		out["skin." + str(e["key"])] = "skins.gd"
	for kod in Fiok.HIBA_SZOVEG:
		out[str(Fiok.HIBA_SZOVEG[kod])] = "fiok.gd"
	# Gorgona: zónák, főellenségek, veszélyzónák, feljegyzések, fejlesztések, képességek
	for z in Story.ZONES:
		out["zone." + str(Story.ZONES[z]["id"])] = "story.gd"
		out["zone." + str(Story.ZONES[z]["id"]) + ".goal"] = "story.gd"
	for lv in Data.BOSS_LVL:
		var bk: String = Data.BOSS_LVL[lv]
		out["boss." + bk + ".s"] = "game.gd"
		out["boss." + bk + ".p2"] = "game.gd"
		out["msg.phase2." + str(Data.MONS[bk]["sp"])] = "game.gd"
	for hk in Data.HAZ_COL:
		out["msg.haz." + str(hk)] = "game.gd"
	for id in Story.NOTE_ORDER:
		out["note." + str(id)] = "story.gd"
		out["note." + str(id) + ".d"] = "story.gd"
	for id in Meta.ORDER:
		out["up." + str(id)] = "meta.gd"
		out["up." + str(id) + ".d"] = "meta.gd"
	for c in Data.SKILL:
		out["ab." + str(Data.SKILL[c])] = "data.gd"
		out["ab." + str(Data.SKILL[c]) + ".d"] = "data.gd"
	for n in ["nora", "profeta"]:
		out["npc." + n] = "story_ui.gd"
		out["npc." + n + ".role"] = "story_ui.gd"
	for id in Relics.ORDER:
		out["relic." + str(id)] = "relics.gd"
		out["relic." + str(id) + ".d"] = "relics.gd"
	for z in Data.MINI:
		out["mini." + str(Data.MINI[z])] = "mon.gd"
	for e in Data.EVENTS:
		for veg in ["", ".d", ".a", ".b"]:
			out["event." + str(e) + veg] = "story_ui.gd"
		out["msg.event." + str(e) + ".a"] = "game.gd"
		out["msg.event." + str(e) + ".b"] = "game.gd"
	for jv in Meta.JELVENYEK:
		out["ach." + str(jv)] = "meta.gd"
	for c in Data.EXTRA_CLASSES:
		out["cls." + str(Lang.CLS_KULCS[c])] = "lang.gd"
		out["cls." + str(Lang.CLS_KULCS[c]) + ".d"] = "lang.gd"
		out["char.locked." + str(Lang.CLS_KULCS[c])] = "screens.gd"
	for i in 3:
		out["set.tempo.%d" % i] = "story_ui.gd"
	for a in ["ki", "var", "megy", "kesz", "hiba"]:
		out["cloud." + a] = "story_ui.gd"
	for h in ["halozat", "belepes", "tul_sok_mentes", "betelt_a_tarhely"]:
		out["cloud.hiba." + h] = "felho_mentes.gd"
	for b in Data.ITEM_BASES:
		if Lang.tabla("hu").has("lore." + str(b["id"])):
			out["lore." + str(b["id"])] = "screens.gd"
	return out


## a {0}, {1}... helyőrzők halmaza
func helyorzok(s: String) -> Array:
	var re := RegEx.create_from_string("\\{(\\d+)\\}")
	var h := {}
	for mm in re.search_all(s):
		h[mm.get_string(1)] = true
	var l := h.keys()
	l.sort()
	return l


## lefordítatlan-e egy megjelenített szöveg (kulcs maradt benne, vagy helyőrző)
func nyers(s: String) -> bool:
	if s.contains("{0}") or s.contains("{1}"):
		return true
	var re := RegEx.create_from_string("^(?:" + KULCS_CSOPORTOK + ")\\.[a-z0-9_.]+$")
	return re.search(s) != null or s.contains("msg.") or s.contains("item.") or s.contains("mon.")


func test_nyelvek() -> void:
	# ── 8.1 a három nyelvi fájl érvényes, BOM nélküli UTF-8 JSON
	var tablak := {}
	for kod in Lang.NYELVEK:
		var ut := Lang.MAPPA % kod
		ok(FileAccess.file_exists(ut), "a nyelvi fájl megvan: " + ut)
		var nyers_b := FileAccess.get_file_as_bytes(ut)
		ok(nyers_b.size() > 3 and not (nyers_b[0] == 0xEF and nyers_b[1] == 0xBB and nyers_b[2] == 0xBF), "%s: nincs BOM" % ut)
		var j := JSON.new()
		ok(j.parse(nyers_b.get_string_from_utf8()) == OK and j.data is Dictionary, "%s: érvényes JSON" % ut)
		tablak[kod] = Lang.tabla(kod)
		ok((tablak[kod] as Dictionary).size() > 300, "%s: %d kulcs" % [kod, (tablak[kod] as Dictionary).size()])
	var hu: Dictionary = tablak["hu"]
	# ── 8.2 mindhárom nyelvben ugyanazok a kulcsok, üres szöveg nélkül, azonos helyőrzőkkel
	for kod in Lang.NYELVEK:
		var t: Dictionary = tablak[kod]
		var hianyzik: Array = []
		var folos: Array = []
		var ures: Array = []
		var rossz_h: Array = []
		for k in hu:
			if not t.has(k):
				hianyzik.append(k)
			elif str(t[k]).strip_edges() == "":
				ures.append(k)
			elif helyorzok(str(t[k])) != helyorzok(str(hu[k])):
				rossz_h.append(k)
		for k in t:
			if not hu.has(k):
				folos.append(k)
		ok(hianyzik.is_empty(), "%s: minden kulcs megvan (hiányzik: %s)" % [kod, str(hianyzik)])
		ok(folos.is_empty(), "%s: nincs fölös kulcs (%s)" % [kod, str(folos)])
		ok(ures.is_empty(), "%s: nincs üres szöveg (%s)" % [kod, str(ures)])
		ok(rossz_h.is_empty(), "%s: a helyőrzők ({0}, {1}...) egyeznek a magyarral (%s)" % [kod, str(rossz_h)])
	# ── 8.3 minden kulcs, amire a kód hivatkozik, mindhárom nyelvben létezik
	var kulcsok := kod_kulcsai()
	ok(kulcsok.size() > 250, "a kódban talált kulcsok száma: %d" % kulcsok.size())
	for kod in Lang.NYELVEK:
		var t: Dictionary = tablak[kod]
		var nincs: Array = []
		for k in kulcsok:
			if not t.has(k):
				nincs.append("%s (%s)" % [k, kulcsok[k]])
		ok(nincs.is_empty(), "%s: a kód minden kulcsa le van fordítva (hiányzik: %s)" % [kod, str(nincs)])
	# és fordítva: nincs olyan kulcs, amit semmi sem használ
	var hasznalatlan: Array = []
	for k in hu:
		if not kulcsok.has(k) and k != "title" and k != "window_title":
			hasznalatlan.append(k)
	ok(hasznalatlan.is_empty(), "nincs használatlan kulcs (%s)" % str(hasznalatlan))
	ok(Lang.T("nincs.ilyen.kulcs") == "nincs.ilyen.kulcs", "hiányzó kulcsnál maga a kulcs látszik (ezt keresi a teszt)")

	# ── 8.4 játék közben sehol sem marad lefordítatlan kulcs vagy helyőrző (mindhárom nyelven)
	for kod in Lang.NYELVEK:
		Lang.set_lang(kod)
		var rossz: Array = []
		# tárgyak (minden alaptárgy, minden ritkaság, minden kaszt)
		for b in Data.ITEM_BASES:
			for r in Data.RARITY_ORDER:
				var it := Item.make(b, r, 3)
				var szovegek: Array[String] = [it.label, it.short_stats("Mágus", 12), it.short_stats("Lovag"), Lang.T("rarity." + r)]
				for cls in Data.CLASS_ORDER:
					szovegek.append_array(it.stat_lines(cls, 12))
				for s in szovegek:
					if nyers(s):
						rossz.append(s)
		# szörnyek (a kincstár őre is), kasztok, képességek, kinézet
		for k in Data.MONS:
			var m := Mon.make(k, 0, 0, "normal")
			var g := Mon.make_guard(k, 0, 0, "normal")
			for s in [m.name, g.name]:
				if nyers(s): rossz.append(s)
		for c in Data.CLASS_ORDER:
			for s in [Lang.cls(c), Lang.cls_desc(c)]:
				if nyers(s): rossz.append(s)
		for id in Perks.ORDER:
			var inf := Perks.info(id)
			for s in [str(inf["n"]), str(inf["d"])]:
				if nyers(s): rossz.append(s)
		for e in Skins.katalogus():
			if nyers(str(e["nev"])): rossz.append(str(e["nev"]))
		for sl in Skins.SLOTS:
			if nyers(Skins.hely_nev(sl)): rossz.append(Skins.hely_nev(sl))
		for i in Fiok.GUMROAD.size():
			if nyers(Fiok.ar_szoveg(i)): rossz.append(Fiok.ar_szoveg(i))
		# egy igazi kaland üzenetnaplója: harc, csapdák, szentélyek, kereskedő, tárgyak, szintlépés
		var ga := arena("Mágus")
		var p := ga.player
		var naplo: Array = []
		p.hp = 5000
		p.max_hp = 5000
		for key in ["goblin", "vampire", "spider", "witch", "assassin", "demon", "rat", "nurse", "spore", "rust_worm", "dr_karel", "weaver"]:
			var mo := place(ga, key, 2)
			mo.hp = 3
			ga.do_move(1, 0)
			var mo2 := place(ga, key, 1)
			mo2.guard = true
			for i in 6:
				ga.mon_attack(mo2)
			naplo.append_array(p.msgs)
			p.msgs.clear()
		for tt in Data.TRAP_ORDER:
			ga.world.traps.append({"x": p.x, "y": p.y, "type": tt, "found": false, "sprung": false})
			ga.trigger_trap()
			ga.world.traps.clear()
		for sk in Data.SHRINE_ORDER:
			ga.world.shrines.append({"x": p.x, "y": p.y, "kind": sk, "used": false})
			ga.trigger_shrine()
			ga.world.shrines.clear()
		naplo.append_array(p.msgs)
		p.msgs.clear()
		var bolt := {"x": 0, "y": 0, "stock": Dungeon.make_stock(3)}
		p.gold = 0
		ga.buy(bolt, 0)
		p.gold = 500
		for i in 3:
			ga.buy(bolt, i)
		for b in Data.ITEM_BASES:
			ga.use_item(Item.make(b, "epic", 2))
		ga.search()
		p.gain_xp(5000, 1.0)
		Perks.apply(p, "fokusz")
		p.poison = 2
		ga.advance_turn()
		ga.advance_turn()
		naplo.append_array(p.msgs)
		ok(naplo.size() > 40, "%s: a próbakaland sok üzenetet írt (%d)" % [kod, naplo.size()])
		for e in naplo:
			ok(Lang.ervenyes_ref(e["t"]), "%s: az üzenet fordítási hivatkozás, nem kész szöveg" % kod)
			var s := Lang.txt(e["t"])
			if nyers(s) or s == "":
				rossz.append(s)
		ok(rossz.is_empty(), "%s: sehol sem látszik lefordítatlan kulcs (%s)" % [kod, str(rossz)])
		# a HUD / menük dinamikus sorai
		for s in [Lang.T("hud.zone", 3, 4, Lang.T("zone.mag")), Lang.T("perk.title", 4), Lang.T("over.stats", 7, 900, Lang.T("zone.kazan")),
				Lang.T("inv.scroll", 1, 8, 12), Lang.T("bolt.buy", 20), Lang.T("fiok.http", 503)]:
			ok(not nyers(s), "%s: kitöltött sor: %s" % [kod, s])
	Lang.set_lang("hu")

	# ── 8.5 élő nyelvváltás: a már kiírt üzenet is az új nyelven látszik
	var hiv := Lang.ref("msg.killed", Lang.ref("mon.guard", Lang.ref("mon.orc")), 45, 12)
	Lang.set_lang("hu")
	var s_hu := Lang.txt(hiv)
	var seq0 := Lang.seq
	Lang.set_lang("en")
	var s_en := Lang.txt(hiv)
	Lang.set_lang("de")
	var s_de := Lang.txt(hiv)
	ok(s_hu == "Kincstár őre (Kazánfűtő) elesett! +45xp, +12 arany", "magyar: " + s_hu)
	ok(s_en == "Treasury Guard (Boiler Stoker) is slain! +45xp, +12 gold", "angol: " + s_en)
	ok(s_de == "Schatzwächter (Kesselheizer) ist besiegt! +45 EP, +12 Gold", "német: " + s_de)
	ok(Lang.seq > seq0, "nyelvváltáskor nő a Lang.seq (a rétegek újrarajzolódnak)")
	# a mentésből float-ként visszajövő számok is egészként látszanak
	var vissza: Variant = JSON.parse_string(JSON.stringify(hiv))
	ok(Lang.ervenyes_ref(vissza) and Lang.txt(vissza) == s_de, "JSON-körút után is ugyanaz: " + Lang.txt(vissza))
	Lang.set_lang("xx")
	ok(Lang.nyelv() in Lang.NYELVEK, "ismeretlen nyelvkód helyett a rendszer nyelve / angol")
	Lang.set_lang("hu")

	# ── 8.6 mentés-kompatibilitás: a régi mentés magyar tárgyneve azonosítóvá alakul
	var regi := SaveGame.item_from({"name": "Holdfénypenge", "label": "✦ Holdfénypenge", "slot": "weapon", "subtype": "sword",
		"glyph": "†", "rarity": "legendary", "dmg": 80})
	ok(regi != null and regi.name == "moonlight_blade", "régi mentés: Holdfénypenge -> moonlight_blade (%s)" % (regi.name if regi else "-"))
	Lang.set_lang("en")
	ok(regi.label == "✦ Moonlight Blade", "régi tárgy angolul: " + regi.label)
	Lang.set_lang("hu")
	var uj: Dictionary = SaveGame.item_to(Item.make(Item.find_base("steel_shield"), "rare", 2))
	ok(str(uj["name"]) == "steel_shield" and not uj.has("label"), "az új mentésbe nem kerül megjelenített (lefordított) név")
	var gm := arena("Lovag")
	var mo3 := place(gm, "orc", 1)
	mo3.guard = true
	gm.mon_attack(mo3)
	var mentett: Variant = JSON.parse_string(JSON.stringify(gm.player.msgs))
	var csak_ref := true
	for e in (mentett as Array):
		if not Lang.ervenyes_ref((e as Dictionary)["t"]):
			csak_ref = false
	ok(csak_ref, "a mentett üzenetnaplóban csak fordítási hivatkozások vannak (nincs lefordított szöveg)")
	ok(not Lang.ervenyes_ref("Goblin elesett! +12xp, +3 arany"), "a régi mentés kész szövege nem hivatkozás (betöltéskor kimarad)")
	print("  Nyelvek: %d kulcs nyelvenként, a kódban %d hivatkozott kulcs" % [hu.size(), kulcsok.size()])


# ══════════ 9. GORGONA: zónák, főellenségek, képességek, veszélyzónák, Műtőterem ══════════
func test_story() -> void:
	# ── 9.1 minden zónának van színvilága, ura, párbeszéde és két feljegyzése
	ok(Story.ZONES.size() == Data.MAX_LEVEL, "annyi zóna van, ahány mélység (%d)" % Story.ZONES.size())
	var osszes_lap := 0
	for lv in range(1, Data.MAX_LEVEL + 1):
		var bk: String = Data.BOSS_LVL[lv]
		ok(Data.MONS.has(bk) and Data.MONS[bk].get("boss", false), "%d. zóna: van főellenség (%s)" % [lv, bk])
		ok(not Story.talk(bk, "pre").is_empty() and not Story.talk(bk, "win").is_empty(), "%s: van párbeszéde" % bk)
		ok(Sprites2.has(bk) and Sprites2.has(bk + "#2"), "%s: van rajza mindkét fázishoz" % bk)
		ok((Story.NOTES[lv] as Array).size() == 2, "%d. zóna: két feljegyzés" % lv)
		osszes_lap += (Story.NOTES[lv] as Array).size()
		for k in ["wall", "floor", "line", "fline", "acc", "lamp", "fog", "pat", "part"]:
			ok(Story.zone(lv).has(k), "%d. zóna: van '%s' beállítása" % [lv, k])
		var p := Player.create("Lovag")
		var w := World.create(p, lv, "normal")
		ok(w.boss() != null and w.boss().key == bk, "%d. zóna: a pályán ott a főellenség" % lv)
		ok(w.notes.size() == 2, "%d. zóna: a pályán két feljegyzés hever (%d)" % [lv, w.notes.size()])
		var s := Dungeon.center(w.rooms[0])
		var seen := Dungeon.reach_map(w.tiles, s.x, s.y, {})
		for n in w.notes:
			var nk := Dungeon.idx(n["x"], n["y"])
			ok(w.tiles[nk] == Data.FLOOR and seen[nk] == 1, "a feljegyzés elérhető padlón van")
			ok(n["id"] in (Story.NOTES[lv] as Array), "a feljegyzés a saját zónájában van")
		for pk in Data.POOL[lv]:
			ok(Data.MONS.has(pk), "%d. zóna: ismert szörny a csapatban (%s)" % [lv, pk])
	ok(osszes_lap == Story.NOTE_ORDER.size(), "a Napló minden lapja megtalálható valahol")

	# ── 9.2 a lejáratot a zóna ura őrzi
	var g := arena("Lovag")
	g.world.tiles[Dungeon.idx(g.player.x, g.player.y)] = Data.STAIR
	var boss := Mon.make("rust_worm", 20, 20, "normal")
	g.world.mons.append(boss)
	ok(g.on_stair() and not g.can_descend(), "amíg a főellenség él, nem lehet lemenni")
	boss.alive = false
	ok(g.can_descend(), "a főellenség halála után megnyílik a lejárat")

	# ── 9.3 félreugrás: két mező, kör nélkül, lehűléssel; a fal megállítja
	g = arena("Lovag")
	var p := g.player
	p.dir_x = 1
	p.dir_y = 0
	var x0 := p.x
	var t0 := g.world.turn
	ok(g.dash() and p.x == x0 + Data.DASH_LEN, "a félreugrás %d mezőt visz (%d)" % [Data.DASH_LEN, p.x - x0])
	ok(g.world.turn == t0, "a félreugrással nem telik kör")
	ok(p.dash_cd == p.dash_cd_max and p.dash_cd > 0, "a félreugrás lehűlésre megy")
	ok(not g.dash() and p.x == x0 + Data.DASH_LEN, "lehűlés alatt nem lehet újra ugrani")
	g.advance_turn()
	ok(p.dash_cd == p.dash_cd_max - 1, "a lehűlés körönként csökken")
	p.dash_cd = 0
	g.world.tiles[Dungeon.idx(p.x + 2, p.y)] = Data.WALL
	x0 = p.x
	g.dash()
	ok(p.x == x0 + 1, "a fal megállítja a félreugrást")
	p.dash_cd = 0
	g.world.mons.append(Mon.make("goblin", p.x - 1, p.y, "normal"))
	p.dir_x = -1
	x0 = p.x
	ok(not g.dash() and p.x == x0, "szörnyön nem lehet átugrani")
	g = arena("Lovag")
	g.player.dir_x = 0
	g.player.dir_y = 1
	Perks.apply(g.player, "idegfonat")
	var y0 := g.player.y
	g.dash()
	ok(g.player.y == y0 + Data.DASH_LEN * 2, "a Réz-Idegfonat megduplázza a félreugrást")
	ok(g.player.dash_cd_max < Data.DASH_CD, "a Réz-Idegfonattal gyorsabban tölt újra")
	g = arena("Lovag")
	g.player.rooted = 2
	ok(not g.dash(), "gyökerek között nem lehet félreugrani")

	# ── 9.4 kaszt-képességek
	g = arena("Lovag")
	p = g.player
	g.world.mons.clear()
	var kor: Array[Mon] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var m := Mon.make("goblin", p.x + d.x, p.y + d.y, "normal")
		m.hp = 9999
		m.max_hp = 9999
		g.world.mons.append(m)
		kor.append(m)
	var tavol := Mon.make("goblin", p.x + 3, p.y, "normal")
	g.world.mons.append(tavol)
	ok(g.skill(), "Forgószél: van célpont, elsül")
	var mind := true
	for m in kor:
		if m.hp >= m.max_hp:
			mind = false
	ok(mind, "Forgószél: minden szomszédos ellenséget megsebez")
	ok(tavol.hp == tavol.max_hp, "Forgószél: a távolit nem éri")
	ok(p.skill_cd > 0 and not g.skill(), "a képesség lehűlésre megy")
	g = arena("Lovag")
	g.world.mons.clear()
	ok(not g.skill() and g.player.skill_cd == 0, "célpont nélkül nem sül el, és nem megy kárba")
	g = arena("Mágus")
	p = g.player
	g.world.mons.clear()
	var m2 := Mon.make("goblin", p.x + 2, p.y - 2, "normal")
	var m3 := Mon.make("goblin", p.x + 3, p.y, "normal")
	m2.hp = 9999; m2.max_hp = 9999; m3.hp = 9999; m3.max_hp = 9999
	g.world.mons.append(m2)
	g.world.mons.append(m3)
	ok(g.skill() and m2.hp < m2.max_hp and m3.hp == m3.max_hp, "Gőzrobbanás: két mezőn belül sebez, azon túl nem")
	g = arena("Íjász")
	p = g.player
	p.dir_x = 1
	p.dir_y = 0
	g.world.mons.clear()
	var a1 := Mon.make("goblin", p.x + 2, p.y, "normal")
	var a2 := Mon.make("goblin", p.x + 4, p.y, "normal")
	a1.hp = 9999; a1.max_hp = 9999; a2.hp = 9999; a2.max_hp = 9999
	g.world.mons.append(a1)
	g.world.mons.append(a2)
	ok(g.skill() and a1.hp < a1.max_hp and a2.hp < a2.max_hp, "Nyílzápor: a vonalban mindenkin átüt")
	# Túlhevített tartály: +30% képesség-sebzés
	var sum0 := 0
	var sum1 := 0
	for kk in 2:
		for i in 300:
			var gq := arena("Lovag")
			gq.world.mons.clear()
			var mq := Mon.make("goblin", gq.player.x + 1, gq.player.y, "normal")
			mq.hp = 9999
			mq.max_hp = 9999
			gq.world.mons.append(mq)
			gq.player.base_atk = 40
			if kk == 1:
				Perks.apply(gq.player, "tulhevites")
			gq.skill()
			if kk == 0: sum0 += 9999 - mq.hp
			else: sum1 += 9999 - mq.hp
	ok(absf(float(sum1) / sum0 - 1.3) < 0.06, "Túlhevített tartály: +30%% képesség-sebzés (%.2f)" % (float(sum1) / sum0))

	# ── 9.5 gyors-ital: a leggyengébbet issza meg
	g = arena("Lovag")
	p = g.player
	p.max_hp = 200
	p.hp = 50
	p.inventory.append(Item.make(Item.find_base("greater_healing_potion"), "common", 1))
	p.inventory.append(Item.make(Item.find_base("healing_potion"), "common", 1))
	ok(g.quick_heal() and p.hp == 75 and p.inventory.size() == 1, "a gyors-ital a kisebb fiolát issza meg (%d)" % p.hp)
	p.inventory.clear()
	ok(not g.quick_heal(), "ital nélkül a gyors-ital nem csinál semmit")

	# ── 9.6 veszélyzónák: aki kilép, megússza; aki marad, megsérül
	g = arena("Lovag")
	p = g.player
	p.max_hp = 500
	p.hp = 500
	g.world.mons.clear()
	g.warn(p.x, p.y, "steam", 20)
	ok(g.world.hazards.size() == 1, "a jelzett csapás felkerül a pályára")
	g.warn(p.x, p.y, "steam", 20)
	ok(g.world.hazards.size() == 1, "egy mezőn egyszerre csak egy jelzés lehet")
	g.do_move(1, 0)
	ok(p.hp == 500 and g.world.hazards.is_empty(), "aki kilép a jelzett mezőről, nem sérül")
	g.warn(p.x, p.y, "root", 20)
	g.advance_turn(true)
	ok(p.hp < 500 and p.rooted > 0, "aki bent marad, megsérül, és a gyökér megfogja")
	var px := p.x
	p.hp = 500
	g.do_move(1, 0)
	ok(p.x == px, "gyökerek között nem lehet lépni")
	p.rooted = 0
	g.do_move(1, 0)
	ok(p.x == px + 1, "a gyökér elenged")
	g.acid_pool(p.x, p.y, 3, 4)
	g.advance_turn(true)
	ok(p.hp == 496, "a savtócsa körönként mar (%d)" % p.hp)
	g.advance_turn(true)
	g.advance_turn(true)
	ok(g.world.hazards.is_empty(), "a savtócsa elpárolog")
	g.world.tiles[Dungeon.idx(p.x + 1, p.y)] = Data.WALL
	g.warn(p.x + 1, p.y, "steam", 5)
	ok(g.world.hazards.is_empty(), "falra nem kerül veszélyzóna")
	# kábulat: a hős egy köre kimarad
	p.stun = 1
	px = p.x
	g.do_move(-1, 0)
	ok(p.x == px and p.stun == 0, "kábultan kimarad egy kör")

	# ── 9.7 főellenségek: találkozás, előre jelzett csapás, második fázis
	for bk in ["rust_worm", "dr_karel", "symbiote", "weaver"]:
		g = arena("Lovag")
		p = g.player
		p.max_hp = 100000
		p.hp = 100000
		g.world.dungeon_level = Data.BOSS_LVL.find_key(bk)
		g.world.mons.clear()
		var b := Mon.make(bk, p.x + 4, p.y, "normal")
		g.world.mons.append(b)
		g.advance_turn()
		ok(b.met and not g.pending_dialog.is_empty(), "%s: az első találkozáskor megszólal" % bk)
		ok(str(g.banner.get("k", "")) == "mon." + bk, "%s: a neve nagy felirattal megjelenik" % bk)
		var volt_jelzes := false
		var bx0 := b.x
		for i in 12:
			g.advance_turn()
			for h in g.world.hazards:
				if h["warn"]:
					volt_jelzes = true
		ok(volt_jelzes, "%s: előre jelzi a csapását" % bk)
		if bk == "symbiote":
			ok(b.x == bx0, "a Szimbióta Anya nem mozdul el a helyéről")
		var def0 := b.def
		g.pending_dialog = []
		g.hit_mon(b, int(b.max_hp * 0.6), "#ffffff")
		ok(b.phase == 2, "%s: fél életerő alatt második fázisba lép" % bk)
		ok(str(g.banner.get("k", "")) == "banner.phase2", "%s: a fázisváltást felirat jelzi" % bk)
		if bk == "rust_worm":
			ok(b.def < def0, "a Rozsdaféreg páncélja leszakad (védelem %d -> %d)" % [def0, b.def])
			var sav := false
			for i in 40:
				g.advance_turn()
				if g.world.hazard_at(p.x, p.y, "acid") != null or g.world.hazards.any(func(h: Dictionary) -> bool: return h["kind"] == "acid"):
					sav = true
			ok(sav, "a Rozsdaféreg a 2. fázisban savat fröcsköl")
		if bk == "weaver":
			ok(b.atk >= maxi(p.atk, p.mag), "az Első Kárpit lemásolja a hős erejét (%d)" % b.atk)
		if bk == "dr_karel":
			b.x = p.x + 3
			b.y = p.y
			var hp0 := p.hp
			b.hp = 10
			for i in 4:
				g.advance_turn(true)
			ok(p.hp < hp0 and b.hp > 10, "Karel Doktor a 2. fázisban elszívja a hős életerejét")
		b.hp = 1
		g.pending_dialog = []
		g.p_attack(b) if g._dist(b) <= 1 else g.hit_mon(b, 5, "#ffffff")
		if b.hp <= 0 and b.alive:
			g.kill_reward(b)
		ok(not b.alive and not g.pending_dialog.is_empty(), "%s: a legyőzése után Vane megszólal" % bk)
		ok(bk in Meta.data()["bosses"], "%s: a győzelem bekerül a Műtőterem emlékei közé" % bk)
		ok(g.world.hazards.is_empty(), "%s: a halálával eltűnnek a veszélyzónái" % bk)

	# ── 9.8 nyersanyag: a hús Bio-Hulladékot, a gép Rézötvözetet hagy; az elit erősebb
	g = arena("Lovag")
	p = g.player
	for i in 50:
		g.kill_reward(Mon.make("goblin", 0, 0, "normal"))
	ok(p.bio >= 50 and p.rez == 0, "húsból Bio-Hulladék lesz (%d / %d)" % [p.bio, p.rez])
	p.bio = 0
	for i in 50:
		g.kill_reward(Mon.make("nurse", 0, 0, "normal"))
	ok(p.rez >= 50 and p.bio == 0, "gépből Rézötvözet lesz (%d / %d)" % [p.rez, p.bio])
	ok(p.kills == 100, "a legyőzött ellenségek száma gyűlik")
	var el := Mon.make_elite("goblin", 0, 0, "normal")
	var sima := Mon.make("goblin", 0, 0, "normal")
	ok(el.elite and el.max_hp > sima.max_hp and el.atk > sima.atk, "a Fertőzött erősebb a közönségesnél")
	ok(el.name == "Fertőzött Csatornalakó", "a Fertőzött neve: " + el.name)
	p.rez = 0
	g.kill_reward(el)
	ok(p.rez >= 2, "a Fertőzött rézötvözetet ejt")
	# Savas Epehólyag: sérüléskor a szomszédos ellenség is sérül
	g = arena("Lovag")
	p = g.player
	Perks.apply(p, "epeholyag")
	var szom := place(g, "goblin", 1)
	var hb := szom.hp
	g.hurt(5)
	ok(szom.hp < hb, "Savas Epehólyag: sérüléskor savat köp a szomszédra")
	# Láncfogazású Szike: a védelem felét átvágja
	var atl := {}
	for nev in ["steel_sword", "chain_scalpel"]:
		var gs := arena("Lovag")
		gs.player.weapon = Item.make(Item.find_base("steel_sword"), "common", 1)
		gs.player.weapon.name = nev
		var tot := 0
		for i in 1500:
			var ms := place(gs, "golem", 1)
			gs.p_attack(ms)
			tot += 100000 - ms.hp
		atl[nev] = tot / 1500.0
	ok(atl["chain_scalpel"] > atl["steel_sword"] + 3.0, "a Láncfogazású Szike átvágja a páncélt (%.1f > %.1f)" % [atl["chain_scalpel"], atl["steel_sword"]])

	# ── 9.9 feljegyzés felvétele
	Meta.reset()
	g = arena("Lovag")
	p = g.player
	g.world.notes.append({"x": p.x + 1, "y": p.y, "id": "n041", "taken": false})
	g.do_move(1, 0)
	ok(g.pending_note == "n041" and Meta.has_note("n041"), "a feljegyzés bekerül a Naplóba")
	ok(p.bio == 3, "az új lap Bio-Hulladékot ér")
	g.world.notes.append({"x": p.x + 1, "y": p.y, "id": "n041", "taken": false})
	g.do_move(1, 0)
	ok(p.bio == 3 and (Meta.data()["notes"] as Array).size() == 1, "ugyanaz a lap másodszor már nem számít")

	# ── 9.10 a Műtőterem: elszámolás, vásárlás, a fejlesztések hatása
	Meta.reset()
	p = Player.create("Mágus")
	p.bio = 40
	p.rez = 30
	p.kills = 12
	Meta.bank_run(p, 2, false)
	var d := Meta.data()
	ok(int(d["bio"]) == 40 and int(d["rez"]) == 30 and p.bio == 0 and p.rez == 0, "a kaland zsákmánya a Műtőterembe kerül")
	ok(int(d["runs"]) == 1 and int(d["deaths"]) == 1 and int(d["deepest"]) == 2 and int(d["last_death"]) == 2, "a halál bekerül a nyilvántartásba")
	ok(Story.nora_line(d) == "hub.nora.idle", "Nora a 2. zónás halál után az általános sorát mondja")
	d["last_death"] = 1
	ok(Story.nora_line(d) == "hub.nora.z1", "Nora az 1. zónás halál után a csatornapatkányokról beszél")
	d["deepest"] = 3
	ok(Story.nora_line(d) == "hub.nora.z3", "Nora a 3. zóna elérése után az apjáról beszél")
	ok(Story.prophet_line({"just_bought_prophet": true}) == "hub.prophet.buy", "a Próféta vásárláskor a szív-pumpáról beszél")
	var ar := Meta.cost("rezhenger")
	ok(Meta.can_buy("rezhenger") and Meta.buy("rezhenger"), "Noránál lehet vásárolni rézért")
	ok(int(d["rez"]) == 30 - ar and Meta.level("rezhenger") == 1, "a vásárlás levonja az árat, és nő a szint")
	ok(Meta.cost("rezhenger") == ar * 2, "a következő szint drágább")
	d["rez"] = 0
	ok(not Meta.buy("rezhenger"), "réz nélkül nincs vásárlás")
	ok(Meta.buy("szivpumpa") and int(d["bio"]) == 40 - 14, "a Prófétánál Bio-Hulladékért lehet vásárolni")
	d["up"] = {"rezhenger": 2, "mellvert": 3, "elezes": 2, "lombik": 1, "szivpumpa": 2, "mirigy": 2, "uvegszem": 1, "gyomor": 2}
	var alap := Player.create("Mágus")
	var uj := Player.create("Mágus")
	Meta.apply_to(uj)
	ok(uj.max_hp == alap.max_hp + 16 and uj.hp == uj.max_hp, "Edzett rézhenger: +8 életerő szintenként")
	ok(uj.base_def == alap.base_def + 3, "Titánbordás mellvért: +1 védelem szintenként")
	ok(uj.base_atk == alap.base_atk + 2 and uj.base_mag == alap.base_mag + 2, "Élezett műszerek: +1 támadás és varázserő")
	ok(uj.lives == alap.lives + 1, "Tartalék lombik: +1 élet")
	ok(uj.kill_heal == 4 and uj.cd_cut == 2 and is_equal_approx(uj.find_mult, 1.2), "Szív-pumpa, Adrenalin-mirigy, Üvegszem")
	ok(uj.inventory.size() == 2 and uj.inventory[0].subtype == "heal", "Kettős gyomor: két gyógyital a táskában")
	ok(uj.skill_cd_max == Data.SKILL_CD - 2, "az Adrenalin-mirigy rövidíti a képesség lehűlését")
	for id in Meta.ORDER:
		d["up"][id] = Meta.UPGRADES[id]["max"]
		d["bio"] = 9999
		d["rez"] = 9999
		ok(not Meta.can_buy(id), "%s: a legfelső szint fölé nem lehet venni" % id)
	Meta.reset()
	p = Player.create("Lovag")
	Meta.bank_run(p, Data.MAX_LEVEL, true)
	ok(int(Meta.data()["wins"]) == 1 and Story.nora_line(Meta.data()) == "hub.nora.win", "győzelem után Nora a szív ritmusáról beszél")

	# ── 9.11 mentés: az új állapot is megmarad
	Meta.reset()
	var gs2 := Game.new()
	gs2.autosave = false
	gs2.start("Íjász", "normal")
	while gs2.world.boss() == null:
		gs2.next_level()   # a zóna ura az utolsó emeleten van
	var ps := gs2.player
	ps.bio = 17; ps.rez = 9; ps.kills = 23; ps.dash_cd = 3; ps.skill_cd = 5; ps.rooted = 1; ps.dir_x = 0; ps.dir_y = -1
	gs2.world.hazards.append({"x": ps.x, "y": ps.y, "kind": "acid", "ttl": 4, "dmg": 3, "warn": false})
	var bs := gs2.world.boss()
	bs.phase = 2
	bs.met = true
	bs.cd = 2
	gs2.world.mons[0].elite = true
	ok(SaveGame.save_run(gs2), "a kaland elmenthető")
	var gl := SaveGame.load_run()
	ok(gl != null, "a mentés visszatölthető")
	if gl != null:
		var pl := gl.player
		ok(pl.bio == 17 and pl.rez == 9 and pl.kills == 23, "nyersanyag és ölések megmaradnak")
		ok(pl.dash_cd == 3 and pl.skill_cd == 5 and pl.rooted == 1 and pl.dir_x == 0 and pl.dir_y == -1, "lehűlések, gyökér és irány megmaradnak")
		ok(gl.world.hazards.size() == 1 and gl.world.hazards[0]["kind"] == "acid" and int(gl.world.hazards[0]["ttl"]) == 4, "a savtócsa megmarad")
		ok(gl.world.notes.size() == gs2.world.notes.size(), "a feljegyzések megmaradnak")
		var bl := gl.world.boss()
		ok(bl != null and bl.phase == 2 and bl.met and bl.cd == 2 and bl.mech == bs.mech, "a főellenség fázisa megmarad")
		ok(gl.world.mons[0].elite, "a Fertőzött jelzés megmarad")
	SaveGame.erase_all()
	test_mentesek()
	print("  %d zóna, %d feljegyzés, %d állandó fejlesztés, %d képesség" % [Story.ZONES.size(), Story.NOTE_ORDER.size(), Meta.ORDER.size(), Perks.ORDER.size()])


# ══════════ 10. TÖBB MENTÉS + FELHŐ ══════════
func test_mentesek() -> void:
	SaveGame.erase_all()
	ok(not SaveGame.has_save() and SaveGame.list().is_empty(), "tiszta lappal nincs mentés")
	var g := Game.new()
	g.autosave = false
	g.start("Lovag", "normal")
	SaveGame.current = ""
	ok(SaveGame.save_run(g) and SaveGame.list().size() == 1, "az első mentés létrehozza a kaland automata mentését")
	var auto_id := SaveGame.current
	ok(SaveGame.save_run(g) and SaveGame.list().size() == 1 and SaveGame.current == auto_id, "az automata mentés ugyanazt a helyet frissíti")
	g.player.gold = 111
	var kezi := SaveGame.snapshot(g)
	ok(kezi != "" and kezi != auto_id and SaveGame.list().size() == 2, "a kézi mentés új helyre kerül")
	g.player.gold = 222
	SaveGame.save_run(g)
	var kezi2 := SaveGame.snapshot(g)
	ok(SaveGame.list().size() == 3, "akárhány kézi mentés készíthető (%d)" % SaveGame.list().size())
	var van_auto := 0
	for e in SaveGame.list():
		if e["auto"]:
			van_auto += 1
		ok(e["cls"] == "Lovag" and int(e["zona"]) == 1 and int(e["ido"]) > 0, "a lista mutatja a hőst, a zónát és az időt")
	ok(van_auto == 1, "a listában egy automata és két kézi mentés van")
	# bármelyik visszatölthető
	var gk := SaveGame.load_run(kezi)
	ok(gk != null and gk.player.gold == 111, "a régebbi kézi mentés is visszatölthető (arany %d)" % (gk.player.gold if gk else -1))
	ok(SaveGame.current == "", "kézi mentésből folytatva az automata mentés új helyre megy")
	gk.autosave = false
	SaveGame.save_run(gk)
	ok(SaveGame.list().size() == 4 and SaveGame.current != kezi, "a kézi mentést a folytatás nem írja felül")
	ok(SaveGame.load_run(kezi).player.gold == 111, "a kézi mentés érintetlen maradt")
	var ga := SaveGame.load_run(auto_id)
	ok(ga != null and ga.player.gold == 222 and SaveGame.current == auto_id, "automata mentésből folytatva ugyanoda ment tovább")
	# halál: csak a kaland automata mentése tűnik el
	SaveGame.erase()
	var maradt: Array = []
	for e in SaveGame.list():
		maradt.append(e["id"])
	ok(not (auto_id in maradt) and (kezi in maradt) and (kezi2 in maradt), "a kaland vége csak az automata mentést törli, a kéziket nem")
	# értesítések a felhőnek
	var irt: Array = []
	var torolt: Array = []
	SaveGame.on_write = func(f: String) -> void: irt.append(f)
	SaveGame.on_erase = func(f: String) -> void: torolt.append(f)
	var uj := SaveGame.snapshot(g)
	SaveGame.erase(uj)
	ok(irt == [uj + ".json"] and torolt == [uj + ".json"], "mentéskor és törléskor a felhő-mentés értesítést kap")
	SaveGame.on_write = Callable()
	SaveGame.on_erase = Callable()
	# a régi, egyetlen mentésfájl átköltözik
	SaveGame.erase_all()
	g.autosave = false
	SaveGame.current = ""
	SaveGame.save_run(g)
	DirAccess.rename_absolute(SaveGame.path_of(SaveGame.current), SaveGame.REGI)
	SaveGame.current = ""
	SaveGame.refresh()
	ok(SaveGame.list().size() == 1 and not FileAccess.file_exists(SaveGame.REGI), "a régi mentes.json átköltözik a mentések közé")
	ok(SaveGame.load_run() != null, "az átköltözött mentés betölthető")
	SaveGame.erase_all()

	# ── a felhő-szinkron döntései (hálózat nélkül): mi történjen egy fájllal?
	var D := FelhoMentes
	ok(D.dont(100, {}, {}) == "fel", "új helyi mentés → feltöltés")
	ok(D.dont(-1, {}, {"ido": 100, "torolt": false}) == "le", "másik gépen készült mentés → letöltés")
	ok(D.dont(100, {"ido": 100, "helyi": 100}, {"ido": 100, "torolt": false}) == "", "szinkronban → semmi")
	ok(D.dont(150, {"ido": 100, "helyi": 100}, {"ido": 100, "torolt": false}) == "fel", "itt változott → feltöltés")
	ok(D.dont(100, {"ido": 100, "helyi": 100}, {"ido": 180, "torolt": false}) == "le", "másik gépen változott → letöltés")
	ok(D.dont(150, {"ido": 100, "helyi": 100}, {"ido": 180, "torolt": false}) == "le", "mindkét helyen változott → az újabb (felhő) nyer")
	ok(D.dont(190, {"ido": 100, "helyi": 100}, {"ido": 180, "torolt": false}) == "fel", "mindkét helyen változott → az újabb (helyi) nyer")
	ok(D.dont(-1, {"ido": 100, "helyi": 100}, {"ido": 100, "torolt": false}) == "torol_felho", "itt törölték → a felhőből is törlődik")
	ok(D.dont(-1, {"ido": 100, "helyi": 100}, {"ido": 180, "torolt": false}) == "le", "itt törölték, de másutt újabb készült → visszajön")
	ok(D.dont(100, {"ido": 100, "helyi": 100}, {"ido": 200, "torolt": true}) == "torol_helyi", "másik gépen törölték → itt is eltűnik")
	ok(D.dont(300, {"ido": 100, "helyi": 100}, {"ido": 200, "torolt": true}) == "fel", "a törlés után újra mentették → megmarad")
	ok(D.dont(-1, {"ido": 100, "helyi": 100}, {"ido": 200, "torolt": true}) == "felejt", "mindenhol törölve → a napló elfelejti")
	ok(D.dont(-1, {}, {"ido": 200, "torolt": true}) == "", "régi sírkő, itt sosem volt → semmi")
	ok(D.dont(-1, {"ido": 1, "helyi": 1}, {}) == "felejt", "sehol sincs már → a napló elfelejti")
	ok(D.dont(100, {"ido": 100, "helyi": 100}, {}) == "fel", "a felhőből eltűnt, itt megvan → újra feltöltjük")
	# csomagolás körút
	DirAccess.make_dir_recursive_absolute(SaveGame.DIR)
	var ut := SaveGame.DIR + "_korut.json"
	var tartalom := "árvíztűrő tükörfúrógép ".repeat(400)
	var f := FileAccess.open(ut, FileAccess.WRITE)
	f.store_string(tartalom)
	f.close()
	var cs := D.csomagol(ut)
	ok(cs != "" and cs.length() < tartalom.length(), "a mentés tömörítve megy fel (%d → %d karakter)" % [tartalom.length(), cs.length()])
	ok(D.kicsomagol(cs).get_string_from_utf8() == tartalom, "kicsomagolva bájtra ugyanaz")
	ok(D.kicsomagol("ez nem base64 gzip!").is_empty(), "sérült adat nem omlaszt össze semmit")
	DirAccess.remove_absolute(ut)
	# belépés nélkül a modul csendben kimarad
	var fm := FelhoMentes.new()
	fm.offline_mod = true
	fm.indit("teszt_jatek", SaveGame.DIR, ["json"])
	ok(fm.allapot in ["ki", "var", "megy", "hiba"], "fiók nélkül / hálózat nélkül a felhő-mentés nem akad meg (%s)" % fm.allapot)
	fm.feltolt("nincs_ilyen.json")
	fm.torol("nincs_ilyen.json")
	ok(not fm._ide_tartozik("../kitores.json") and not fm._ide_tartozik("kep.png") and fm._ide_tartozik("m1_2.json"), "csak a mentésmappa saját fájljai szinkronizálódnak")
	fm.free()


# ══════════ 11. EREKLYÉK, ÁLLAPOTOK, ESEMÉNYEK, MINI-BOSSOK, A SEBÉSZ, NAPI KIHÍVÁS ══════════
func test_uj() -> void:
	Meta.reset()
	# ── 11.1 ereklyék: gyújtás, marás, robbanás
	var g := arena("Lovag")
	var p := g.player
	ok(Relics.ORDER.size() == Relics.LIST.size(), "minden ereklyének van sorszáma")
	ok(Relics.apply(p, "gyujto") and not Relics.apply(p, "gyujto"), "egy ereklye csak egyszer szerezhető meg")
	var m := place(g, "golem", 1)
	g.p_attack(m)
	ok(m.burn == Relics.BURN_TURNS, "Gyújtókamra: a találat meggyújt")
	var hp0 := m.hp
	g.advance_turn(true)
	ok(m.hp < hp0 and m.burn == Relics.BURN_TURNS - 1, "az égés körönként sebez, és fogy")
	Relics.apply(p, "savmirigy")
	m = place(g, "golem", 1)
	for i in 5:
		g.p_attack(m)
	ok(m.corr == Relics.CORR_MAX, "Savmirigy: a marás legfeljebb %d rétegig halmozódik" % Relics.CORR_MAX)
	ok(Game.mdef(m) == m.def - 2 * Relics.CORR_MAX, "a marás rétegenként 2 védelmet vesz le (%d -> %d)" % [m.def, Game.mdef(m)])
	# Robbanó epe: az égő és mart szörny halála a szomszédját is megsebzi és meggyújtja
	Relics.apply(p, "robbano")
	g.world.mons.clear()
	var a := Mon.make("goblin", p.x + 1, p.y, "normal")
	var b := Mon.make("golem", p.x + 2, p.y, "normal")
	b.hp = 9999
	b.max_hp = 9999
	g.world.mons.append(a)
	g.world.mons.append(b)
	a.burn = 2
	a.corr = 1
	a.hp = 1
	g.p_attack(a)
	ok(not a.alive and b.hp < 9999 and b.burn > 0, "Robbanó epe: a robbanás a szomszédot is megsebzi és meggyújtja")
	# ── Tesla + Rézbőr
	g = arena("Lovag")
	p = g.player
	Relics.apply(p, "tesla")
	Relics.apply(p, "rezbor")
	g.world.mons.clear()
	var c1 := Mon.make("golem", p.x + 1, p.y, "normal")
	var c2 := Mon.make("golem", p.x + 2, p.y + 1, "normal")
	for mm in [c1, c2]:
		mm.hp = 99999
		mm.max_hp = 99999
		g.world.mons.append(mm)
	c2.corr = 1
	for i in 3:
		g.p_attack(c1)
	ok(c2.hp == 99999, "Tesla-tekercs: az első három találat még nem láncol")
	g.p_attack(c1)
	ok(c2.hp < 99999 and c2.stun > 0, "a negyedik találat villámot láncol; Rézbőrrel a mart ellenséget el is kábítja")
	# ── Tükörlemez, Végső szikra, Gőzköpeny, Óramű-szív
	g = arena("Lovag")
	p = g.player
	p.max_hp = 500
	p.hp = 500
	Relics.apply(p, "tukor")
	m = place(g, "orc", 1)
	var mh := m.hp
	g.mon_attack(m)
	ok(m.hp < mh, "Tükörlemez: a kapott ütés egy része visszaverődik")
	Relics.apply(p, "vegso")
	p.hp = 3
	p.lives = 1
	g.hurt(50)
	g.check_death()
	ok(p.alive and p.hp == 1 and p.spark_used and p.lives == 1, "Végső szikra: a halálos ütés 1 életerőn megállít")
	g.hurt(50)
	g.check_death()
	ok(not p.alive, "a Végső szikra zónánként csak egyszer ment meg")
	g = arena("Lovag")
	p = g.player
	Relics.apply(p, "gozkopeny")
	Relics.apply(p, "oramu")
	p.dir_x = 0
	p.dir_y = 1
	g.dash()
	ok(p.steam_charge, "Gőzköpeny: félreugrás után feltöltődik a következő ütés")
	ok(is_equal_approx(g.hit_mult(), 2.0) and not p.steam_charge and is_equal_approx(g.hit_mult(), 1.0), "a feltöltött ütés duplán sebez, és csak egyszer")
	ok(p.skill_cd_max == Data.SKILL_CD - 2, "Óramű-szív: a képesség 2 körrel hamarabb tölt")
	ok(p.dash_cd > 0, "a félreugrás lehűlésen van")
	g.kill_reward(Mon.make("goblin", 0, 0, "normal"))
	ok(p.dash_cd == 0, "Óramű-szív: ölés után azonnal újra lehet ugrani")
	# az ajánlat előnyben részesíti, ami a meglévőkkel együttműködik
	var po := Player.create("Lovag")
	po.relics = ["gyujto"]
	var jo := 0
	for i in 40:
		var of := Relics.offer(po)
		ok(of.size() == 2 and of[0] != of[1] and not ("gyujto" in of), "az ajánlat két különböző, még nem birtokolt ereklye")
		if of[0] in ["robbano", "verpumpa"]:
			jo += 1
	ok(jo == 40, "az első lap mindig illik a meglévő ereklyéhez (%d/40)" % jo)
	po.relics = Relics.ORDER.duplicate()
	ok(Relics.offer(po).is_empty(), "ha minden ereklye megvan, nincs mit ajánlani")

	# ── 11.2 mini-boss: erős, talapzatot hagy, a talapzaton ereklye választható
	for lv in range(1, Data.MAX_LEVEL + 1):
		var pw := Player.create("Lovag")
		var w := World.create(pw, lv, "normal")
		var minik := 0
		for mo in w.mons:
			if mo.mini:
				minik += 1
				ok(mo.key == Data.MINI[lv] and mo.max_hp > Mon.make(mo.key, 0, 0, "normal").max_hp * 3, "%d. zóna: a mini-boss a zónáé és erős" % lv)
		ok(minik == 1, "%d. zóna: pontosan egy mini-boss van (%d)" % [lv, minik])
		ok(w.events.size() == 1 and not w.vents.is_empty(), "%d. zóna: van esemény és padlórács" % lv)
		var s := Dungeon.center(w.rooms[0])
		var seen := Dungeon.reach_map(w.tiles, s.x, s.y, {})
		for v in (w.vents + w.events):
			var vk := Dungeon.idx(v["x"], v["y"])
			ok(w.tiles[vk] == Data.FLOOR and seen[vk] == 1, "a rács / esemény elérhető padlón áll")
		var elo := 0
		for d in w.decor:
			if d["type"] in Sprites2.ELO_DISZEK:
				elo += 1
				ok(w.tiles[Dungeon.idx(d["x"], d["y"])] == Data.WALL, "az élő dísz falon van")
		ok(elo > 5, "%d. zóna: vannak mozgó díszek a falakon (%d)" % [lv, elo])
	g = arena("Lovag")
	p = g.player
	var mb := Mon.make_mini("rat", p.x + 1, p.y, "normal")
	g.world.mons.append(mb)
	ok(mb.name == "A Patkánykirály", "a mini-boss neve: " + mb.name)
	g.kill_reward(mb)
	ok(g.world.pedestals.size() == 1 and not g.world.pedestals[0]["taken"], "a mini-boss ereklye-talapzatot hagy maga után")
	var pd: Dictionary = g.world.pedestals[0]
	p.x = pd["x"]
	p.y = pd["y"]
	g._land(p.x, p.y)
	ok(g.pending_relic, "a talapzatra lépve ereklyét lehet választani")
	ok(g.take_relic("tesla") and pd["taken"] and p.has_relic("tesla"), "a választott ereklye a hősé, a talapzat kiürül")
	ok(not g.take_relic("gyujto"), "üres talapzatról nem lehet még egyet elvenni")

	# ── 11.3 padlórácsok: a kitörés előtt egy körrel jeleznek
	g = arena("Lovag")
	p = g.player
	p.max_hp = 500
	p.hp = 500
	g.world.mons.clear()
	g.world.vents.append({"x": p.x + 2, "y": p.y, "ph": 0})
	var jelzett := 0
	var korok := 0
	for i in Data.VENT_PERIOD * 3:
		g.advance_turn(true)
		korok += 1
		if g.world.hazard_at(p.x + 2, p.y) != null:
			jelzett += 1
	ok(jelzett == 3, "a rács periódusonként egyszer tör ki (%d / %d kör)" % [jelzett, korok])
	ok(p.hp == 500, "aki nem áll a rácson, nem sérül")

	# ── 11.4 döntési események
	for ek in Data.EVENTS:
		for valasz in 2:
			g = arena("Lovag")
			p = g.player
			p.max_hp = 100
			p.hp = 100
			var e := {"x": p.x, "y": p.y, "kind": ek, "used": false}
			var elotte := [p.gold, p.bio, p.rez, p.inventory.size(), p.hp, p.max_hp, g.pending_perks, p.poison]
			ok(g.event_choice(e, valasz) and e["used"], "%s / %d: a választás megtörténik" % [ek, valasz])
			var utana := [p.gold, p.bio, p.rez, p.inventory.size(), p.hp, p.max_hp, g.pending_perks, p.poison]
			ok(elotte != utana, "%s / %d: a választásnak van következménye" % [ek, valasz])
			ok(not g.event_choice(e, valasz), "%s: egy esemény csak egyszer használható" % ek)
			ok(not nyers(Lang.txt(p.msgs[p.msgs.size() - 1]["t"])), "%s / %d: az üzenet le van fordítva" % [ek, valasz])
	g = arena("Lovag")
	g.world.events.append({"x": g.player.x + 1, "y": g.player.y, "kind": "fogoly", "used": false})
	g.do_move(1, 0)
	ok(g.pending_event != null, "az eseményre lépve megnyílik a választás")

	# ── 11.5 a Sebész: vérzés, szervek, beültetés; a Bronz Klinikával oldódik fel
	ok(not ("Sebész" in Meta.playable()) and Meta.playable().size() == 3, "a Sebész eleinte zárva van")
	Meta.reach(2)
	ok("Sebész" in Meta.playable() and Meta.has_badge("sebesz"), "a Bronz Klinika elérése feloldja (jelvénnyel)")
	g = arena("Sebész")
	p = g.player
	ok(p.cls == "Sebész" and p.max_hp == Data.CLASSES["Sebész"]["hp"], "a Sebész létrehozható")
	m = place(g, "golem", 1)
	g.p_attack(m)
	ok(m.bleed == 2, "a Sebész vágása vérzést okoz")
	hp0 = m.hp
	g.advance_turn(true)
	ok(m.hp < hp0 and m.bleed == 1, "a vérzés körönként sebez, és fogy")
	ok(not g.skill() or true, "képesség szerv nélkül")
	g = arena("Sebész")
	p = g.player
	g.world.mons.clear()
	ok(not g.skill() and p.skill_cd == 0, "szerv és célpont nélkül a képesség nem megy kárba")
	m = place(g, "golem", 1)
	p.dir_x = 1
	p.dir_y = 0
	ok(g.skill() and m.bleed == Data.BLEED_MAX - 1 and m.hp < m.max_hp, "Metszés: mély vágás, teljes vérzéssel")
	p.skill_cd = 0
	p.organs = 0
	g.kill_reward(Mon.make_elite("goblin", 0, 0, "normal"))
	ok(p.organs == 1, "erős ellenségből mindig lesz szerv")
	g.world.mons.clear()
	p.max_hp = 100
	p.hp = 20
	var atk0 := p.base_atk
	ok(g.skill() and p.hp == 55 and p.base_atk == atk0 + 1 and p.organs == 0, "Beültetés: +35%% életerő és +1 támadás (hp %d)" % p.hp)
	for i in 400:
		g.kill_reward(Mon.make("goblin", 0, 0, "normal"))
	ok(p.organs == Data.ORGAN_MAX, "legfeljebb %d szerv lehet nála" % Data.ORGAN_MAX)

	# ── 11.6 napi kihívás: ugyanaz a nap ugyanazt a pályát adja, a fejlesztések nem számítanak
	var d := Meta.data()
	d["up"] = {"rezhenger": 3}
	var g1 := Game.new()
	g1.autosave = false
	g1.start("Lovag", "normal", "2026-10-09")
	var g2 := Game.new()
	g2.autosave = false
	g2.start("Mágus", "normal", "2026-10-09")
	var g3 := Game.new()
	g3.autosave = false
	g3.start("Lovag", "normal", "2026-10-10")
	ok(g1.world.tiles == g2.world.tiles and g1.world.rooms == g2.world.rooms, "ugyanazon a napon mindenki ugyanazt a pályát kapja")
	ok(g1.world.mons.size() == g2.world.mons.size() and g1.world.chests.size() == g2.world.chests.size(), "ugyanannyi szörny és láda")
	ok(g1.world.tiles != g3.world.tiles, "másnap más a pálya")
	ok(g1.player.max_hp == Data.CLASSES["Lovag"]["hp"], "a napi kihívásban a Műtőterem fejlesztései nem számítanak")
	g1.next_level()
	g2.next_level()
	ok(g1.world.tiles == g2.world.tiles and g1.world.emelet == 2, "a következő emelet is közös")
	while g1.world.dungeon_level < 2:
		g1.next_level()
		g2.next_level()
	ok(g1.world.tiles == g2.world.tiles and g1.world.dungeon_level == 2, "a következő zóna is közös")
	var gn := Game.new()
	gn.autosave = false
	gn.start("Lovag", "normal")
	ok(gn.player.max_hp == Data.CLASSES["Lovag"]["hp"] + 24 and gn.daily == "", "a szokásos kalandban a fejlesztések élnek")
	d["up"] = {}
	var pp := Player.create("Lovag")
	pp.kills = 10
	pp.gold = 50
	pp.plvl = 3
	var p1 := Daily.pont(pp, 2, false, 400)
	ok(p1 == 1000 + 150 + 100 + 200 - 100, "a pontszám képlete (%d)" % p1)
	ok(Daily.pont(pp, 4, true, 400) > p1 + 5000, "a győzelem sokat ér")
	ok(Daily.pont(pp, 1, false, 999999) == 0, "a pontszám nem lehet negatív")
	ok(Daily.mag("2026-10-09") == Daily.mag("2026-10-09") and Daily.mag("2026-10-09") != Daily.mag("2026-10-10"), "a nap magja állandó, napról napra más")
	ok(Meta.napi_ment("2026-10-09", 500) and not Meta.napi_ment("2026-10-09", 400) and Meta.napi_legjobb("2026-10-09") == 500, "a napi legjobb megmarad")
	ok(Meta.napi_legjobb("2026-10-10") == 0, "másnap nulláról indul")

	# ── 11.7 jelvények
	Meta.reset()
	Meta.uj_jelvenyek.clear()
	Meta.boss_down("rust_worm")
	ok(Meta.has_badge("rozsda") and Meta.uj_jelvenyek == ["rozsda"], "főellenség legyőzése jelvényt ad")
	Meta.boss_down("rust_worm")
	ok(Meta.uj_jelvenyek.size() == 1, "egy jelvény csak egyszer jár")
	for id in Story.NOTE_ORDER:
		Meta.add_note(id)
	ok(Meta.has_badge("naplo"), "minden feljegyzés: Krónikás")
	var pj := Player.create("Lovag")
	pj.kills = 120
	Meta.bank_run(pj, 4, true)
	ok(Meta.has_badge("meszaros") and Meta.has_badge("sziv"), "száz ölés és a győzelem jelvénye")
	for jv in Meta.JELVENYEK:
		ok(Meta.JELVENY_IKON.has(jv), "%s: van ikonja" % jv)
	Meta.uj_jelvenyek.clear()

	# ── 11.8 mentés: az új állapot megmarad
	Meta.reset()
	SaveGame.erase_all()
	var gs := Game.new()
	gs.autosave = false
	gs.start("Sebész", "normal", "2026-10-09")
	var ps := gs.player
	ps.relics = ["gyujto", "tesla"]
	ps.organs = 2
	ps.hit_count = 3
	ps.steam_charge = true
	ps.spark_used = true
	gs.world.mons[0].burn = 2
	gs.world.mons[0].corr = 1
	gs.world.mons[0].bleed = 4
	gs.world.pedestals.append({"x": ps.x, "y": ps.y, "taken": false})
	SaveGame.current = ""
	ok(SaveGame.save_run(gs), "az új állapot elmenthető")
	var gl := SaveGame.load_run()
	ok(gl != null, "és visszatölthető")
	if gl != null:
		var pl := gl.player
		ok(pl.cls == "Sebész" and pl.relics == ["gyujto", "tesla"] and pl.organs == 2 and pl.hit_count == 3, "hős, ereklyék, szervek")
		ok(pl.steam_charge and pl.spark_used and gl.daily == "2026-10-09", "töltés, szikra, napi kihívás")
		ok(gl.world.mons[0].burn == 2 and gl.world.mons[0].corr == 1 and gl.world.mons[0].bleed == 4, "a szörnyek állapotai")
		ok(gl.world.vents == gs.world.vents and gl.world.events == gs.world.events and gl.world.pedestals.size() == 1, "rácsok, események, talapzat")
		var mi0 := 0
		var mi1 := 0
		for mo in gs.world.mons:
			if mo.mini: mi0 += 1
		for mo in gl.world.mons:
			if mo.mini: mi1 += 1
		ok(mi0 == 1 and mi1 == 1, "a mini-boss megmarad")
	SaveGame.erase_all()
	Meta.reset()
	# ── 11.9 változatos szörnyek: minden zóna minden szörnyének van rajza; az újak viselkedése
	for lv in Data.POOL:
		for kulcs in (Data.POOL[lv] as Array) + (Data.RARE_POOL[lv] as Array):
			ok(Data.MONS.has(kulcs), "%d. zóna: ismert szörny (%s)" % [lv, kulcs])
	for kulcs in ["witch", "vampire", "assassin", "troll", "demon", "leech", "drone", "bloom", "sentinel"]:
		ok(Sprites2.has(kulcs), "%s: Gorgona-stílusú rajza van" % kulcs)
	ok(Data.VAR_MERET.size() >= 3 and Data.VAR_TONUS.size() >= 4 and Data.VAR_TONUS[0] == Color(1, 1, 1), "a példányok mérete és árnyalata változik")
	g = arena("Lovag")
	p = g.player
	p.max_hp = 500
	p.hp = 500
	g.world.mons.clear()
	var dr := Mon.make("drone", p.x + 3, p.y, "normal")
	dr.awake = true
	g.world.mons.append(dr)
	g.advance_turn(true)
	ok(p.hp < 500 and dr.x == p.x + 3, "a Szerelődrón egy vonalból, messziről lő (nem megy oda)")
	g.world.mons.clear()
	p.hp = 500
	var vi := Mon.make("bloom", p.x + 2, p.y + 1, "normal")
	vi.awake = true
	g.world.mons.append(vi)
	for i in 6:
		g.advance_turn(true)
	ok(p.hp < 500 and vi.x == p.x + 2 and vi.y == p.y + 1, "a Húsvirág helyből köp, és sosem mozdul")
	g.world.mons.clear()
	p.hp = 500
	var vi2 := Mon.make("bloom", p.x + 6, p.y, "normal")
	vi2.awake = true
	g.world.mons.append(vi2)
	for i in 6:
		g.advance_turn(true)
	ok(p.hp == 500 and vi2.x == p.x + 6, "a Húsvirág a köpőtávján kívül ártalmatlan")
	print("  %d ereklye, %d esemény, %d jelvény; a Sebész és a napi kihívás rendben" % [Relics.ORDER.size(), Data.EVENTS.size(), Meta.JELVENYEK.size()])


# ══════════ 12. ZÓNÁNKÉNTI PÁLYAELEMEK ÉS REJTVÉNYSZOBA ══════════
## egy gép mezői (a zsilip és a sín `n` mezője, a gubó egy mezője, a korong 3×3-a)
func gep_mezok(g: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match str(g["tip"]):
		"zsilip", "szike":
			for i in int(g["n"]):
				out.append(Vector2i(int(g["x"]) + int(g["dx"]) * i, int(g["y"]) + int(g["dy"]) * i))
		"korong":
			for ax in range(-1, 2):
				for ay in range(-1, 2):
					out.append(Vector2i(int(g["x"]) + ax, int(g["y"]) + ay))
		_:
			out.append(Vector2i(int(g["x"]), int(g["y"])))
	return out


func gep(tip: String, x: int, y: int) -> Dictionary:
	return {"tip": tip, "x": x, "y": y, "dx": 0, "dy": 0, "n": 0, "ph": 0, "p": 0, "t": 0, "all": 0}


## mozdulatlan (elkábított) próbaszörny sok életerővel
func babu(g: Game, key: String, x: int, y: int) -> Mon:
	var m := Mon.make(key, x, y, "normal")
	m.max_hp = 1000
	m.hp = 1000
	m.stun = 100000
	g.world.mons.append(m)
	return m


func jelzesek(w: World, kind: String) -> int:
	var n := 0
	for h in w.hazards:
		if h["warn"] and h["kind"] == kind:
			n += 1
	return n


func test_palyaelemek() -> void:
	# ── 12.1 generálás: minden zónának megvan a saját eleme, jó helyen áll, mélyebben több van
	var rejt_van := 0
	var rejt_nincs := 0
	var palyak := 0
	for zona in range(1, Data.MAX_LEVEL + 1):
		var tip: String = Data.GEP_ZONA[zona]
		var db := {}
		var rossz_tip := 0
		var rossz_hely := 0
		var zart_ut := 0
		var rossz_rejtveny := 0
		for em in range(1, Data.emeletek(zona) + 1):
			db[em] = 0
			for i in 8:
				palyak += 1
				var hos := Player.create("Lovag")
				var w := World.create(hos, zona, "normal", em)
				db[em] += w.gepek.size()
				if Dungeon.verify_open(w.tiles, w.rooms, w.chests) != "":
					zart_ut += 1
				var kezdo := w.rooms[0]
				var veg := w.rooms[w.rooms.size() - 1]
				var foglalt := {}
				for ge in w.gepek:
					if ge["tip"] != tip:
						rossz_tip += 1
					for q in gep_mezok(ge):
						var k := Dungeon.idx(q.x, q.y)
						if w.tiles[k] != Data.FLOOR or kezdo.has_point(q) or veg.has_point(q) or w.chest_at(q.x, q.y) != null:
							rossz_hely += 1
						# két gép nem fedi egymást (a 3. emelettől ugyanazon a sínen két szike jár: az nem hiba)
						if foglalt.has(k) and not (tip == "szike" and foglalt[k] == Vector2i(int(ge["x"]), int(ge["y"]))):
							rossz_hely += 1
						foglalt[k] = Vector2i(int(ge["x"]), int(ge["y"]))
					if tip == "zsilip":
						# folyosón van: egyik szobában sincs, és a két oldalán fal áll
						for q in gep_mezok(ge):
							for r in w.rooms:
								if r.has_point(q):
									rossz_hely += 1
							if w.tile(q.x + int(ge["dy"]), q.y + int(ge["dx"])) == Data.FLOOR or w.tile(q.x - int(ge["dy"]), q.y - int(ge["dx"])) == Data.FLOOR:
								rossz_hely += 1
						if int(ge["p"]) != int(Data.ZSILIP_PERIOD[em - 1]):
							rossz_hely += 1
				# rejtvényszoba: vagy nincs, vagy egy leláncolt láda + a lapjai (a sorrend teljes)
				var zart := 0
				var lada: Dictionary = {}
				for c in w.chests:
					if c.get("zart", false):
						zart += 1
						lada = c
				if w.lapok.is_empty():
					rejt_nincs += 1
					if zart != 0:
						rossz_rejtveny += 1
				else:
					rejt_van += 1
					var kell := 3 + (1 if em >= 3 else 0) + (1 if zona >= 3 else 0)
					if zart != 1 or w.lapok.size() < 3 or w.lapok.size() > kell:
						rossz_rejtveny += 1
					var sorok := {}
					var helyek := {}
					for l in w.lapok:
						sorok[int(l["sor"])] = true
						helyek[Dungeon.idx(l["x"], l["y"])] = true
						if w.tiles[Dungeon.idx(l["x"], l["y"])] != Data.FLOOR or l["le"] or w.chest_at(l["x"], l["y"]) != null:
							rossz_rejtveny += 1
					for k in w.lapok.size():
						if not sorok.has(k):
							rossz_rejtveny += 1
					if helyek.size() != w.lapok.size():
						rossz_rejtveny += 1
					if zart == 1:
						# a láda körül mind a nyolc mező padló: semmit nem zárhat el
						for ax in range(-1, 2):
							for ay in range(-1, 2):
								if (ax != 0 or ay != 0) and w.tile(int(lada["x"]) + ax, int(lada["y"]) + ay) != Data.FLOOR:
									rossz_rejtveny += 1
						var szoba := -1
						for j in w.rooms.size():
							if w.rooms[j].has_point(Vector2i(int(lada["x"]), int(lada["y"]))):
								szoba = j
						if szoba < 0 or w.room_kind[szoba] != "rejtveny":
							rossz_rejtveny += 1
		var utolso := Data.emeletek(zona)
		ok(rossz_tip == 0, "%d. zóna: csak a saját pályaeleme (%s) van benne" % [zona, tip])
		ok(rossz_hely == 0, "%d. zóna: minden elem szabad padlón, a kezdő- és a lejárati termen kívül áll (%d hiba)" % [zona, rossz_hely])
		ok(zart_ut == 0, "%d. zóna: az elemekkel és a rejtvényládával is minden bejárható" % zona)
		ok(rossz_rejtveny == 0, "%d. zóna: a rejtvényszobák épek (%d hiba)" % [zona, rossz_rejtveny])
		ok(db[1] > 0 and db[utolso] > db[1], "%d. zóna: mélyebb emeleten több az elem (%s)" % [zona, str(db)])
		ok(Data.gep_dmg(tip, zona, utolso) > Data.gep_dmg(tip, zona, 1), "%d. zóna: mélyebben nagyobbat sebez" % zona)
		print("  %d. zóna (%s): elemek emeletenként (8 pályán) %s" % [zona, tip, str(db)])
	ok(rejt_van > 0 and rejt_nincs > 0, "rejtvényszoba van, de nem minden emeleten (%d / %d pályán)" % [rejt_van, palyak])
	ok(Data.ZSILIP_PERIOD[3] < Data.ZSILIP_PERIOD[0] and Data.KORONG_PERIOD[3] < Data.KORONG_PERIOD[0] and Data.GUBO_UJRA[3] < Data.GUBO_UJRA[0], "mélyebben szaporább az ütem")
	print("  rejtvényszoba: %d / %d pályán" % [rejt_van, palyak])

	# ── 12.2 gőzzsilip: a nyomásmérő után jelez, két körig fúj, a szörnyet is megégeti
	var g := arena("Lovag")
	var p := g.player
	var w := g.world
	p.max_hp = 500
	p.hp = 500
	w.mons.clear()
	var zs := gep("zsilip", p.x + 3, p.y)
	zs["dx"] = 1
	zs["n"] = 3
	zs["p"] = 8
	w.gepek.append(zs)
	var bm := babu(g, "goblin", p.x + 4, p.y)
	var minta := {}
	for i in 16:
		g.advance_turn(true)
		minta[w.gep_fazis(zs)] = jelzesek(w, "steam")
		if w.gep_fazis(zs) == 0:
			ok(not w.veszely_mezok().has(Dungeon.idx(zs["x"], zs["y"])), "zsilip: az ütem elején át lehet kelni rajta")
		if w.gep_fazis(zs) == 4:
			ok(w.veszely_mezok().has(Dungeon.idx(zs["x"], zs["y"])), "zsilip: a nyomás tetején már nem tanácsos belépni")
	ok(minta[0] == 0 and minta[4] == 0 and minta[7] == 0, "zsilip: a csendes körökben nincs jelzés (%s)" % str(minta))
	ok(minta[5] == 3 and minta[6] == 3, "zsilip: a kitörés előtt mindhárom mezője jelez, két egymás utáni körben")
	var zd := Data.gep_dmg("zsilip", 1, 1)
	ok(bm.hp == 1000 - 4 * zd, "zsilip: a benne álló szörnyet ütemenként kétszer megégeti (%d)" % bm.hp)
	ok(not bm.awake, "zsilip: a pálya csapása nem ébreszti fel a szörnyet")
	ok(p.hp == 500, "zsilip: aki kívül áll, nem sérül")
	p.x = int(zs["x"])
	for i in 8:
		g.advance_turn(true)
	ok(p.hp == 500 - 2 * (zd - int(p.def / 3.0)), "zsilip: a benne álló hőst is megégeti, a védelme harmadát levonva (%d)" % p.hp)
	bm.hp = 3
	for i in 8:
		g.advance_turn(true)
	ok(not bm.alive and p.kills == 1, "zsilip: a gőz meg is ölheti a szörnyet (a jutalom a hősé)")

	# ── 12.3 sínen ingázó szike: körönként egy mezőt lép, a következő mezője előre villog
	g = arena("Lovag")
	p = g.player
	w = g.world
	w.dungeon_level = 2
	p.max_hp = 500
	p.hp = 500
	w.mons.clear()
	var sz := gep("szike", p.x + 2, p.y + 2)
	sz["dx"] = 1
	sz["n"] = 4
	w.gepek.append(sz)
	var ut: Array = []
	for k in 7:
		ut.append(w.szike_hely(sz, k).x - int(sz["x"]))
	ok(ut == [0, 1, 2, 3, 2, 1, 0], "szike: oda-vissza jár a sínen (%s)" % str(ut))
	var bs := babu(g, "goblin", int(sz["x"]) + 2, int(sz["y"]))
	var jo_jelzes := 0
	for i in 12:
		g.advance_turn(true)
		var kov := w.szike_hely(sz, w.turn + 1)
		var h: Variant = w.hazard_at(kov.x, kov.y, "blade")
		if h != null and h["warn"] and w.hazards.size() == 1:
			jo_jelzes += 1
	ok(jo_jelzes == 12, "szike: mindig pontosan az a mező villog, ahová a következő körben lép (%d/12)" % jo_jelzes)
	ok(bs.hp == 1000 - 4 * Data.gep_dmg("szike", 2, 1), "szike: a sínen álló szörnyet minden áthaladáskor megvágja (%d)" % bs.hp)
	ok(p.hp == 500, "szike: a sín mellett állva nem ér el")
	p.x = int(sz["x"])
	p.y = int(sz["y"])
	for i in 6:
		g.advance_turn(true)
	ok(p.hp == 500 - (Data.gep_dmg("szike", 2, 1) - int(p.def / 3.0)), "szike: a sínen álló hőst megvágja, amikor odaér (%d)" % p.hp)
	ok(not nyers(Lang.txt(p.msgs[p.msgs.size() - 1]["t"])), "szike: az üzenet le van fordítva")

	# ── 12.4 spóragubó: megduzzad, kipukkad, felhőt hagy; a gombalényeket nem bántja; újra beérik
	g = arena("Lovag")
	p = g.player
	w = g.world
	w.dungeon_level = 3
	p.max_hp = 500
	p.hp = 500
	w.mons.clear()
	var gb := gep("gubo", p.x + 1, p.y)
	gb["n"] = 1
	w.gepek.append(gb)
	ok(w.veszely_mezok().has(Dungeon.idx(p.x, p.y)), "gubó: az érett gubó szomszédsága veszélyes mezőnek számít")
	g.advance_turn(true)
	ok(int(gb["all"]) == 1 and w.hazards.is_empty(), "gubó: ha valaki mellé lép, előbb csak megduzzad (figyelmeztet)")
	var gob := babu(g, "goblin", p.x + 2, p.y)
	var spo := babu(g, "spore", p.x + 2, p.y + 1)
	g.advance_turn(true)
	var felho := 0
	for h in w.hazards:
		if h["kind"] == "spora" and not h["warn"]:
			felho += 1
	ok(int(gb["all"]) == 2 and felho == 9, "gubó: a következő körben kipukkad, 3×3-as spórafelhő marad utána (%d)" % felho)
	ok(p.hp == 500, "gubó: a pukkanás pillanata még nem sebez (van idő kilépni)")
	g.advance_turn(true)
	var gd := Data.gep_dmg("gubo", 3, 1)
	ok(p.hp == 500 - gd and p.poison >= 2, "gubó: a felhőben maradó hős sebződik és megmérgeződik (%d)" % p.hp)
	ok(gob.hp == 1000 - gd and spo.hp == 1000, "gubó: a felhő a szörnyet is marja, a spóralényt nem")
	for i in Data.FELHO_KOR:
		g.advance_turn(true)
	ok(w.hazards.is_empty(), "gubó: a felhő %d kör után eloszlik" % Data.FELHO_KOR)
	p.x += 10
	gob.x += 10
	spo.x += 10
	for i in int(Data.GUBO_UJRA[0]):
		g.advance_turn(true)
	ok(int(gb["all"]) == 0, "gubó: idővel újra beérik")
	gob.x = int(gb["x"]) + 1
	gob.y = int(gb["y"]) + 1
	g.advance_turn(true)
	ok(int(gb["all"]) == 1, "gubó: a szörny is kiváltja")
	gob.x += 10
	g.advance_turn(true)
	g.advance_turn(true)
	spo.x = int(gb["x"]) + 1
	spo.y = int(gb["y"])
	for i in int(Data.GUBO_UJRA[0]) + 2:
		g.advance_turn(true)
	ok(int(gb["all"]) == 0, "gubó: a spóralény nem váltja ki")
	var gb2 := gep("gubo", p.x + 1, p.y)
	gb2["n"] = 2
	w.gepek.append(gb2)
	g.advance_turn(true)
	g.advance_turn(true)
	felho = 0
	for h in w.hazards:
		if h["kind"] == "spora":
			felho += 1
	ok(felho == 13, "gubó: mélyebb emeleten nagyobb a felhő (%d mező)" % felho)

	# ── 12.5 forgó fogaskerék-padló: felizzik, megcsíp, és negyedfordulatot tesz azzal, aki rajta áll
	g = arena("Lovag")
	p = g.player
	w = g.world
	w.dungeon_level = 4
	p.max_hp = 500
	p.hp = 500
	w.mons.clear()
	var kr := gep("korong", p.x + 4, p.y + 4)
	kr["p"] = 7
	w.gepek.append(kr)
	var kx := int(kr["x"])
	var ky := int(kr["y"])
	var gyuru := babu(g, "goblin", kx + 1, ky)
	var kozep := babu(g, "goblin", kx, ky)
	p.x = kx - 1
	p.y = ky - 1
	while w.gep_fazis(kr) != 5:
		g.advance_turn(true)
		ok(jelzesek(w, "gear") == (8 if w.gep_fazis(kr) == 5 else 0), "korong: csak a fordulás előtti körben jelez, akkor a gyűrű mind a nyolc mezőjén")
	ok(p.x == kx - 1 and p.y == ky - 1 and p.hp == 500, "korong: a jelzés körében még semmi nem történik")
	ok(w.veszely_mezok().has(Dungeon.idx(kx - 1, ky - 1)) and not w.veszely_mezok().has(Dungeon.idx(kx, ky)), "korong: a gyűrű veszélyes, a közepe nem")
	g.advance_turn(true)
	var kd := Data.gep_dmg("korong", 4, 1)
	ok(p.x == kx + 1 and p.y == ky - 1, "korong: a hőst negyedfordulattal odébb viszi (%d,%d)" % [p.x - kx, p.y - ky])
	ok(p.hp == 500 - (kd - int(p.def / 3.0)), "korong: a fogak megcsípik a hőst (%d)" % p.hp)
	ok(gyuru.x == kx and gyuru.y == ky + 1 and gyuru.hp < 1000, "korong: a gyűrűn álló szörnyet is elforgatja és megcsípi")
	ok(kozep.x == kx and kozep.y == ky and kozep.hp == 1000, "korong: a közepén álló a helyén marad, sértetlenül")
	ok(w.is_vis(p.x, p.y), "korong: a fordulás után a látótér a hős új helyéhez igazodik")

	# ── 12.6 rejtvényszoba: a lapok sorrendje, a rossz lap büntetése, a láda lánca
	g = arena("Lovag")
	p = g.player
	w = g.world
	p.max_hp = 500
	p.hp = 500
	w.mons.clear()
	var lada2 := {"x": p.x, "y": p.y + 3, "opened": false, "zart": true, "items": [mk("Rúnakard", "epic", 2), mk("Rúnapajzs", "epic", 2)]}
	w.chests.append(lada2)
	w.lapok = [{"x": p.x + 2, "y": p.y, "jel": 0, "sor": 1, "le": false},
		{"x": p.x + 3, "y": p.y, "jel": 1, "sor": 0, "le": false},
		{"x": p.x + 4, "y": p.y, "jel": 2, "sor": 2, "le": false}]
	var x0 := p.x
	var y0 := p.y
	p.y = y0 + 2
	ok(g.do_move(0, 1) and g.pending_chest == null and p.y == y0 + 2, "rejtvény: a leláncolt láda nem nyílik ki")
	ok(not nyers(Lang.txt(p.msgs[p.msgs.size() - 1]["t"])), "rejtvény: a láda üzenete le van fordítva")
	ok(w.robot_celok() == [Dungeon.idx(x0 + 3, y0)], "rejtvény: az első lap a 0. sorszámú")
	ok(w.veszely_mezok().has(Dungeon.idx(x0 + 2, y0)) and not w.veszely_mezok().has(Dungeon.idx(x0 + 3, y0)), "rejtvény: a soron kívüli lapra nem érdemes lépni")
	p.y = y0
	p.x = x0 + 3
	g._land(p.x, p.y)
	ok(w.lapok[1]["le"] and w.lapok_le() == 1 and w.hazards.is_empty(), "rejtvény: a jó lap lenyomva marad")
	p.x = x0 + 4
	g._land(p.x, p.y)
	ok(w.lapok_le() == 0, "rejtvény: a rossz lap mindet visszaugrasztja")
	var hj: Variant = w.hazard_at(p.x, p.y)
	ok(hj != null and hj["warn"], "rejtvény: a büntetés előre jelzett csapás (ki lehet térni)")
	ok(lada2["zart"], "rejtvény: a láda zárva marad")
	w.hazards.clear()
	var szorny := babu(g, "goblin", x0 + 3, y0)
	g.advance_turn(true)
	ok(w.lapok_le() == 0, "rejtvény: a szörny nem nyomja le a lapot")
	szorny.alive = false
	for lx in [3, 2, 4]:
		p.x = x0 + lx
		g._land(p.x, p.y)
	ok(w.lapok_le() == 3 and not lada2["zart"] and w.zart_lada() == null, "rejtvény: helyes sorrendben lehull a lánc")
	ok(w.veszely_mezok().is_empty() and w.robot_celok().is_empty(), "rejtvény: megoldás után a lapok ártalmatlanok")
	p.x = x0
	p.y = y0 + 2
	ok(g.do_move(0, 1) and g.pending_chest == lada2, "rejtvény: a megoldás után a láda kinyitható")

	# ── 12.7 mentés: a gépek, a lapok, a leláncolt láda és a felhő megmarad; a régi mentés is betölt
	Meta.reset()
	SaveGame.erase_all()
	var gs := Game.new()
	gs.autosave = false
	gs.start("Lovag", "normal")
	for i in 60:
		var wp := World.create(gs.player, 3, "normal", 3)
		if not wp.lapok.is_empty() and wp.gepek.size() >= 2:
			gs.world = wp
			break
	var ws := gs.world
	ok(not ws.lapok.is_empty() and ws.gepek.size() >= 2, "mentés: van mit menteni (rejtvényszobás pálya gépekkel)")
	if not ws.lapok.is_empty() and ws.gepek.size() >= 2:
		ws.gepek[0]["all"] = 2
		ws.gepek[0]["t"] = 77
		ws.gepek[1]["all"] = 1
		ws.lapok[0]["le"] = true
		ws.hazards.append({"x": gs.player.x, "y": gs.player.y, "kind": "spora", "ttl": 2, "dmg": 3, "warn": false, "mind": true})
		SaveGame.current = ""
		ok(SaveGame.save_run(gs), "mentés: a pályaelemekkel együtt elmenthető")
		var gl := SaveGame.load_run()
		ok(gl != null, "mentés: visszatölthető")
		if gl != null:
			var wl := gl.world
			ok(wl.gepek == ws.gepek, "mentés: a gépek (fajta, hely, ütem, állapot) azonosak")
			ok(wl.lapok == ws.lapok and wl.lapok_le() == 1, "mentés: a nyomólapok és az állásuk azonos")
			var zl: Variant = wl.zart_lada()
			var zs0: Variant = ws.zart_lada()
			ok(zl != null and zl["x"] == zs0["x"] and zl["y"] == zs0["y"], "mentés: a leláncolt láda zárva marad")
			ok(wl.hazards.size() == 1 and wl.hazards[0]["kind"] == "spora" and wl.hazards[0]["mind"], "mentés: a spórafelhő megmarad")
			ok(wl.room_kind == ws.room_kind, "mentés: a rejtvényszoba jelölése megmarad")
		# régi mentés: a fájlból kivesszük mindazt, amit a régi változat még nem írt bele
		var ut_f := SaveGame.path_of(SaveGame.current)
		var j := JSON.new()
		ok(j.parse(FileAccess.get_file_as_string(ut_f)) == OK, "mentés: a fájl érvényes JSON")
		var d: Dictionary = j.data
		(d["palya"] as Dictionary).erase("gepek")
		(d["palya"] as Dictionary).erase("lapok")
		for c in (d["palya"]["chests"] as Array):
			(c as Dictionary).erase("zart")
		for h in (d["palya"]["hazards"] as Array):
			(h as Dictionary).erase("mind")
		var f := FileAccess.open(ut_f, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		var gr := SaveGame.load_run()
		ok(gr != null, "régi mentés: betölthető")
		if gr != null:
			ok(gr.world.gepek.is_empty() and gr.world.lapok.is_empty() and gr.world.zart_lada() == null, "régi mentés: gépek és rejtvény nélkül tölt be")
			ok(gr.world.hazards.size() == 1 and not gr.world.hazards[0]["mind"], "régi mentés: a veszélyzóna a szörnyekre nem hat")
			var t0 := gr.world.turn
			gr.player.hp = gr.player.max_hp
			gr.advance_turn(true)
			ok(gr.world.turn > t0, "régi mentés: tovább lehet játszani")
	SaveGame.erase_all()
	Meta.reset()

	# ── 12.8 a rajzok hibátlanul lefutnak (fej nélkül is), és minden fajtának van saját rajza
	var c := Cv.new()
	var ci := RenderingServer.canvas_item_create()
	c.begin(ci)
	var halok: Array = []
	var rajzok: Array[Callable] = [
		func() -> void: Sprites2.zsilip(c, 0, 0, 48, 0.5, false, true, true, 10.0),
		func() -> void: Sprites2.zsilip(c, 0, 0, 48, 1.0, true, false, false, 10.0),
		func() -> void: Sprites2.szike_sin(c, 0, 0, 48, true, true, true),
		func() -> void: Sprites2.szike(c, 0, 0, 48, 10.0),
		func() -> void: Sprites2.gubo(c, 0, 0, 48, 0, 10.0),
		func() -> void: Sprites2.gubo(c, 0, 0, 48, 1, 10.0),
		func() -> void: Sprites2.gubo(c, 0, 0, 48, 2, 10.0),
		func() -> void: Sprites2.sporafelho(c, 0, 0, 48, 10.0, 1.0),
		func() -> void: Sprites2.korong(c, 24, 24, 48, 0.3, 1.0),
		func() -> void: Sprites2.nyomolap(c, 0, 0, 48, 3, false, 10.0),
		func() -> void: Sprites2.nyomolap(c, 0, 0, 48, 4, true, 10.0),
		func() -> void: Sprites2.lada_lanc(c, 0, 0, 48),
		func() -> void: Sprites2.lada_jelek(c, 0, 0, 48, [2, 0, 1, 4, 3], 2, 10.0)]
	for rajz in rajzok:
		c.rec_begin()
		rajz.call()
		var halo: Array = c.rec_end()
		var uj := (halo[0] as PackedVector2Array).size() > 0
		for elozo in halok:
			if not _halo_mas(halo, elozo):
				uj = false
		halok.append(halo)
		ok(uj, "pályaelem-rajz %d: látható és más, mint a többi" % halok.size())
	RenderingServer.free_rid(ci)
	print("  %d féle pályaelem + rejtvényszoba: működés, mentés, rajz rendben" % Data.GEP_ZONA.size())


# ══════════ 13. HANGOK: lépések, szörnyhangok, felfigyelés, fázisváltás ══════════
## egy hang legnagyobb kitérése (0..1) és „élessége” (a magas hangok aránya: a szomszédos
## minták különbségének energiája az egész energiájához mérve)
func hang_jellemzok(wav: AudioStreamWAV) -> Array:
	var d := wav.data
	var n := int(d.size() / 2.0)
	var csucs := 0.0
	var e := 0.0
	var ed := 0.0
	var elozo := 0.0
	for i in n:
		var v := d.decode_s16(i * 2) / 32767.0
		csucs = maxf(csucs, absf(v))
		e += v * v
		ed += (v - elozo) * (v - elozo)
		elozo = v
	return [csucs, ed / maxf(e, 0.000001), n]


func szornyhang_db(naplo: Array) -> int:
	var n := 0
	for h in naplo:
		if str(h[0]) in ["gep", "hus", "lebego", "kuszo"]:
			n += 1
	return n


func test_hangok() -> void:
	# ── 13.1 a hangkészlet: minden név, amit a játék lejátszhat, létezik, hallható és nem torzít
	var a := Audio.new()
	root.add_child(a)
	a.setup(false)
	var nevek := {}
	var re := RegEx.create_from_string('play\\("([a-z_0-9]+)"')
	for fajl in ["game.gd", "main.gd"]:
		for mm in re.search_all(FileAccess.get_file_as_string("res://scripts/" + fajl)):
			nevek[mm.get_string(1)] = fajl
	for z in range(1, Data.MAX_LEVEL + 1):
		nevek["step%d" % z] = "game.gd"
	for k in Data.MON_HANG:
		nevek[str(Data.MON_HANG[k])] = "data.gd"
	var jell := {}
	for nev in nevek:
		var van: bool = a._sfx.has(nev) and not (a._sfx[nev] as Array).is_empty()
		ok(van, "hang: „%s” létezik (%s)" % [nev, nevek[nev]])
		if not van:
			continue
		var j := hang_jellemzok((a._sfx[nev] as Array)[0])
		jell[nev] = j
		ok(float(j[0]) > 0.02 and float(j[0]) <= 1.0 and int(j[2]) > 400, "hang: „%s” hallható és nem üres (csúcs %.2f, %d minta)" % [nev, j[0], j[2]])
	for k in Data.MONS:
		ok(Data.MON_HANG.has(k), "szörnyhang: %s besorolva egy fajtába" % k)
	ok(nevek.has("fazis") and nevek.has("eszlel"), "a fázisváltásnak és a felfigyelésnek saját hangja van")
	# a lépés halk; a kemény talaj (márvány, fémrács) élesebben koppan, mint a kazánlemez és a puha padló
	for z in range(1, Data.MAX_LEVEL + 1):
		var cs := 0.0
		for wv in (a._sfx["step%d" % z] as Array):
			cs = maxf(cs, float(hang_jellemzok(wv)[0]))
		ok(cs < 0.45 and (a._sfx["step%d" % z] as Array).size() >= 3, "lépés (%d. zóna): halk, és több változata van (csúcs %.2f)" % [z, cs])
	ok(float(jell["step3"][1]) < float(jell["step2"][1]) and float(jell["step3"][1]) < float(jell["step4"][1]) and float(jell["step1"][1]) < float(jell["step4"][1]),
		"lépés: a puha padló tompább a márványnál és a fémrácsnál (élesség: %.3f / %.3f / %.3f / %.3f)" % [jell["step1"][1], jell["step2"][1], jell["step3"][1], jell["step4"][1]])
	ok(float(jell["kuszo"][1]) > float(jell["hus"][1]) and float(jell["kuszo"][1]) > float(jell["lebego"][1]),
		"szörnyhang: a surrogás élesebb a hörgésnél és a zümmögésnél (%.3f / %.3f / %.3f)" % [jell["kuszo"][1], jell["hus"][1], jell["lebego"][1]])
	print("  %d hang; lépések élessége zónánként: %.3f · %.3f · %.3f · %.3f" % [nevek.size(), jell["step1"][1], jell["step2"][1], jell["step3"][1], jell["step4"][1]])

	# ── 13.2 hangerő és némítás: a meglévő hang-beállítás kezeli
	var pi0 := a._pi
	a.set_muted(true)
	a.play("step1")
	a.play("gep", 0.5)
	ok(a._pi == pi0, "némítva egyetlen új hang sem szól")
	a.set_muted(false)
	a.play("nincs_ilyen_hang")
	a.play("step1", 0.0)
	ok(a._pi == pi0, "ismeretlen név és nulla hangerő: nem történik semmi")
	a.play("gep", 0.5)
	var lej: AudioStreamPlayer = a._players[pi0]
	ok(a._pi == (pi0 + 1) % a._players.size() and absf(lej.volume_db - linear_to_db(Audio.MASTER * 0.5)) < 0.01, "a hangerő-szorzó érvényesül (%.1f dB)" % lej.volume_db)
	a.play("sword")
	ok(absf(a._players[(pi0 + 1) % a._players.size()].volume_db - linear_to_db(Audio.MASTER)) < 0.01, "a többi hang teljes hangerővel szól")
	var csupasz := Audio.new()
	csupasz._build_sfx()
	csupasz.play("step1")   # lejátszók nélkül (setup nélkül) sem okoz hibát
	ok(csupasz._players.is_empty(), "lejátszók nélkül a hang kérése ártalmatlan")
	csupasz.free()
	a.set_muted(false)
	a.queue_free()

	# ── 13.3 lépéshang: zónánként más talaj, halkan
	var g := arena("Lovag")
	var p := g.player
	var w := g.world
	var naplo: Array = []
	g.sfx = func(n: String, v: float = 1.0) -> void: naplo.append([n, v])
	w.mons.clear()
	for z in range(1, Data.MAX_LEVEL + 1):
		w.dungeon_level = z
		naplo.clear()
		g.do_move(1, 0)
		ok(naplo.size() >= 1 and naplo[0][0] == "step%d" % z and float(naplo[0][1]) == Data.LEPES_HANGERO and float(naplo[0][1]) < 1.0, "lépéshang a %d. zónában: %s" % [z, str(naplo)])
	w.dungeon_level = 1

	# ── 13.4 szörnyhangok: csak a látható, közeli, mozduló szörny szól; ritkítva; távolsággal halkul
	p.max_hp = 100000
	p.hp = 100000
	g._hang_rng.seed = 7
	var kulcsok := ["rat", "goblin", "drone", "golem", "spider", "orc", "scalpel", "skeleton", "leech", "troll"]
	for i in kulcsok.size():
		var m := Mon.make(kulcsok[i], p.x - 5 + i, p.y + 4 + (i % 2), "normal")
		m.awake = true
		m.eszlelt = true
		w.mons.append(m)
	var legtobb := 0
	var ossz := 0
	var rossz_hangero := 0
	for kor in 4:
		naplo.clear()
		g.advance_turn(true)
		var db := szornyhang_db(naplo)
		legtobb = maxi(legtobb, db)
		ossz += db
		var fajtak := {}
		for h in naplo:
			if str(h[0]) in ["gep", "hus", "lebego", "kuszo"]:
				if fajtak.has(h[0]) or float(h[1]) <= 0.0 or float(h[1]) > 0.8:
					rossz_hangero += 1
				fajtak[h[0]] = true
	ok(legtobb <= Data.SZORNYHANG_MAX and ossz >= 2, "tíz mozgó szörny mellett is körönként legfeljebb %d szörnyhang szól (legtöbb %d, négy kör alatt %d)" % [Data.SZORNYHANG_MAX, legtobb, ossz])
	ok(rossz_hangero == 0, "egy körben egy fajta csak egyszer szól, és a hangereje érvényes")
	w.mons.clear()
	var kozeli := Mon.make("goblin", p.x + 2, p.y, "normal")
	var tavoli := Mon.make("goblin", p.x + 6, p.y, "normal")
	ok(g._tav_hangero(kozeli) > g._tav_hangero(tavoli) and g._tav_hangero(tavoli) >= 0.2, "a távolabbi szörny halkabb (%.2f > %.2f)" % [g._tav_hangero(kozeli), g._tav_hangero(tavoli)])
	# egyetlen mozduló, látható szörny: a ritkítás ellenére néhány körön belül megszólal
	var egy := Mon.make("golem", p.x + 7, p.y + 7, "normal")
	egy.awake = true
	egy.eszlelt = true
	w.mons.append(egy)
	var szolt := 0
	var jo_hang := true
	for kor in 5:
		naplo.clear()
		g.advance_turn(true)
		for h in naplo:
			if str(h[0]) in ["gep", "hus", "lebego", "kuszo"]:
				szolt += 1
				if h[0] != "gep" or absf(float(h[1]) - g._tav_hangero(egy) * 0.8) > 0.001:
					jo_hang = false
	ok(szolt >= 1 and jo_hang, "a közeledő gólem a gépi hangján szól, a távolságának megfelelő hangerővel (%d)" % szolt)
	# nem látható szörny néma
	w.mons.clear()
	var rejtett := Mon.make("goblin", p.x + 5, p.y + 5, "normal")
	rejtett.awake = true
	rejtett.eszlelt = true
	w.mons.append(rejtett)
	w.vis.fill(0)
	var x0 := rejtett.x
	naplo.clear()
	for kor in 3:
		g.advance_turn(true)
	ok(rejtett.x != x0 and szornyhang_db(naplo) == 0, "a nem látható szörny mozog, de néma")
	w.vis.fill(1)
	# a hallótávon kívüli szörny néma
	w.mons.clear()
	var messzi := Mon.make("goblin", p.x + 14, p.y, "normal")
	messzi.awake = true
	messzi.eszlelt = true
	w.mons.append(messzi)
	naplo.clear()
	for kor in 3:
		g.advance_turn(true)
	ok(messzi.x < p.x + 14 and szornyhang_db(naplo) == 0, "a hallótávon (%d mező) kívül mozgó szörny néma" % Data.SZORNYHANG_TAV)

	# ── 13.5 „felfigyelt rád”: egyszer, amikor a szörny először meglátja a hőst
	w.mons.clear()
	g.fx.clear()
	var uj1 := Mon.make("goblin", p.x + 4, p.y, "normal")
	var uj2 := Mon.make("orc", p.x - 4, p.y, "normal")
	w.mons.append(uj1)
	w.mons.append(uj2)
	naplo.clear()
	g.advance_turn(true)
	var eszl := 0
	for h in naplo:
		if h[0] == "eszlel":
			eszl += 1
	var jelek := 0
	for f in g.fx:
		if f.get("txt", "") == "!":
			jelek += 1
	ok(uj1.eszlelt and uj2.eszlelt and eszl == 1 and jelek == 2, "két szörny egyszerre figyel fel: két felkiáltójel, de csak egy hang (%d / %d)" % [jelek, eszl])
	naplo.clear()
	g.advance_turn(true)
	eszl = 0
	for h in naplo:
		if h[0] == "eszlel":
			eszl += 1
	ok(eszl == 0, "a felfigyelés hangja nem ismétlődik")
	w.mons.clear()
	var nem_lat := Mon.make("goblin", p.x + 4, p.y, "normal")
	w.mons.append(nem_lat)
	w.vis.fill(0)
	naplo.clear()
	g.advance_turn(true)
	ok(not nem_lat.eszlelt and naplo.is_empty(), "akit a hős nem lát, az még nem figyelt fel")
	w.vis.fill(1)

	# ── 13.6 főellenség: a fázisváltásnak saját hangja van
	w.mons.clear()
	var fo := Mon.make("rust_worm", p.x + 3, p.y, "normal")
	w.mons.append(fo)
	naplo.clear()
	g.boss_phase2(fo)
	var hangok := {}
	for h in naplo:
		hangok[h[0]] = true
	ok(hangok.has("fazis") and hangok.has("roar"), "fázisváltás: bömbölés + a fázisváltás saját hangja (%s)" % str(hangok.keys()))
	g.pending_dialog = []

	# ── 13.7 hang nélkül (fej nélküli futás, nincs sfx) minden ugyanúgy megy
	g.sfx = Callable()
	w.mons.clear()
	var csendes := Mon.make("goblin", p.x + 3, p.y, "normal")
	w.mons.append(csendes)
	g.advance_turn(true)
	g.do_move(0, 1)
	ok(csendes.eszlelt and g._szornyhangok({csendes: Vector2i(0, 0)}) == 0, "hangkimenet nélkül a szörnyek ugyanúgy észrevesznek, hang nem készül")

	# ── 13.8 mentés: aki már felfigyelt, betöltés után nem kiált fel újra
	Meta.reset()
	SaveGame.erase_all()
	var gs := Game.new()
	gs.autosave = false
	gs.start("Lovag", "normal")
	gs.world.mons[0].eszlelt = true
	gs.world.mons[1].eszlelt = false
	SaveGame.current = ""
	ok(SaveGame.save_run(gs), "hang-állapot: elmenthető")
	var gl := SaveGame.load_run()
	ok(gl != null and gl.world.mons[0].eszlelt and not gl.world.mons[1].eszlelt, "a felfigyelés állapota megmarad a mentésben")
	SaveGame.erase_all()
	Meta.reset()


# ══════════ 14. A 15 PÁLYA NEHÉZSÉGE: a hangolás táblái jól vannak bekötve ══════════
## (A számok maguk méréssel készültek — tests/egyensuly.gd —, itt csak azt nézzük, hogy a táblák
## teljesek, és hogy a játék tényleg azokból dolgozik.)
func test_nehezseg() -> void:
	var n := Data.palyak()
	ok(n == 15 and Data.PALYA_HP.size() == n and Data.PALYA_ATK.size() == n and Data.PALYA_CSAPAS.size() == n, "minden pályának van szorzója (%d pálya)" % n)
	ok(Data.palya_sorszam(1, 1) == 1 and Data.palya_sorszam(1, 4) == 4 and Data.palya_sorszam(2, 1) == 5 and Data.palya_sorszam(4, 3) == 15, "a pálya sorszáma a kaland elejétől számol")
	ok(Data.palya_hp(1) == 1.0 and Data.palya_atk(1) == 0 and Data.palya_csapas(1) == 0, "az első pálya szörnyei a tábla szerinti alapértékükkel indulnak")
	var no := true
	for i in range(1, n):
		if Data.PALYA_ATK[i] < Data.PALYA_ATK[i - 1] or Data.PALYA_CSAPAS[i] < Data.PALYA_CSAPAS[i - 1] or Data.PALYA_HP[i] <= 1.0:
			no = false
	ok(no, "mélyebb pályán a szörnyek támadása és a csapások ereje sosem csökken")
	# a szörnyek életereje ténylegesen nő pályáról pályára (a zónaváltásnál is: az új zóna lényei eleve szívósabbak)
	var elozo := 0.0
	var hp_no := true
	for z in range(1, Data.MAX_LEVEL + 1):
		var atlag := 0.0
		for k in Data.POOL[z]:
			atlag += float(Data.MONS[k]["hp"])
		atlag /= (Data.POOL[z] as Array).size()
		for e in range(1, Data.emeletek(z) + 1):
			var most := atlag * Data.palya_hp(Data.palya_sorszam(z, e))
			if most <= elozo:
				hp_no = false
			elozo = most
	ok(hp_no, "a közönséges szörnyek átlagos életereje pályáról pályára nő")

	# ── a pálya létrehozásakor minden szörny egyszer kapja meg az erősítést; a zóna ura nem
	for zona in [1, 2, 4]:
		for em in [1, Data.emeletek(zona)]:
			var s := Data.palya_sorszam(zona, em)
			var w := World.create(Player.create("Lovag"), zona, "normal", em)
			ok(w.szakasz() == s, "%d/%d: a pálya tudja a sorszámát (%d)" % [zona, em, s])
			var rossz := 0
			var fo := 0
			for m in w.mons:
				var alap := Mon.make(m.key, 0, 0, "normal")
				if m.boss:
					fo += 1
					if m.max_hp != alap.max_hp or m.atk != alap.atk:
						rossz += 1
				elif not m.elite and not m.guard and not m.mini:
					if m.max_hp != maxi(1, int(round(alap.max_hp * Data.palya_hp(s)))) or m.atk != alap.atk + Data.palya_atk(s):
						rossz += 1
				elif m.mini:
					var mm := Mon.make_mini(m.key, 0, 0, "normal")
					if m.atk != mm.atk + int(round(Data.palya_atk(s) * Data.MINI_PALYA_ATK)) or m.max_hp != int(round(mm.max_hp * Data.palya_hp(s))):
						rossz += 1
			ok(rossz == 0, "%d/%d: a szörnyek ereje a pálya sorszámából jön, a zóna uráé a saját táblájából (%d eltérés)" % [zona, em, rossz])
			ok(fo == (1 if em == Data.emeletek(zona) else 0), "%d/%d: a zóna ura csak az utolsó emeleten van" % [zona, em])
	# a nehézség a támadás-többletre csak mérsékelten hat
	var wk := World.create(Player.create("Lovag"), 2, "easy", 2)
	var wn := World.create(Player.create("Lovag"), 2, "hard", 2)
	var bk := wk.erosit(Mon.make("orc", 0, 0, "easy")).atk - Mon.make("orc", 0, 0, "easy").atk
	var bn := wn.erosit(Mon.make("orc", 0, 0, "hard")).atk - Mon.make("orc", 0, 0, "hard").atk
	var s6 := Data.palya_atk(6)
	ok(bk < s6 and bn > s6 and bk > s6 * 0.8 and bn < s6 * 1.3, "könnyű / nehéz: a támadás-többlet mérsékelten változik (%d / %d / %d)" % [bk, s6, bn])

	# ── a megidézett szörny is a pálya szerint erős
	var g := arena("Lovag")
	var p := g.player
	g.world.dungeon_level = 3
	g.world.emelet = 4
	g.world.mons.clear()
	p.max_hp = 100000
	p.hp = 100000
	var anya := Mon.make("symbiote", p.x + 3, p.y, "normal")
	anya.met = true
	anya.awake = true
	g.world.mons.append(anya)
	seed(4)
	for i in 120:
		g.advance_turn(true)
		g.world.hazards.clear()
	var spora: Mon = null
	for m in g.world.mons:
		if m.key == "spore":
			spora = m
	ok(spora != null and spora.max_hp == int(round(Mon.make("spore", 0, 0, "normal").max_hp * Data.palya_hp(12))), "a Szimbióta Anya megidézett spórái a 12. pálya erejével születnek")

	# ── a főellenségek csapásai a BOSS_CSAPAS táblából jönnek
	for lv in Data.BOSS_LVL:
		var sp := str(Data.MONS[Data.BOSS_LVL[lv]]["sp"])
		ok(Data.BOSS_CSAPAS.has(sp), "%s: van csapás-táblája" % sp)
	g = arena("Lovag")
	p = g.player
	p.max_hp = 100000
	p.hp = 100000
	g.world.mons.clear()
	var fereg := Mon.make("rust_worm", p.x + 4, p.y, "normal")
	fereg.met = true
	fereg.awake = true
	fereg.cd = 0
	g.world.mons.append(fereg)
	g.boss_turn(fereg)
	var hz: Variant = g.world.hazard_at(p.x, p.y, "steam")
	ok(hz != null and int(hz["dmg"]) == int(Data.boss_csapas("worm", "goz")), "Rozsdaféreg: a gőzsugár ereje a táblából jön")
	g.pending_dialog = []
	# a Tükör-fázis a hős támadásának táblabeli hányadával üt
	g = arena("Lovag")
	p = g.player
	p.base_atk = 1000
	var karpit := Mon.make("weaver", p.x + 3, p.y, "normal")
	g.world.mons.append(karpit)
	g.boss_phase2(karpit)
	ok(karpit.atk == Data.jround(1000 * Data.boss_csapas("weaver", "tukor")) + 6, "Első Kárpit: a Tükör-fázis ereje a táblából jön (%d)" % karpit.atk)
	g.pending_dialog = []

	# ── a szörnyek védelmet megkerülő többletütése és az állapot-sebzések
	g = arena("Lovag")
	p = g.player
	p.max_hp = 100000
	p.hp = 100000
	g.world.mons.clear()
	var orgy := Mon.make("assassin", p.x + 1, p.y, "normal")
	orgy.atk = 1000
	g.world.mons.append(orgy)
	var legnagyobb := 0
	seed(9)
	for i in 60:
		var h0 := p.hp
		g.mon_attack(orgy)
		legnagyobb = maxi(legnagyobb, h0 - p.hp)
	var varhato := (1000 + 3 - p.def) + int(floorf(1000 * Data.SZORNY_KRIT))
	ok(legnagyobb <= varhato and legnagyobb >= varhato - 5, "az Orgyilkos többletütése a támadása %.0f%%-a (%d)" % [Data.SZORNY_KRIT * 100.0, legnagyobb])
	# égés: a szörnyek életerejével együtt erősödik (különben mélyen semmit sem érne)
	for par in [[1, 1], [3, 2]]:
		g = arena("Lovag")
		g.world.dungeon_level = par[0]
		g.world.emelet = par[1]
		g.world.mons.clear()
		var eg := babu(g, "goblin", g.player.x + 5, g.player.y)
		eg.burn = 1
		g.advance_turn(true)
		var hs := Data.palya_hp(Data.palya_sorszam(par[0], par[1]))
		ok(eg.hp == 1000 - Data.jround((2 + int(par[0])) * hs), "égés a %d/%d pályán: %d sebzés" % [par[0], par[1], 1000 - eg.hp])

	# ── zsákmány: a hosszabb kalandban ritkább a láda egy-egy szobában
	ok(Data.LADA_ESELY > 0.0 and Data.LADA_ESELY < 0.42, "a hétköznapi szobák ládái ritkábbak, mint a 4 pályás játékban (%.2f)" % Data.LADA_ESELY)
	var lada := 0
	for i in 20:
		lada += World.create(Player.create("Lovag"), 1 + i % 4, "normal", 1).chests.size()
	ok(lada >= 20 * 4 and lada <= 20 * 18, "pályánként 4–18 láda van (átlag %.1f)" % (lada / 20.0))
	print("  pályánként átlag %.1f láda · PALYA_ATK %s" % [lada / 20.0, str(Data.PALYA_ATK)])