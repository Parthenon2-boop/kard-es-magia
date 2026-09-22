class_name Game
extends RefCounted
## A játék szabályai: mozgás, harc (közel/táv/varázsgömb), szörnyek köre, tárgyhasználat, szintek.
## Kirajzolástól független, így fej nélküli (headless) tesztből is futtatható.

var world: World
var player: Player
var fx: Array = []              # látványelemek (lövedék, villanás, sebzésszám...)
var sfx: Callable = Callable()  # hang lejátszása név szerint
var pending_chest: Variant = null  # ha a hős ládához lépett
var pending_shop: Variant = null   # ha a hős a kereskedőre lépett
var pending_perks := 0             # hány képességet kell még választani (szintlépésenként egyet)
var autosave := true               # szintváltáskor mentsen-e (tesztben/képernyőkép-módban nem)
var now_ms: Callable = func() -> float: return Time.get_ticks_usec() / 1000.0


func play(n: String) -> void:
	if sfx.is_valid():
		sfx.call(n)


func add_fx(o: Dictionary) -> void:
	o["t0"] = now_ms.call()
	fx.append(o)


## A lejárt látványelemek törlése (a képkocka-hurok hívja).
##
## Enélkül az fx tömb SOHA nem ürült: csak új kaland és szintváltás törölte.
## A rajzoló 1.0-ra vágja a haladást, ezért a becsapódott varázsgömb ott
## maradt a célpontja fölött a mélység végéig – és a tömb is nőtt körről
## körre, minden sebzésszámmal és villanással együtt.
func prune_fx() -> void:
	if fx.is_empty():
		return
	var now: float = now_ms.call()
	var maradt: Array = []
	for f in fx:
		if now - float(f["t0"]) < float(f.get("delay", 0.0)) + float(f["dur"]):
			maradt.append(f)
	fx = maradt


func start(cls: String, diff: String) -> void:
	player = Player.create(cls)
	player.on_level_up = _level_up
	world = World.create(player, 1, diff)
	fx.clear()
	pending_perks = 0
	pending_chest = null
	pending_shop = null
	player.add_msg("Kaland kezdete! ♥♥♥", Data.P["parchGold"])


## szintlépés: hang + egy képességválasztás a sorba
func _level_up() -> void:
	play("levelup")
	pending_perks += 1


## true, ha a játék véget ért (győzelem)
func next_level() -> bool:
	var n := world.dungeon_level + 1
	if n > Data.MAX_LEVEL:
		if autosave:
			SaveGame.erase()   # a befejezett kalandot nincs mit folytatni
		return true
	player.add_msg("%d. mélység..." % n, "#9060d0")
	world = World.create(player, n, world.diff)
	fx.clear()
	if autosave:
		SaveGame.save_run(self)
	return false


func on_stair() -> bool:
	return world != null and world.tile(player.x, player.y) == Data.STAIR


static func calc_dmg(atk: int, def: int) -> int:
	return maxi(1, atk + Data.rnd(-2, 3) - def)


## varázssebzés: a páncél (védelem) csak harmadában számít, a varázsellenállás teljesen
static func magic_dmg(mag: int, m: Mon) -> int:
	return maxi(1, mag + Data.rnd(-1, 3) - int(floorf(m.def / 3.0)) - m.mres)


# ══════════ SZÖRNYEK ══════════
func mon_special(m: Mon) -> void:
	var p := player
	var w := world
	if m.sp == "lifesteal":
		var h := maxi(1, int(floorf(m.atk * 0.4)))
		m.hp = mini(m.max_hp, m.hp + h)
		p.add_msg("%s vért szív (+%d)" % [m.name, h], Data.P["vein"])
	elif m.sp == "poison" and randf() < 0.38:
		p.poison = maxi(p.poison, 4)
		p.add_msg("Megmérgeztek!", "#90c030")
	elif m.sp == "regen" and randf() < 0.28:
		m.hp = mini(m.max_hp, m.hp + int(floorf(m.max_hp * 0.05)))
	elif m.sp == "crit" and randf() < 0.3:
		var x := int(floorf(m.atk * 0.9))
		p.hp -= x
		p.add_msg("KRITIKUS! -%d" % x, Data.P["vein"])
	elif m.sp == "fireball" and randf() < 0.22:
		var d := Data.rnd(12, 20)
		p.hp -= d
		p.add_msg("Tűzgömb! -%d" % d, "#e06020")
		add_fx({"type": "boom", "x": p.x, "y": p.y, "dur": 400.0})
	elif m.sp == "aoe" and randf() < 0.18:
		var d := Data.rnd(8, 16)
		p.hp -= d
		p.add_msg("Robbanás! -%d" % d, "#e08020")
		add_fx({"type": "boom", "x": p.x, "y": p.y, "dur": 400.0})
	elif m.sp == "summon" and randf() < 0.18:
		var pool: Array = Data.POOL.get(w.dungeon_level, ["goblin"])
		var sx := m.x + Data.rnd(-2, 2)
		var sy := m.y + Data.rnd(-2, 2)
		# az idézett szörny csak járható, szabad mezőre kerülhet (falba nem)
		if not w.blocked(sx, sy) and w.mon_at(sx, sy) == null and not (sx == p.x and sy == p.y):
			w.mons.append(Mon.make(Data.pick(pool), sx, sy, w.diff))
			p.add_msg("%s idéz!" % m.name, Data.P["vein"])
	elif m.sp == "teleport" and randf() < 0.22:
		var r: Rect2i = Data.pick(w.rooms)
		var c := Dungeon.center(r)
		if w.mon_at(c.x, c.y) == null and not (c.x == p.x and c.y == p.y):
			m.x = c.x
			m.y = c.y
			m.rx = c.x
			m.ry = c.y
			p.add_msg("%s teleportál!" % m.name, "#9060d0")
	elif m.sp == "revive" and m.hp < m.max_hp * 0.3 and randf() < 0.15:
		var dead: Array = []
		for mm in w.mons:
			if not mm.alive and not mm.boss and w.mon_at(mm.x, mm.y) == null:
				dead.append(mm)
		if not dead.is_empty():
			var rev: Mon = Data.pick(dead)
			rev.alive = true
			rev.hp = int(floorf(rev.max_hp * 0.4))
			p.add_msg("%s feltámaszt!" % m.name, "#9060d0")


func mon_attack(m: Mon) -> void:
	var p := player
	var dmg := calc_dmg(m.atk, p.def)
	# lovag: 20% eséllyel pajzzsal felfogja az ütés felét (a Pajzsmester képesség növeli)
	if randf() < p.block_chance:
		dmg = int(ceilf(dmg / 2.0))
		p.add_msg("🛡 Pajzs! Felfogtad az ütés felét.", "#80a8e0")
	p.hp -= dmg
	p.add_msg("%s: -%d" % [m.name, dmg], Data.P["vein"])
	add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % dmg, "col": "#ff5040", "dur": 700.0})
	play("growl")
	play("hit")
	mon_special(m)
	check_death()


func check_death() -> void:
	var p := player
	if p.hp <= 0 and p.alive:
		p.lives -= 1
		if p.lives > 0:
			p.hp = int(floorf(p.max_hp * 0.5))
			p.add_msg("💔 Elestél! %d élet maradt." % p.lives, Data.P["vein"])
			play("death")
		else:
			p.hp = 0
			p.alive = false
			play("death")


# ══════════ A HŐS TÁMADÁSAI ══════════
## Életlopás (nagyon ritka / legendás fegyver): a kiosztott sebzés 10% / 20%-a visszajön.
func apply_lifesteal(dmg: int) -> void:
	var p := player
	if p.lifesteal <= 0.0 or dmg <= 0:
		return
	var h := mini(maxi(1, Data.jround(dmg * p.lifesteal)), p.max_hp - p.hp)
	if h <= 0:
		return
	p.hp += h
	add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "+%d" % h, "col": "#50e070", "dur": 700.0, "dy": -0.35})


## Egy legyőzött szörny jutalma: tapasztalat és arany (a főellenség és a kincstár őre bőkezűbb;
## a Kincsvadász képesség 50%-kal többet ad).
func kill_reward(m: Mon) -> int:
	var p := player
	m.alive = false
	p.gain_xp(m.xp, Data.DIFF[world.diff]["xpMult"])
	var g := Data.rnd(Data.GOLD_MIN, Data.GOLD_MAX + world.dungeon_level * 2)
	if m.boss:
		g = Data.rnd(Data.GOLD_BOSS[0], Data.GOLD_BOSS[1])
	elif m.guard:
		g *= 3
	g = Data.jround(g * (1.0 + 0.5 * p.perk("kincs")))
	p.gold += g
	return g


func kill_check(m: Mon, dmg: int, hit_msg: String, hit_col: String) -> void:
	var p := player
	if m.hp <= 0:
		var g := kill_reward(m)
		p.add_msg("%s elesett! +%dxp, +%d arany" % [m.name, m.xp, g], Data.P["parchGold"])
		if m.boss:
			p.add_msg("⚜ BOSS LEGYŐZVE!", Data.P["legendary"])
	else:
		p.add_msg(hit_msg % [m.name, dmg], hit_col)
		play("growl")


func p_attack(m: Mon) -> int:
	var p := player
	# közelharc: a lovag erős, az íjász és a mágus gyengébb közelről
	var dmg := maxi(1, Data.jround(calc_dmg(p.atk, m.def) * float(Data.MELEE_MULT.get(p.cls, 1.0))))
	m.hp -= dmg
	add_fx({"type": "slash", "x": m.x, "y": m.y, "dur": 250.0})
	add_fx({"type": "dmgnum", "x": m.x, "y": m.y, "txt": "-%d" % dmg, "col": "#ffd060", "dur": 700.0})
	play("sword")
	p.lunge = 1.0
	p.lunge_dx = m.x - p.x
	p.lunge_dy = m.y - p.y
	apply_lifesteal(dmg)
	# Pajzsdöfés (lovag képesség): esély egy környi kábításra
	if m.hp > 0 and p.perk("dofes") > 0 and randf() < 0.25 * p.perk("dofes"):
		m.stun = 1
		p.add_msg("⛨ Pajzsdöfés! %s elkábult." % m.name, "#80a8e0")
	kill_check(m, dmg, "%s: -%d", "#e0a040")
	return dmg


## Lőtáv: a mágus varázsgömbje mindig 5 mező; a többieknek íj vagy ágyú kell (az íjász +1 mezővel lő)
func ranged_range() -> int:
	var p := player
	if p.cls == "Mágus":
		return Data.MAGE_RANGE + p.perk("messzi")   # "Messzi gömb"
	if p.weapon and p.weapon.reach > 0:
		return p.weapon.reach + (1 if p.cls == "Íjász" else 0) + p.perk("hosszuij")
	return 0


## Távolsági támadás: az első szörnyre egyenes vonalban, a lőtávon belül. Visszaadja a sebzést (0: nem lőtt).
func try_ranged_attack(dx: int, dy: int) -> int:
	var p := player
	var w := world
	var wep := p.weapon
	var mage := p.cls == "Mágus"
	var rng := ranged_range()
	if rng < 2:
		return 0
	var total := 0
	for d in range(1, rng + 1):
		var tx := p.x + dx * d
		var ty := p.y + dy * d
		if w.blocked(tx, ty):
			break   # a fal felfogja a lövést
		var m := w.mon_at(tx, ty)
		if m == null:
			continue
		if d == 1 and not mage and total == 0:
			return 0   # szomszédos: közelharc (a mágus közelről is varázsol)
		var dmg := 0
		var col := "#ffd060"
		if mage:
			dmg = magic_dmg(p.mag, m)
			col = "#8cc4ff"
			var fl := 120.0 + d * 45.0
			add_fx({"type": "orb", "x0": p.x, "y0": p.y, "x1": m.x, "y1": m.y, "dur": fl})
			add_fx({"type": "mburst", "x": m.x, "y": m.y, "dur": 420.0, "delay": fl})
			play("magic")
		else:
			dmg = calc_dmg(p.atk, m.def)
			if p.cls == "Íjász" and wep.subtype == "bow" and randf() < p.crit_chance:
				dmg = int(floorf(dmg * 2.2))
				p.add_msg("🏹 Kritikus!", Data.P["parchGold"])
			var is_cannon := wep.subtype == "cannon"
			add_fx({"type": "ball" if is_cannon else "arrow", "x0": p.x, "y0": p.y, "x1": m.x, "y1": m.y, "dur": 300.0 if is_cannon else 200.0})
			if is_cannon:
				play("cannon")
				add_fx({"type": "boom", "x": m.x, "y": m.y, "dur": 350.0})
			else:
				play("shoot")
		m.hp -= dmg
		add_fx({"type": "dmgnum", "x": m.x, "y": m.y, "txt": "-%d" % dmg, "col": col, "dur": 700.0, "delay": (120.0 + d * 45.0) if mage else 0.0})
		if dx != 0:
			p.facing = dx
		apply_lifesteal(dmg)
		kill_check(m, dmg, ("Varázsgömb: %s -%d" if mage else "Lövés: %s -%d"), ("#8cc4ff" if mage else "#e0a040"))
		total += dmg
		# "Átütő gömb": a mágus gömbje eséllyel továbbrepül a célponton
		if mage and p.perk("atuto") > 0 and randf() < 0.2 * p.perk("atuto") and d < rng:
			p.add_msg("✳ A gömb átüt!", "#a0d0ff")
			continue
		advance_turn()
		return total
	if total > 0:
		advance_turn()
	return total


# ══════════ KÖRÖK ══════════
## Egy kör lepergetése.
##
## `idle` = a hős NEM tett semmit, csak telt az idő (élő katakomba). Ilyenkor a
## szörnyek lépnek – ez a feature lényege –, de a hőst érő, KÖRÖNKÉNTI hatások
## nem futnak le. Enélkül a méreg a valós időben marta le a gyógyitalt, amíg a
## játékos gondolkodott: hat várakozó kör alatt a 25 HP-s italból 20 elfogyott,
## ezért tűnt úgy, hogy a gyógyital nem tölt semmit. A regeneráció ugyanígy
## kimarad, különben álldogálással ingyen lehetne gyógyulni.
func advance_turn(idle := false) -> void:
	var w := world
	var p := player
	w.turn += 1
	if not idle:
		if p.poison > 0:
			p.poison -= 1
			var d := Data.rnd(2, 5)
			p.hp = maxi(1, p.hp - d)
			p.add_msg(("☠ Méreg -%d" % d) if p.poison > 0 else "Méreg lejárt", "#90c030")
		# regeneráció (nagyon ritka / legendás páncél és pajzs)
		var rg := p.regen
		if rg > 0 and p.alive and p.hp > 0 and p.hp < p.max_hp:
			p.hp = mini(p.max_hp, p.hp + rg)
		spot_hidden()
	for m in w.mons:
		if not m.alive or not p.alive:
			continue
		if m.stun > 0:
			m.stun -= 1
			continue
		if not w.is_exp(m.x, m.y) and not m.awake:
			continue
		if w.is_vis(m.x, m.y) or m.awake:
			var dx := 0 if p.x == m.x else (1 if p.x > m.x else -1)
			var dy := 0 if p.y == m.y else (1 if p.y > m.y else -1)
			if dx != 0:
				m.facing = dx
			var nx := m.x + dx
			var ny := m.y + dy
			if nx == p.x and ny == p.y:
				mon_attack(m)
			else:
				# A szörnynek nincs útkeresése: a hős felé tesz egy lépést. Ha ott
				# fal van, eddig egyszerűen MEGÁLLT – a folyosókon ezért látszott
				# úgy, hogy a szörnyek meg sem mozdulnak. Most megkerüli: előbb
				# az átlós lépés, aztán a két tengely menti irány.
				for l: Vector2i in [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]:
					if l.x == 0 and l.y == 0:
						continue
					var lx: int = m.x + l.x
					var ly: int = m.y + l.y
					if lx == p.x and ly == p.y:
						mon_attack(m)
						break
					if not w.blocked(lx, ly) and w.mon_at(lx, ly) == null:
						m.x = lx
						m.y = ly
						break
		elif randf() < 0.22:
			var d: Vector2i = Data.pick(Dungeon.DIRS)
			if d.x != 0:
				m.facing = d.x
			var nx := m.x + d.x
			var ny := m.y + d.y
			if not w.blocked(nx, ny) and w.mon_at(nx, ny) == null and not (nx == p.x and ny == p.y):
				m.x = nx
				m.y = ny


# ══════════ CSAPDÁK ÉS TITKOS AJTÓK ══════════
## A hős minden körben eséllyel észrevesz egy szomszédos csapdát vagy titkos ajtót
## (az íjász sokkal gyakrabban).
func spot_hidden() -> void:
	var p := player
	var w := world
	var pc := Data.TRAP_SPOT_ARCHER if p.cls == "Íjász" else Data.TRAP_SPOT
	for t in w.traps:
		if t["found"] or absi(t["x"] - p.x) > 1 or absi(t["y"] - p.y) > 1:
			continue
		if randf() < pc:
			t["found"] = true
			p.add_msg("👁 %s! Észrevetted." % Data.TRAPS[t["type"]]["label"], "#e0c060")
	for s in w.secrets:
		if s["found"] or absi(s["x"] - p.x) > 1 or absi(s["y"] - p.y) > 1:
			continue
		if randf() < pc * 0.6:
			w.open_secret(s)
			play("chest")
			p.add_msg("🚪 Titkos ajtó nyílt ki!", Data.P["parchGold"])


## Kutatás (K): a szomszédos mezők átvizsgálása. Egy kört vesz igénybe.
func search() -> bool:
	var p := player
	var w := world
	if not p.alive:
		return false
	var pc := 1.0 if p.cls == "Íjász" else Data.SEARCH_CHANCE
	var found := 0
	for t in w.traps:
		if not t["found"] and absi(t["x"] - p.x) <= 1 and absi(t["y"] - p.y) <= 1 and randf() < pc:
			t["found"] = true
			found += 1
			p.add_msg("👁 %s a közelben!" % Data.TRAPS[t["type"]]["label"], "#e0c060")
	for s in w.secrets:
		if not s["found"] and absi(s["x"] - p.x) <= 1 and absi(s["y"] - p.y) <= 1 and randf() < pc:
			w.open_secret(s)
			found += 1
			play("chest")
			p.add_msg("🚪 Titkos ajtót találtál!", Data.P["parchGold"])
	if found == 0:
		p.add_msg("🔍 Kutatsz... semmi.", Data.P["inkDark"])
	advance_turn()
	return true


## Rálépés egy csapdára: felfedi és elsüti (egyszer sül el, utána látható marad).
func trigger_trap() -> bool:
	var p := player
	var t: Variant = world.trap_at(p.x, p.y)
	if t == null or t["sprung"]:
		return false
	t["found"] = true
	t["sprung"] = true
	match t["type"]:
		"tuske":
			var d := maxi(3, Data.rnd(Data.jround(p.max_hp * Data.TRAP_DMG_MIN), Data.jround(p.max_hp * Data.TRAP_DMG_MAX)))
			p.hp -= d
			p.add_msg("⚠ Tüskecsapda! -%d" % d, Data.P["vein"])
			add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % d, "col": "#ff5040", "dur": 700.0})
			play("hit")
		"mereg":
			var d2 := maxi(2, Data.jround(p.max_hp * Data.TRAP_DMG_MIN * 0.6))
			p.hp -= d2
			p.poison = maxi(p.poison, 5)
			p.add_msg("☠ Méregcsapda! -%d és megmérgeztek." % d2, "#90c030")
			add_fx({"type": "boom", "x": p.x, "y": p.y, "dur": 400.0})
			play("hit")
		"riaszto":
			var n := 0
			for m in world.mons:
				if m.alive and not m.awake and absi(m.x - p.x) <= Data.ALARM_R and absi(m.y - p.y) <= Data.ALARM_R:
					m.awake = true
					n += 1
			p.add_msg("🔔 Riasztó! %d szörny felriadt." % n, "#e0a030")
			play("growl")
	check_death()
	return true


## Szentély: egyszer használható áldás.
func trigger_shrine() -> bool:
	var p := player
	var s: Variant = world.shrine_at(p.x, p.y)
	if s == null or s["used"]:
		return false
	s["used"] = true
	play("levelup")
	match s["kind"]:
		"gyogyulas":
			p.hp = p.max_hp
			p.add_msg("✛ %s: teljesen meggyógyultál." % Data.SHRINES["gyogyulas"]["label"], "#50d080")
		"elet":
			p.lives += 1
			p.add_msg("✛ %s: +1 élet!" % Data.SHRINES["elet"]["label"], "#e06080")
		"vedelem":
			p.base_def += 2
			p.add_msg("✛ %s: +2 védelem örökre." % Data.SHRINES["vedelem"]["label"], "#5080e0")
		"varazs":
			p.base_mag += 3
			p.add_msg("✛ %s: +3 varázserő örökre." % Data.SHRINES["varazs"]["label"], "#8cc4ff")
	return true


# ══════════ KERESKEDŐ ══════════
## Vásárlás a hulló aranyból. true, ha sikerült.
func buy(shop: Dictionary, i: int) -> bool:
	var p := player
	if i < 0 or i >= (shop["stock"] as Array).size():
		return false
	var s: Dictionary = shop["stock"][i]
	if s["sold"]:
		return false
	var price := int(s["price"])
	if p.gold < price:
		p.add_msg("Nincs elég aranyad (%d arany kell)." % price, Data.P["vein"])
		return false
	p.gold -= price
	s["sold"] = true
	play("chest")
	if s["kind"] == "heal":
		p.hp = p.max_hp
		p.add_msg("−%d arany: teljes gyógyulás." % price, "#40c860")
	else:
		var it: Item = s["item"]
		p.inventory.append(it)
		p.add_msg("−%d arany: %s a táskádba került." % [price, it.label], it.glow())
	return true


## Egy lépés / támadás a megadott irányba. true, ha történt valami.
func do_move(dx: int, dy: int) -> bool:
	var p := player
	var w := world
	if not p.alive:
		return false
	if dx != 0:
		p.facing = dx   # arcirány követi a mozgást
	# előbb távolsági támadás (ha van lőtáv és szörny a vonalban)
	if try_ranged_attack(dx, dy) > 0:
		return true
	var nx := p.x + dx
	var ny := p.y + dy
	var m := w.mon_at(nx, ny)
	if m:
		p_attack(m)
		advance_turn()
		return true
	var ch: Variant = w.chest_at(nx, ny)
	if ch != null:
		play("chest")
		pending_chest = ch
		return true
	if not w.blocked(nx, ny):
		p.x = nx
		p.y = ny
		p.steps += 1
		w.update_fov()
		play("step")
		var trapped := trigger_trap()
		trigger_shrine()
		var sh: Variant = w.shop_at(nx, ny)
		if sh != null:
			pending_shop = sh
		# "Gyors léptek" (íjász): minden 5. lépés ingyen — nem telik vele kör
		if p.perk("gyorslab") > 0 and p.steps % 5 == 0 and not trapped:
			return true
		advance_turn()
		return true
	return false


# ══════════ TÁRGYAK ══════════
func equip(item: Item) -> void:
	var p := player
	var old: Item = null
	if item.slot == "weapon":
		old = p.weapon
		p.weapon = item
	elif item.slot == "armor":
		old = p.armor
		p.armor = item
	elif item.slot == "shield":
		old = p.shield
		p.shield = item
	else:
		return
	p.inventory.erase(item)
	if old:
		p.inventory.append(old)
	var c := {"weapon": "#a0c8e0", "armor": "#8090c0", "shield": "#80a0c0"}
	p.add_msg("Felvéve: %s" % item.label, c[item.slot])


## Tárgy használata a táskából. true, ha elhasználódott / felvette.
func use_item(item: Item) -> bool:
	var p := player
	var w := world
	if item == null:
		return false
	match item.subtype:
		"heal":
			# Teli életerőnél NEM isszuk meg: régen elfogyott a fiola, kiírta a
			# "+0 HP"-t, és a játékos joggal hitte, hogy a gyógyital nem működik.
			if p.hp >= p.max_hp:
				p.add_msg("Tele van az életerőd – a fiola marad.", "#c0c8d0")
				return false
			var h := maxi(0, mini(item.heal, p.max_hp - p.hp))
			p.hp += h
			p.add_msg("+%d HP" % h, "#40c860")
			add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "+%d" % h, "col": "#50e070", "dur": 700.0})
		"maxheal":
			# Életerő töltő: nagyobb max. életerő ÉS teljes gyógyulás
			p.max_hp += item.max_hp_up
			p.hp = p.max_hp
			p.add_msg("MaxHP +%d! Teljesen meggyógyultál." % item.max_hp_up, "#40c860")
		"fireball":
			var c := 0
			var bonus := p.mag if p.cls == "Mágus" else 0
			for m in w.mons:
				if not m.alive or not w.is_vis(m.x, m.y):
					continue
				var d := item.damage + Data.rnd(0, 15) + bonus
				m.hp -= d
				add_fx({"type": "boom", "x": m.x, "y": m.y, "dur": 400.0})
				add_fx({"type": "dmgnum", "x": m.x, "y": m.y, "txt": "-%d" % d, "col": "#ff9040", "dur": 700.0})
				if m.hp <= 0:
					kill_reward(m)
					if m.boss:
						p.add_msg("⚜ BOSS LEGYŐZVE!", Data.P["legendary"])
				c += 1
			p.add_msg("🔥 Tűzgömb! %d szörny" % c, "#e06020")
			play("cannon")
		"atk_up":
			if p.cls == "Mágus":
				var up := item.atk_up * 2
				p.base_mag += up
				p.add_msg("VARÁZSERŐ +%d örökre!" % up, "#8cc4ff")
			else:
				p.base_atk += item.atk_up
				p.add_msg("ATK +%d örökre!" % item.atk_up, "#e05050")
		"def_up":
			var up := item.def_up + (2 if p.cls == "Lovag" else 0)
			p.base_def += up
			p.add_msg("DEF +%d örökre!" % up, "#5080e0")
		_:
			if item.slot in ["weapon", "armor", "shield"]:
				equip(item)
				return true
			return false
	p.inventory.erase(item)
	return true


## A ládából választott tárgy: ha az adott hely üres, azonnal felveszi, különben a táskába kerül.
func take_chest_item(chest: Dictionary, sel: int) -> Item:
	var p := player
	var it: Item = chest["items"][sel]
	chest["opened"] = true
	if it.slot == "weapon" and p.weapon == null: p.weapon = it
	elif it.slot == "armor" and p.armor == null: p.armor = it
	elif it.slot == "shield" and p.shield == null: p.shield = it
	else: p.inventory.append(it)
	p.add_msg("Elveszed: %s" % it.label, it.glow())
	return it
