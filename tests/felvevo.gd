extends SceneTree
## Előzetes-felvevő: a honlap előzetes videójának jeleneteit játssza le és menti képsorba.
## NEM része a játéknak és a teszteknek (a tests mappa nem kerül a kiadásba).
##
##   godot --path . --fixed-fps 30 --resolution 1280x720 -s res://tests/felvevo.gd -- \
##       --shot=felvetel --scene=blank --size=1280x720 --frames=999999 --lang=hu \
##       --jelenet=z1 --ki=C:/tmp/z1 --kockak=360
##
## A főjelenet a képernyőkép-módjában indul (`--shot=`): így nem ír mentést, nem nyúl a játékos
## beállításaihoz és a Műtőterem állásához, és az idő magától nem telik — a köröket a felvevő
## lépteti, kockára pontosan. A hős egy egyszerű robot (üt / lő, kitér a jelzett csapás elől,
## használja a kaszt képességét), a jeleneteket a `_shot_elemek()` terme adja.
##
## Jelenetek: z1 (Lovag, gőzzsilip) · z2 (Mágus, ingázó szike) · z3 (Íjász, spóragubó) ·
##            z4 (Mágus, forgó padló + rejtvényszoba) · fo (Lovag a Rozsdaféreg ellen) ·
##            borito (a főmenü gombok nélkül — a záró címképhez; ehhez --scene=borito kell)


func _initialize() -> void:
	var nagyitas := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nagyitas="): nagyitas = float(a.substr(11))
	# A főjelenet egy 1280×720-as belső nézetbe rajzol: így a kép mérete nem függ az ablaktól (kis
	# kijelzőn a Windows összenyomná), és a --nagyitas=1.25 közelebb hozza a pályát — a játék
	# 1024×576 egységre rajzol, ami nyújtva tölti ki a képet (mint a „Felület mérete” beállítás).
	var nezet := SubViewport.new()
	nezet.size = Vector2i(1280, 720)
	nezet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	nezet.disable_3d = true
	if nagyitas != 1.0:
		nezet.size_2d_override = Vector2i(roundi(1280.0 / nagyitas), roundi(720.0 / nagyitas))
		nezet.size_2d_override_stretch = true
	root.add_child(nezet)
	var m: Node = (load("res://main.tscn") as PackedScene).instantiate()
	nezet.add_child(m)
	# az ablakban is látszik, mi készül
	var mutat := TextureRect.new()
	mutat.texture = nezet.get_texture()
	mutat.set_anchors_preset(Control.PRESET_FULL_RECT)
	mutat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mutat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(mutat)
	var h := Hajto.new()
	h.m = m
	h.nezet = nezet
	root.add_child(h)   # a főjelenet UTÁN fut, így a kocka végső állapotát ő állítja be


class Hajto extends Node:
	const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	const MH := Data.MAP_H

	var m: Node
	var nezet: SubViewport
	var g: Game
	var jelenet := ""
	var ki := ""
	var kockak := 300
	var nagyitas := 1.0
	var f := 0
	var sor: Array = []          # a hátralévő parancsok
	var kov := 0                 # ettől a kockától jöhet a következő parancs
	var _allapot := ""
	var _allapot_f := 0
	var _utolso_us := 0
	var _mentes: Array = []      # a háttérszálon futó képmentések
	var _lassu := 0
	var _x0 := 0
	var _y0 := 0
	var _parbeszed := 0

	func _ready() -> void:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--jelenet="): jelenet = a.substr(10)
			elif a.begins_with("--ki="): ki = a.substr(5)
			elif a.begins_with("--kockak="): kockak = int(a.substr(9))
			elif a.begins_with("--nagyitas="): nagyitas = float(a.substr(11))
		if ki != "":
			DirAccess.make_dir_recursive_absolute(ki)
			RenderingServer.frame_post_draw.connect(_ment)
		match jelenet:
			"z1": _z1()
			"z2": _z2()
			"z3": _z3()
			"z4": _z4()
			"fo": _fo()
			"borito": pass
			_: print("[felvevo] ismeretlen jelenet: ", jelenet)
		print("[felvevo] jelenet: ", jelenet, "  kockák: ", kockak)

	func _process(_delta: float) -> void:
		f += 1
		m.tick = f * 2.0     # 30 kép/mp: kockánként két "hatvanad" (a főjelenet 2,5-öt adna)
		if g != null:
			_lepes()
		# a játék több látványeleme a valós órát nézi: egy kocka ne legyen rövidebb 1/30 mp-nél
		var most := Time.get_ticks_usec()
		if _utolso_us > 0:
			var telt := most - _utolso_us
			if telt < 33333:
				OS.delay_usec(33333 - telt)
			elif telt > 45000 and f > 10:
				_lassu += 1
		_utolso_us = Time.get_ticks_usec()
		if f == kockak + 1:
			for id in _mentes:
				WorkerThreadPool.wait_for_task_completion(id)
			print("[felvevo] kész: %d kocka, ebből lassú (45 ms fölött): %d" % [kockak, _lassu])
			get_tree().quit()

	func _ment() -> void:
		if f < 1 or f > kockak:
			return
		var kep := nezet.get_texture().get_image()
		var ut := "%s/k%05d.jpg" % [ki, f - 1]
		_mentes.append(WorkerThreadPool.add_task(func() -> void:
			kep.convert(Image.FORMAT_RGB8)
			kep.save_jpg(ut, 0.93)))

	# ══════════ A ROBOT ══════════
	func _lepes() -> void:
		var p := g.player
		if m.state != _allapot:
			_allapot = m.state
			_allapot_f = f
			print("  [%4d] állapot: %s" % [f, _allapot])
		var bent := f - _allapot_f
		match m.state:
			"dialog":
				# az első párbeszéd egy másodpercig látszik, a későbbiek rövidebben (a harc a lényeg)
				if bent >= (34 if _parbeszed == 0 else 24):
					_parbeszed += 1
					for i in 30:
						if m.state != "dialog": break
						m.dialog_next()
				return
			"perk":
				if bent >= 36: m.pick_perk(0)
				return
			"relic":
				if bent >= 45: m.pick_relic(0)
				return
			"chest":
				return      # a láda ablaka a jelenet végéig nyitva marad
			"note":
				if bent >= 30: m.close_note()
				return
			"event":
				if bent >= 30: m.close_event()
				return
			"shop":
				m.close_shop()
				return
		if m.state != "play" or f < kov:
			return
		var parancs: Array = sor.pop_front() if not sor.is_empty() else ["harc"]
		var varj := 8
		match str(parancs[0]):
			"var":
				varj = int(parancs[1])
			"kor":
				g.advance_turn(true)
			"mv":
				g.do_move(int(parancs[1]), int(parancs[2]))
				varj = 5
			"q":
				g.skill()
				varj = 14
			"ut":
				varj = _ut_lepes(int(parancs[1]), int(parancs[2]))
				if p.x != int(parancs[1]) or p.y != int(parancs[2]):
					sor.push_front(parancs)
			"harc_n":
				varj = _harc()
				if int(parancs[1]) > 1 and not _latott().is_empty():
					sor.push_front(["harc_n", int(parancs[1]) - 1])
			_:
				varj = _harc()
		# a felvételen a hős ne essen el: csendben talpra áll
		if p.hp < p.max_hp * 0.55:
			p.hp = int(p.max_hp * 0.8)
		m._after_move()
		kov = f + varj

	func _latott() -> Array[Mon]:
		var ki_: Array[Mon] = []
		for mo in g.world.mons:
			if mo.alive and g.world.is_vis(mo.x, mo.y):
				ki_.append(mo)
		var p := g.player
		ki_.sort_custom(func(a: Mon, b: Mon) -> bool:
			return absi(a.x - p.x) + absi(a.y - p.y) < absi(b.x - p.x) + absi(b.y - p.y))
		return ki_

	func _szabad(x: int, y: int) -> bool:
		var w := g.world
		return not w.blocked(x, y) and w.mon_at(x, y) == null and w.chest_at(x, y) == null

	## az első szörny a megadott irányban, a lőtávon (közelharcban: egy mezőn) belül
	func _vonalban(x: int, y: int, d: Vector2i) -> Mon:
		var w := g.world
		for k in range(1, maxi(1, g.ranged_range()) + 1):
			var tx := x + d.x * k
			var ty := y + d.y * k
			if w.blocked(tx, ty):
				return null
			var mo := w.mon_at(tx, ty)
			if mo != null:
				return mo
		return null

	## Egy döntés harcban; visszaadja, hány kockát várjon utána.
	func _harc() -> int:
		var p := g.player
		var w := g.world
		# 1. jelzett csapás a hős alatt: kilép belőle
		if w.hazard_at(p.x, p.y) != null and p.rooted == 0:
			var jo := Vector2i.ZERO
			var pont := -1
			for d in DIRS4:
				var tx := p.x + d.x
				var ty := p.y + d.y
				if _szabad(tx, ty) and w.hazard_at(tx, ty) == null:
					var s := 1
					for d2 in DIRS4:
						if _vonalban(tx, ty, d2) != null: s = 2
					if s > pont:
						pont = s
						jo = d
			if pont > 0:
				g.do_move(jo.x, jo.y)
				return 6
		var latok := _latott()
		if latok.is_empty():
			g.advance_turn(true)
			return 9
		# 2. a kaszt képessége
		if p.skill_cd == 0:
			var kozel := 0
			var ket := 0
			for mo in latok:
				if absi(mo.x - p.x) <= 1 and absi(mo.y - p.y) <= 1: kozel += 1
				if absi(mo.x - p.x) <= 2 and absi(mo.y - p.y) <= 2: ket += 1
			match p.cls:
				"Lovag":
					if kozel >= 2 or (kozel >= 1 and latok[0].boss and latok[0].hp * 3 < latok[0].max_hp * 2):
						if g.skill(): return 16
				"Mágus":
					if ket >= 2:
						if g.skill(): return 16
				"Íjász":
					for d in DIRS4:
						var n := 0
						for k in range(1, maxi(4, g.ranged_range() + 1) + 1):
							if w.blocked(p.x + d.x * k, p.y + d.y * k): break
							if w.mon_at(p.x + d.x * k, p.y + d.y * k) != null: n += 1
						if n >= 2:
							p.dir_x = d.x
							p.dir_y = d.y
							if d.x != 0: p.facing = d.x
							if g.skill(): return 16
				"Sebész":
					for d in DIRS4:
						if w.mon_at(p.x + d.x, p.y + d.y) != null:
							p.dir_x = d.x
							p.dir_y = d.y
							if g.skill(): return 14
		# 3. akit innen el lehet érni: a legközelebbit üti / lövi
		var legj := Vector2i.ZERO
		var tav := 999
		for d in DIRS4:
			var mo := _vonalban(p.x, p.y, d)
			if mo != null and absi(mo.x - p.x) + absi(mo.y - p.y) < tav:
				tav = absi(mo.x - p.x) + absi(mo.y - p.y)
				legj = d
		if tav < 999:
			g.do_move(legj.x, legj.y)
			return 11
		# 4. senki nincs vonalban
		if g.ranged_range() >= 2:
			# a lövész oda lép, ahonnan valaki célba kerül — különben megvárja őket
			for d in DIRS4:
				var tx := p.x + d.x
				var ty := p.y + d.y
				if not _szabad(tx, ty) or w.hazard_at(tx, ty) != null or w.lap_at(tx, ty) != null:
					continue
				for d2 in DIRS4:
					var mo := _vonalban(tx, ty, d2)
					if mo != null and absi(mo.x - tx) + absi(mo.y - ty) >= 2:
						g.do_move(d.x, d.y)
						return 6
			g.advance_turn(true)
			return 8
		# a közelharcos odamegy a legközelebbihez
		var celok := {}
		for d in DIRS4:
			var tx := latok[0].x + d.x
			var ty := latok[0].y + d.y
			if _szabad(tx, ty):
				celok[tx * MH + ty] = true
		var u := _ut(celok, true)
		if u.is_empty():
			g.advance_turn(true)
			return 8
		g.do_move(u[0].x - p.x, u[0].y - p.y)
		return 6

	## Szélességi keresés a hőstől a célmezők bármelyikéig; a lépések sorát adja vissza.
	func _ut(celok: Dictionary, lapot_kerul: bool) -> Array[Vector2i]:
		var p := g.player
		var w := g.world
		var out: Array[Vector2i] = []
		var start := p.x * MH + p.y
		if celok.has(start) or celok.is_empty():
			return out
		var szulo := {start: -1}
		var q: Array[int] = [start]
		var talalt := -1
		while not q.is_empty() and talalt < 0:
			var c: int = q.pop_front()
			var cx := int(c / MH)
			var cy := c % MH
			for d in DIRS4:
				var nx := cx + d.x
				var ny := cy + d.y
				var k := nx * MH + ny
				if szulo.has(k) or w.blocked(nx, ny) or w.chest_at(nx, ny) != null:
					continue
				if not celok.has(k):
					if w.mon_at(nx, ny) != null or w.hazard_at(nx, ny) != null:
						continue
					if lapot_kerul and w.lap_at(nx, ny) != null:
						continue
					if w.veszely_mezok().has(k):
						continue
				szulo[k] = c
				if celok.has(k):
					talalt = k
					break
				q.append(k)
		if talalt < 0:
			return out
		var c2 := talalt
		while c2 != start:
			out.append(Vector2i(int(c2 / MH), c2 % MH))
			c2 = szulo[c2]
		out.reverse()
		return out

	func _ut_lepes(x: int, y: int) -> int:
		var p := g.player
		var u := _ut({x * MH + y: true}, true)
		if u.is_empty():
			g.advance_turn(true)     # épp nem járható (pl. forog a korong): vár egy kört
			return 8
		g.do_move(u[0].x - p.x, u[0].y - p.y)
		return 5

	# ══════════ A JELENETEK ══════════
	func _kezd(cls: String, zona: int) -> void:
		m.skins = Skins.alap_valasztas()
		m.shot_cls = cls
		m.start_game(cls, "normal")
		g = m.game
		while g.world.dungeon_level < zona:
			g.next_level()
		Meta.uj_jelvenyek.clear()    # a mélyebb zóna elérésének jelvénye ne kerüljön az üzenetek közé
		var p := g.player
		p.plvl = 1 + (zona - 1) * 4
		p.max_hp = Data.CLASSES[cls]["hp"] + (zona - 1) * 70
		p.hp = p.max_hp
		p.gold = 18 * zona
		if zona > 1 or jelenet == "fo":
			p.xp_next = 99999        # a képességválasztó ablak csak az első jelenetben nyíljon ki
		p.msgs.clear()
		p.msg_seq += 1
		_x0 = p.x
		_y0 = p.y

	## A hős egy ütésének várható sebzése erre a szörnyre.
	func _sebzes(mo: Mon) -> int:
		var p := g.player
		if p.cls == "Mágus":
			return maxi(1, Game.magic_dmg(p.mag, mo))
		return maxi(1, Data.jround(Game.calc_dmg(p.atk, Game.mdef(mo)) * (float(Data.MELEE_MULT.get(p.cls, 1.0)) if g.ranged_range() < 2 else 1.0)))

	## Megrendezett szörny: ébren van, és ennyi ütést bír ki.
	func _szorny(kulcs: String, dx: int, dy: int, utes: float, tam: int = -1) -> Mon:
		var w := g.world
		var x := _x0 + dx
		var y := _y0 + dy
		if w.blocked(x, y) or w.mon_at(x, y) != null or w.chest_at(x, y) != null:
			return null
		var mo := Mon.make(kulcs, x, y, "normal")
		w.mons.append(mo)
		_hangol(mo, utes, tam)
		return mo

	func _hangol(mo: Mon, utes: float, tam: int = -1) -> void:
		mo.max_hp = maxi(2, int(_sebzes(mo) * utes))
		mo.hp = mo.max_hp
		mo.atk = tam if tam >= 0 else 5 + g.world.dungeon_level * 3
		mo.awake = true

	## A terem szörnyeit a jelenethez hangolja; a pálya többi lakója ne tévedjen be a képbe
	## (a mélyebb zónák kóborló szörnyei egy csapással végeznének a kezdő hőssel).
	func _terem_szornyei(utes: float) -> void:
		for mo in g.world.mons:
			if not mo.alive:
				continue
			if absi(mo.x - _x0) < 10 and absi(mo.y - _y0) < 6:
				_hangol(mo, utes)
			else:
				mo.alive = false

	func _indul() -> void:
		g.world.update_fov()
		g.fx.clear()
		g.show_zone_banner()

	# 1. zóna — Csatorna-Kazánok: lovag, gőzzsilip a folyosón
	func _z1() -> void:
		_kezd("Lovag", 1)
		m._shot_elemek()
		_terem_szornyei(2.0)
		_szorny("goblin", -6, -2, 2.0)
		_szorny("skeleton", -7, 0, 3.0)
		_szorny("rat", -6, 2, 2.0)
		_szorny("leech", 7, 0, 2.0)
		_indul()
		sor = [["var", 24]]

	# 2. zóna — Bronz Klinika: mágus, sínen ingázó szikék
	func _z2() -> void:
		_kezd("Mágus", 2)
		m._shot_elemek()
		_terem_szornyei(2.0)
		_szorny("scalpel", 8, 0, 2.0)
		_szorny("nurse", 7, 2, 3.0)
		_szorny("drone", -7, 0, 2.0)
		_szorny("skeleton", -6, -1, 2.0)
		_indul()
		sor = [["var", 24]]

	# 3. zóna — Tüdő-Kert: íjász, spóragubó
	func _z3() -> void:
		_kezd("Íjász", 3)
		m._shot_elemek()
		_terem_szornyei(2.0)
		_szorny("spider", 7, 0, 2.0)
		_szorny("spore", 8, 1, 2.0)
		_szorny("troll", 8, -1, 4.0)
		_szorny("spore", 6, -3, 2.0)
		_indul()
		# a hős melletti gubó megduzzad: ellép mellőle, mielőtt kipukkad
		sor = [["var", 24], ["mv", -1, 0], ["mv", -1, 0], ["mv", 0, 1]]

	# 4. zóna — Mag-Kamra: mágus, forgó fogaskerék-padló és a rejtvényszoba
	func _z4() -> void:
		_kezd("Mágus", 4)
		m._shot_elemek()
		_terem_szornyei(3.0)
		_szorny("sentinel", 7, 1, 2.0)
		_indul()
		var x := _x0
		var y := _y0
		# a nyomólapok a láda fölötti jelek sorrendjében, aztán a láda
		sor = [["var", 24], ["harc_n", 9], ["ut", x + 1, y + 3], ["var", 8], ["ut", x - 4, y + 4], ["var", 8],
			["ut", x + 2, y + 1], ["var", 14], ["ut", x, y + 3], ["mv", -1, 0], ["var", 9999]]

	# A zóna ura: lovag a Rozsdaféreg ellen (belépő, jelzett gőzsugár, második fázis)
	func _fo() -> void:
		_kezd("Lovag", 1)
		var w := g.world
		var p := g.player
		for ax in range(-8, 9):
			for ay in range(-4, 5):
				var x := p.x + ax
				var y := p.y + ay
				if x > 1 and y > 1 and x < Data.MAP_W - 2 and y < Data.MAP_H - 2:
					w.tiles[x * Data.MAP_H + y] = Data.FLOOR
		for mo in w.mons:
			if mo.boss or (absi(mo.x - p.x) < 14 and absi(mo.y - p.y) < 9):
				mo.alive = false
		w.traps.clear()
		w.vents.clear()
		w.gepek.clear()
		w.lapok.clear()
		w.chests = w.chests.filter(func(ch: Dictionary) -> bool: return absi(int(ch["x"]) - p.x) > 9 or absi(int(ch["y"]) - p.y) > 5)
		for mo in w.mons:
			mo.alive = false
		var fo := Mon.make(str(Data.BOSS_LVL[1]), p.x + 6, p.y, "normal")
		w.mons.append(fo)
		# a harc a felvételre van méretezve: a hős a zóna végi erejével üt, a féreg kilenc ütést bír
		p.plvl = 6
		p.base_atk += 16
		p.base_def += 4
		p.max_hp = 120
		p.hp = 120
		fo.max_hp = _sebzes(fo) * 9
		fo.hp = fo.max_hp
		fo.atk = 26
		w.update_fov()
		g.fx.clear()
		g.banner = {}
		sor = [["var", 20], ["mv", 1, 0]]
