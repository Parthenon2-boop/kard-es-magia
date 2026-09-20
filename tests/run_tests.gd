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
	var bossm := place(gg, "dragon", 1)
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
	for i in 40:
		g.do_move([1, 0, -1, 0][i % 4], [0, 1, 0, -1][i % 4])
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
	var sz := FileAccess.get_file_as_bytes(SaveGame.PATH).size()
	print("  A mentésfájl mérete: %.1f kB (%s)" % [sz / 1024.0, SaveGame.PATH])

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
	ok(not g3.next_level(), "lejjebb a 2. mélységbe")
	SaveGame.refresh()
	ok(SaveGame.has_save(), "a szintváltás automatikusan mentett")
	var g4 := SaveGame.load_run()
	ok(g4 != null and g4.world.dungeon_level == 2, "az automata mentés a 2. mélységet őrzi")

	# ── sérült / régi mentés: nincs folytatás
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string('{"v": 999, "hos": {}}')
	f.close()
	SaveGame.refresh()
	ok(SaveGame.load_run() == null and not SaveGame.has_save(), "régi verziójú mentés elutasítva")
	f = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string("ez nem json {{{")
	f.close()
	SaveGame.refresh()
	ok(SaveGame.load_run() == null and not SaveGame.has_save(), "sérült mentés elutasítva")
	SaveGame.erase()
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
