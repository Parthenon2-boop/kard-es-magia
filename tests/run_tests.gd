extends SceneTree
## Fej nélküli tesztek:
##   godot --headless --path . -s res://tests/run_tests.gd
## 1) 300 pálya (1–5. mélység): minden padló, a lépcső és minden láda elérhető-e
## 2) harc-szimuláció kasztonként (goblin, kőgolem, sárkány): átlagos sebzés
## 3) tárgyak: fegyver/páncél/pajzs felvétele és cseréje, bájitalok, tekercsek, életlopás, regeneráció

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  HIBA: ", what)


func _init() -> void:
	seed(12345)
	print("══════ 1. PÁLYÁK (300 db) ══════")
	test_levels()
	print("══════ 2. HARC ══════")
	test_combat()
	print("══════ 3. TÁRGYAK ══════")
	test_items()
	print("══════ ÖSSZESEN: %d ellenőrzés, %d hiba ══════" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ══════════ 1. PÁLYÁK ══════════
func test_levels() -> void:
	var bad := 0
	var chests := 0
	var removed := 0
	var t0 := Time.get_ticks_msec()
	for i in 300:
		var depth := 1 + i % 5
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
		if err != "":
			bad += 1
			print("  mélység %d: %s" % [depth, err])
	ok(bad == 0, "elérhetetlen rész a pályákon")
	print("  300 pálya, %d hibás (elvárt: 0) · %d láda, ebből %d-t kellett eltüntetni · %d ms" % [bad, chests, removed, Time.get_ticks_msec() - t0])


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
	w.player = g.player
	w.diff = "normal"
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
		for key in ["goblin", "golem", "dragon"]:
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
					if "Kritikus" in msg["t"]: crits += 1
					if "Pajzs" in msg["t"]: blocks += 1
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
			print("  %-6s vs %-7s  átl. sebzés: %6.2f   · kapott ütés átl.: %5.2f%s" % [cls, Data.MONS[key]["name"], avg, float(taken) / N, extra])
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
	ok(ga.player.weapon != null and ga.player.weapon.name == "Faíj", "az íjász Faíjjal indul")
	ok(ga.ranged_range() == 4, "az íjász lőtávja íj + 1 (%d)" % ga.ranged_range())
	var ma := place(ga, "goblin", 4)
	ga.do_move(1, 0)
	ok(ma.hp < ma.max_hp, "az íjász 4 mezőre lő")
	# varázsellenállás: sárkány ellen kisebb a mágus sebzése, mint goblin ellen
	ok(res["Mágus/dragon"] < res["Mágus/goblin"], "a sárkány varázsellenállása csökkenti a sebzést")
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
	ok(mk("Erő tekercs", "common").atk_up == 5 and mk("Erő tekercs", "legendary").atk_up == 11, "erő tekercs szorzó")
	ok(mk("Véd tekercs", "common").def_up == 3 and mk("Véd tekercs", "epic").def_up == 5, "véd tekercs szorzó")
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
		var want := def_s.def_up + (2 if cls == "Lovag" else 0)
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
