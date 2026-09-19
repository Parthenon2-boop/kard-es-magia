class_name Game
extends RefCounted
## A játék szabályai: mozgás, harc (közel/táv/varázsgömb), szörnyek köre, tárgyhasználat, szintek.
## Kirajzolástól független, így fej nélküli (headless) tesztből is futtatható.

var world: World
var player: Player
var fx: Array = []              # látványelemek (lövedék, villanás, sebzésszám...)
var sfx: Callable = Callable()  # hang lejátszása név szerint
var pending_chest: Variant = null  # ha a hős ládához lépett
var now_ms: Callable = func() -> float: return Time.get_ticks_usec() / 1000.0


func play(n: String) -> void:
	if sfx.is_valid():
		sfx.call(n)


func add_fx(o: Dictionary) -> void:
	o["t0"] = now_ms.call()
	fx.append(o)


func start(cls: String, diff: String) -> void:
	player = Player.create(cls)
	player.on_level_up = play.bind("levelup")   # metódus-hivatkozás: nincs körkörös hivatkozás
	world = World.create(player, 1, diff)
	fx.clear()
	player.add_msg("Kaland kezdete! ♥♥♥", Data.P["parchGold"])


## true, ha a játék véget ért (győzelem)
func next_level() -> bool:
	var n := world.dungeon_level + 1
	if n > Data.MAX_LEVEL:
		return true
	player.add_msg("%d. mélység..." % n, "#9060d0")
	world = World.create(player, n, world.diff)
	fx.clear()
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
	# lovag: 20% eséllyel pajzzsal felfogja az ütés felét
	if p.cls == "Lovag" and randf() < 0.2:
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


func kill_check(m: Mon, dmg: int, hit_msg: String, hit_col: String) -> void:
	var p := player
	if m.hp <= 0:
		m.alive = false
		p.gain_xp(m.xp, Data.DIFF[world.diff]["xpMult"])
		p.add_msg("%s elesett! +%dxp" % [m.name, m.xp], Data.P["parchGold"])
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
	kill_check(m, dmg, "%s: -%d", "#e0a040")
	return dmg


## Lőtáv: a mágus varázsgömbje mindig 5 mező; a többieknek íj vagy ágyú kell (az íjász +1 mezővel lő)
func ranged_range() -> int:
	var p := player
	if p.cls == "Mágus":
		return Data.MAGE_RANGE
	if p.weapon and p.weapon.reach > 0:
		return p.weapon.reach + (1 if p.cls == "Íjász" else 0)
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
	for d in range(1, rng + 1):
		var tx := p.x + dx * d
		var ty := p.y + dy * d
		if w.blocked(tx, ty):
			return 0   # a fal felfogja a lövést
		var m := w.mon_at(tx, ty)
		if m == null:
			continue
		if d == 1 and not mage:
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
			if p.cls == "Íjász" and wep.subtype == "bow" and randf() < 0.3:
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
		advance_turn()
		return dmg
	return 0


# ══════════ KÖRÖK ══════════
func advance_turn() -> void:
	var w := world
	var p := player
	w.turn += 1
	if p.poison > 0:
		p.poison -= 1
		var d := Data.rnd(2, 5)
		p.hp = maxi(1, p.hp - d)
		p.add_msg(("☠ Méreg -%d" % d) if p.poison > 0 else "Méreg lejárt", "#90c030")
	# regeneráció (nagyon ritka / legendás páncél és pajzs)
	var rg := p.regen
	if rg > 0 and p.alive and p.hp > 0 and p.hp < p.max_hp:
		p.hp = mini(p.max_hp, p.hp + rg)
	for m in w.mons:
		if not m.alive or not p.alive:
			continue
		if not w.is_exp(m.x, m.y):
			continue
		if w.is_vis(m.x, m.y):
			var dx := 0 if p.x == m.x else (1 if p.x > m.x else -1)
			var dy := 0 if p.y == m.y else (1 if p.y > m.y else -1)
			if dx != 0:
				m.facing = dx
			var nx := m.x + dx
			var ny := m.y + dy
			if nx == p.x and ny == p.y:
				mon_attack(m)
			elif not w.blocked(nx, ny) and w.mon_at(nx, ny) == null:
				m.x = nx
				m.y = ny
		elif randf() < 0.22:
			var d: Vector2i = Data.pick(Dungeon.DIRS)
			if d.x != 0:
				m.facing = d.x
			var nx := m.x + d.x
			var ny := m.y + d.y
			if not w.blocked(nx, ny) and w.mon_at(nx, ny) == null and not (nx == p.x and ny == p.y):
				m.x = nx
				m.y = ny


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
		w.update_fov()
		play("step")
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
			var h := mini(item.heal, p.max_hp - p.hp)
			p.hp += h
			p.add_msg("+%d HP" % h, "#40c860")
			if h > 0:
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
					m.alive = false
					p.gain_xp(m.xp, Data.DIFF[w.diff]["xpMult"])
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
