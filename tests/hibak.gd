extends SceneTree
## Három bejelentett hiba célzott próbája:
##   godot --headless --path . -s res://tests/hibak.gd
## 1) a gyógyital visszatölti-e az életerőt
## 2) a mágus varázsgömbje eltűnik-e a becsapódás után
## 3) a szörnyek lépnek-e akkor is, ha a hős áll

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
	print("  %s %s" % ["OK  " if cond else "HIBA", what])


func mk(nm: String, rar: String) -> Item:
	return Item.make(Item.find_base(nm), rar, 1)


## Játék üres pályán, ismert helyen álló hőssel
func arena(cls: String) -> Game:
	var g := Game.new()
	g.now_ms = func() -> float: return float(Time.get_ticks_msec())
	g.start(cls, "normal")
	return g


func _init() -> void:
	seed(999)
	print("══════ 1. GYÓGYITAL ══════")
	test_heal()
	print("══════ 2. VARÁZSGÖMB (lövedék eltűnése) ══════")
	test_fx()
	print("══════ 3. ÉLŐ KATAKOMBA (a hős áll) ══════")
	test_idle()
	print("══════ ÖSSZESEN: %d ellenőrzés, %d hiba ══════" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_heal() -> void:
	var g := arena("Lovag")
	var p := g.player
	var it := mk("Gyógyital", "common")
	ok(it.heal == 25, "a gyógyital ereje 25 (%d)" % it.heal)

	# sebzett hős: töltsön
	p.max_hp = 100
	p.hp = 40
	p.inventory.append(it)
	g.use_item(it)
	ok(p.hp == 65, "40 HP-ról 65-re tölt (lett: %d)" % p.hp)
	ok(not p.inventory.has(it), "a felhasznált ital kikerül a táskából")

	# teli hősnél nem megy a maximum fölé
	var it2 := mk("Gyógyital", "common")
	p.hp = 95
	p.inventory.append(it2)
	g.use_item(it2)
	ok(p.hp == 100, "95 HP-ról a maximumig tölt, nem tovább (lett: %d)" % p.hp)

	# nagy gyógyital
	var it3 := mk("Nagy gyógyital", "common")
	p.hp = 20
	p.inventory.append(it3)
	g.use_item(it3)
	ok(p.hp == 20 + it3.heal, "a nagy gyógyital %d-et tölt (lett: %d)" % [it3.heal, p.hp - 20])

	# MÉRGEZETTEN: az „élő katakomba” óta a körök állva is peregnek (kb. másodpercenként
	# egy), és eddig a méreg is velük. A játékos ilyenkor azt látja, hogy megissza az
	# italt, mégis fogy az élete – ezért tűnhet úgy, hogy a gyógyital nem tölt.
	p.max_hp = 100
	p.hp = 40
	p.poison = 8
	var it4 := mk("Gyógyital", "common")
	p.inventory.append(it4)
	g.use_item(it4)
	var ital_utan: int = p.hp
	ok(ital_utan == 65, "mérgezetten is 65-re tölt (lett: %d)" % ital_utan)
	for i in 6:
		g.advance_turn(true)      # várakozó kör (élő katakomba)
	print("     6 várakozó kör után mérgezetten: %d HP" % p.hp)
	ok(p.hp >= ital_utan, "a várakozó körök nem eszik meg a gyógyítást (lett: %d)" % p.hp)
	ok(p.poison == 8, "a méreg nem fogy a várakozó körökben sem (%d)" % p.poison)

	# a hős SAJÁT köreiben viszont marnia kell
	var merge_elott: int = p.hp
	for i in 3:
		g.advance_turn()          # valódi kör: a hős tett valamit
	ok(p.hp < merge_elott, "a hős saját köreiben a méreg tovább mar (%d -> %d)" % [merge_elott, p.hp])
	ok(p.poison == 5, "és a méreg hátralévő ideje is fogy (%d)" % p.poison)


func test_fx() -> void:
	var g := arena("Mágus")
	# FIGYELEM: a GDScript lambdája ÉRTÉK szerint zárja a helyi változót, ezért
	# egy sima float nem működne – tömbben tartjuk, az hivatkozás.
	var t := [0.0]
	g.now_ms = func() -> float: return t[0]

	g.fx.clear()
	g.add_fx({"type": "orb", "x0": 1, "y0": 1, "x1": 5, "y1": 5, "dur": 300.0})
	g.add_fx({"type": "dmgnum", "x": 5, "y": 5, "txt": "-10", "col": "#fff", "dur": 700.0})
	ok(g.fx.size() == 2, "a két látványelem bekerült (%d)" % g.fx.size())

	# a lövedék röptének felénél még látszania kell
	t[0] = 150.0
	g.prune_fx()
	ok(g.fx.size() == 2, "röpülés közben megmarad (%d)" % g.fx.size())

	# a lövedék lejárt, a sebzésszám még nem
	t[0] = 400.0
	g.prune_fx()
	ok(g.fx.size() == 1, "a becsapódott varázsgömb eltűnik (%d maradt)" % g.fx.size())
	ok(g.fx[0]["type"] == "dmgnum", "a még futó sebzésszám megmarad")

	# minden lejárt
	t[0] = 900.0
	g.prune_fx()
	ok(g.fx.is_empty(), "a lejárt sebzésszám is eltűnik (%d maradt)" % g.fx.size())

	# késleltetett elem: a delay is számít
	t[0] = 0.0
	g.fx.clear()
	g.add_fx({"type": "mburst", "x": 5, "y": 5, "dur": 420.0, "delay": 300.0})
	t[0] = 500.0
	g.prune_fx()
	ok(g.fx.size() == 1, "a késleltetett becsapódás még fut (%d)" % g.fx.size())
	t[0] = 800.0
	g.prune_fx()
	ok(g.fx.is_empty(), "a késleltetett becsapódás is eltűnik")

	# nem nő korlátlanul: sok elem után is elfogy
	t[0] = 0.0
	g.fx.clear()
	for i in 200:
		g.add_fx({"type": "dmgnum", "x": 1, "y": 1, "txt": "-1", "col": "#fff", "dur": 100.0})
	t[0] = 200.0
	g.prune_fx()
	ok(g.fx.is_empty(), "200 lejárt elem után sem marad semmi (%d)" % g.fx.size())


func test_idle() -> void:
	var g := arena("Lovag")
	var w := g.world
	var p := g.player

	var mon: Mon = null
	for m in w.mons:
		if m.alive:
			mon = m
			break
	ok(mon != null, "van szörny a pályán")
	if mon == null:
		return

	# A szörnynek NINCS útkeresése: a hős felé tesz egy lépést, és ha ott fal van,
	# megáll. Ezért a próbához a hős mellé, szabad mezőre tesszük – különben nem
	# azt mérnénk, amit akarunk.
	var hely := Vector2i(-1, -1)
	for tav in range(2, 7):
		for d in [Vector2i(tav, 0), Vector2i(-tav, 0), Vector2i(0, tav), Vector2i(0, -tav)]:
			var x: int = p.x + d.x
			var y: int = p.y + d.y
			# a köztes mezők is legyenek szabadok, hogy tudjon közelíteni
			var szabad := true
			for k in range(1, tav + 1):
				var kx: int = p.x + (d.x / tav) * k
				var ky: int = p.y + (d.y / tav) * k
				if w.blocked(kx, ky):
					szabad = false
					break
			if szabad and w.mon_at(x, y) == null and hely.x < 0:
				hely = Vector2i(x, y)
	ok(hely.x >= 0, "találtunk szabad helyet a hős közelében")
	if hely.x < 0:
		return
	mon.x = hely.x
	mon.y = hely.y

	# a szörny ébren van és lát minket: a hős állva marad, mégis közelítenie kell
	mon.awake = true
	var tav_elott: int = absi(mon.x - p.x) + absi(mon.y - p.y)
	var hely_elott := Vector2i(mon.x, mon.y)
	var px := p.x
	var py := p.y
	for i in 6:
		g.advance_turn()
	var tav_utan: int = absi(mon.x - p.x) + absi(mon.y - p.y)
	ok(p.x == px and p.y == py, "a hős tényleg nem mozdult")
	ok(Vector2i(mon.x, mon.y) != hely_elott or tav_utan < tav_elott,
		"az ébren lévő szörny lépett, pedig a hős állt (%s -> %s, táv %d -> %d)" %
		[hely_elott, Vector2i(mon.x, mon.y), tav_elott, tav_utan])

	# a körszámláló is nő, erre figyel a main.gd idle_tick-je
	var kor_elott: int = int(w.turn)
	g.advance_turn()
	ok(int(w.turn) == kor_elott + 1, "a várakozó kör növeli a körszámlálót")
