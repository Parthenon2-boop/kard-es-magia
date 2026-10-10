class_name Game
extends RefCounted
## A játék szabályai: mozgás, harc (közel/táv/varázsgömb), aktív képességek, szörnyek köre,
## a főellenségek fázisai és előre jelzett csapásai, tárgyhasználat, szintek.
## Kirajzolástól független, így fej nélküli (headless) tesztből is futtatható.

var world: World
var player: Player
var fx: Array = []              # látványelemek (lövedék, villanás, sebzésszám...)
var sfx: Callable = Callable()  # hang lejátszása név szerint
var pending_chest: Variant = null  # ha a hős ládához lépett
var pending_shop: Variant = null   # ha a hős a kereskedőre lépett
var pending_perks := 0             # hány képességet kell még választani (szintlépésenként egyet)
var pending_dialog: Array = []     # lejátszandó párbeszéd: [[ki, szövegkulcs], ...]
var pending_note := ""             # most talált feljegyzés azonosítója
var banner := {}                   # nagy felirat a képernyő közepén: {k, s, col, t0}
var shake := 0.0                   # képernyőrázás (a rajzoló csillapítja)
var run_bio := 0                   # a lezárt kaland zsákmánya (az összegző képernyőhöz)
var run_rez := 0
var daily := ""                    # napi kihívás: a nap dátuma ("" = szokásos kaland)
var run_pont := 0                  # a lezárt napi kihívás pontszáma
var pending_relic := false         # a hős ereklye-talapzatra lépett: két ereklye közül választhat
var pending_event: Variant = null  # a hős döntési eseményhez ért
var focus := {}                    # a kamera egy pillanatra ide úszik: {x, y, t0, dur} (főellenség belépője)
var flash := {}                    # teljes képernyős villanás: {col, t0, dur} (fázisváltás, főellenség halála)
var autosave := true               # szintváltáskor mentsen-e (tesztben/képernyőkép-módban nem)
var now_ms: Callable = func() -> float: return Time.get_ticks_usec() / 1000.0
## a hangok ritkításához saját véletlenforrás (a játék közös véletlenjéhez nem nyúl)
var _hang_rng := RandomNumberGenerator.new()


## `vol`: 0..1 hangerő (a távoli szörny hangja halkabb)
func play(n: String, vol: float = 1.0) -> void:
	if sfx.is_valid():
		sfx.call(n, vol)


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


func start(cls: String, diff: String, napi := "") -> void:
	player = Player.create(cls)
	player.on_level_up = _level_up
	daily = napi
	run_pont = 0
	if daily == "":
		Meta.apply_to(player)   # a Műtőteremben megvett szervek és végtagok (a napi kihívásban nem számítanak)
	world = _uj_vilag(1, diff)
	fx.clear()
	pending_perks = 0
	pending_chest = null
	pending_shop = null
	pending_dialog = []
	pending_note = ""
	pending_relic = false
	pending_event = null
	focus = {}
	flash = {}
	shake = 0.0
	player.add_msg(Lang.ref("msg.start"), Data.P["parchGold"])
	show_zone_banner()


## Új zóna. A napi kihívásban a pálya a nap magjából épül: aznap mindenkinek ugyanaz.
func _uj_vilag(n: int, diff: String, em: int = 1) -> World:
	if daily == "":
		return World.create(player, n, diff, em)
	seed(Daily.mag(daily) + n * 7919 + em * 104729)
	var w := World.create(player, n, diff, em)
	randomize()   # a harc szerencséje már nem közös
	return w


## a zóna neve és célja nagy felirattal (új zónába érkezéskor)
func show_zone_banner() -> void:
	var z := Story.zone(world.dungeon_level)
	banner = {"k": "zone." + str(z["id"]), "s": "zone." + str(z["id"]) + ".goal", "col": z["acc"],
		"n": world.dungeon_level, "t0": now_ms.call()}


## szintlépés: hang + egy képességválasztás a sorba
func _level_up() -> void:
	play("levelup")
	pending_perks += 1
	add_fx({"type": "nova", "x": player.x, "y": player.y, "r": 2.2, "col": Data.P["parchGold"], "dur": 700.0})
	add_fx({"type": "dmgnum", "x": player.x, "y": player.y, "txt": "⬆", "col": "#ffe070", "dur": 1100.0, "big": true, "dy": -0.5})


## true, ha a játék véget ért (győzelem)
func next_level() -> bool:
	# a zónán belül előbb a következő emelet jön; a zóna ura az utolsón van
	if world.emelet < Data.emeletek(world.dungeon_level):
		var em := world.emelet + 1
		player.add_msg(Lang.ref("msg.emelet", em, Data.emeletek(world.dungeon_level)), Story.zone(world.dungeon_level)["acc"])
		world = _uj_vilag(world.dungeon_level, world.diff, em)
		fx.clear()
		banner = {"k": "zone." + Story.zone_id(world.dungeon_level), "s": "banner.emelet.ur" if em >= Data.emeletek(world.dungeon_level) else "banner.emelet", "col": Story.zone(world.dungeon_level)["acc"],
			"n": world.dungeon_level, "t0": now_ms.call()}
		if autosave:
			SaveGame.save_run(self)
		return false
	var n := world.dungeon_level + 1
	if n > Data.MAX_LEVEL:
		if autosave:
			SaveGame.erase()   # a befejezett kalandot nincs mit folytatni
		return true
	player.add_msg(Lang.ref("msg.depth", Lang.ref("zone." + Story.zone_id(n))), Story.zone(n)["acc"])
	world = _uj_vilag(n, world.diff)
	fx.clear()
	player.spark_used = false   # a Végső szikra zónánként újratölt
	Meta.reach(n)
	show_zone_banner()
	if autosave:
		SaveGame.save_run(self)
	return false


func on_stair() -> bool:
	return world != null and world.tile(player.x, player.y) == Data.STAIR


## Lejjebb csak a zóna urának legyőzése után lehet menni: ő őrzi a lejáratot.
func can_descend() -> bool:
	return on_stair() and world.boss() == null


static func calc_dmg(atk: int, def: int) -> int:
	return maxi(1, atk + Data.rnd(-2, 3) - def)


## varázssebzés: a páncél (védelem) csak harmadában számít, a varázsellenállás teljesen
static func magic_dmg(mag: int, m: Mon) -> int:
	return maxi(1, mag + Data.rnd(-1, 3) - int(floorf(mdef(m) / 3.0)) - m.mres)


## A szörny pillanatnyi védelme: a marás (Savmirigy) rétegenként 2-t levesz belőle.
static func mdef(m: Mon) -> int:
	return maxi(0, m.def - 2 * m.corr)


# ══════════ EREKLYÉK ÉS ÁLLAPOTOK ══════════
## A hős sebzés-szorzója erre az egy ütésre (Gőzköpeny: félreugrás után dupla). Elhasználja a töltést.
func hit_mult() -> float:
	var p := player
	if p.steam_charge:
		p.steam_charge = false
		add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 0.9, "col": "#f0f0e0", "dur": 260.0})
		return 2.0
	return 1.0


## Minden, a hős által kiosztott találat után: gyújtás, marás, vérzés, villámlánc.
func on_hit(m: Mon, dmg: int, melee := false) -> void:
	var p := player
	if not m.alive or m.hp <= 0:
		return
	if p.has_relic("gyujto"):
		m.burn = Relics.BURN_TURNS
	if p.has_relic("savmirigy") and m.corr < Relics.CORR_MAX:
		m.corr += 1
	# a Sebész minden vágása vérzést okoz
	if melee and p.cls == "Sebész":
		m.bleed = mini(Data.BLEED_MAX, m.bleed + 2)
	if p.has_relic("tesla"):
		p.hit_count += 1
		if p.hit_count % 4 == 0:
			_chain(m, maxi(1, Data.jround(dmg * 0.6)))


## Tesla-tekercs: villám ugrik a közeli ellenségekre (Rézbőrrel a martakon duplán sebez és kábít).
func _chain(from: Mon, dmg: int) -> void:
	var p := player
	var n := 0
	for o in world.mons:
		if n >= 2:
			break
		if o == from or not o.alive or absi(o.x - from.x) > 3 or absi(o.y - from.y) > 3 or not world.is_vis(o.x, o.y):
			continue
		var d := dmg
		if p.has_relic("rezbor") and o.corr > 0:
			d *= 2
			o.stun = maxi(o.stun, 1)
		add_fx({"type": "bolt", "x0": from.x, "y0": from.y, "x1": o.x, "y1": o.y, "dur": 260.0})
		hit_mon(o, d, "#8cd0ff", 60.0)
		if o.hp <= 0:
			kill_reward(o)
		n += 1
	if n > 0:
		play("magic")
		p.add_msg(Lang.ref("msg.chain", n), "#8cd0ff")


## Égés és vérzés: körönként sebez. (A marás nem sebez, csak a védelmet veszi le.)
func _tick_status() -> void:
	var dl := world.dungeon_level
	# a szörnyek életereje pályánként szorzódik: az égés és a vérzés ugyanennyivel erősebb, hogy megérje
	var hs := Data.palya_hp(world.szakasz())
	for m in world.mons:
		if not m.alive:
			continue
		var d := 0
		if m.burn > 0:
			m.burn -= 1
			d += Data.jround((2 + dl) * hs)
		if m.bleed > 0:
			d += maxi(1, int(ceilf(m.bleed * (0.5 + dl * 0.25) * hs)))
			m.bleed -= 1
		if d > 0 and world.is_exp(m.x, m.y):
			m.hp -= d
			m.hit_ms = now_ms.call()
			add_fx({"type": "dmgnum", "x": m.x, "y": m.y, "txt": "-%d" % d, "col": "#ff9040", "dur": 600.0, "dy": -0.25})
			if m.boss and m.phase == 1 and m.hp > 0 and m.hp * 2 <= m.max_hp:
				boss_phase2(m)
			if m.hp <= 0:
				var g := kill_reward(m)
				player.add_msg(Lang.ref("msg.killed", m.ref(), m.xp, g), Data.P["parchGold"])


# ══════════ A HŐST ÉRŐ SEBZÉS ══════════
## Minden, a hőst érő ütés ide fut be: villanás, képernyőrázás, és a Savas Epehólyag
## (beültetés) ilyenkor köp savat a szomszédos ellenségekre.
func hurt(dmg: int, big := false) -> void:
	var p := player
	if dmg <= 0:
		return
	p.hp -= dmg
	p.hurt_ms = now_ms.call()
	shake = maxf(shake, 7.0 if big else 4.0)
	var n := p.perk("epeholyag")
	if n > 0:
		var acid := Data.jround((3 * n + world.dungeon_level * 2) * Data.palya_hp(world.szakasz()))
		var hit := false
		for m in world.mons:
			if m.alive and absi(m.x - p.x) <= 1 and absi(m.y - p.y) <= 1:
				hit_mon(m, acid, "#b0e030")
				add_fx({"type": "puff", "x": m.x, "y": m.y, "col": "#b0e030", "dur": 380.0})
				if m.hp <= 0:
					kill_reward(m)
				hit = true
		if hit:
			p.add_msg(Lang.ref("msg.acid_spit", acid), "#b0e030")


## Egy szörnyet érő sebzés: életerő, találat-villanás, lebegő szám, fázisváltás.
func hit_mon(m: Mon, dmg: int, col: String, delay := 0.0, big := false) -> void:
	m.hp -= dmg
	m.hit_ms = now_ms.call() + delay
	m.awake = true
	add_fx({"type": "dmgnum", "x": m.x, "y": m.y, "txt": "-%d" % dmg, "col": col, "dur": 800.0 if big else 700.0, "delay": delay, "big": big})
	if m.boss and m.phase == 1 and m.hp > 0 and m.hp * 2 <= m.max_hp:
		boss_phase2(m)


# ══════════ SZÖRNYEK ══════════
func mon_special(m: Mon) -> void:
	var p := player
	var w := world
	if m.sp == "lifesteal":
		var h := maxi(1, int(floorf(m.atk * 0.4)))
		m.hp = mini(m.max_hp, m.hp + h)
		p.add_msg(Lang.ref("msg.lifesteal", m.ref(), h), Data.P["vein"])
	elif m.sp == "poison" and randf() < 0.38:
		p.poison = maxi(p.poison, 4)
		p.add_msg(Lang.ref("msg.poisoned"), "#90c030")
	elif m.sp == "regen" and randf() < 0.28:
		m.hp = mini(m.max_hp, m.hp + int(floorf(m.max_hp * 0.05)))
	elif m.sp == "crit" and randf() < 0.3:
		var x := int(floorf(m.atk * Data.SZORNY_KRIT))
		hurt(x, true)
		p.add_msg(Lang.ref("msg.crit_in", x), Data.P["vein"])
	elif m.sp == "fireball" and randf() < 0.22:
		var d := Data.jround(Data.rnd(12, 20) * Data.varazs_szorzo(w.szakasz()))
		hurt(d, true)
		p.add_msg(Lang.ref("msg.fireball_in", d), "#e06020")
		add_fx({"type": "boom", "x": p.x, "y": p.y, "dur": 400.0})
	elif m.sp == "aoe" and randf() < 0.18:
		var d := Data.jround(Data.rnd(8, 16) * Data.varazs_szorzo(w.szakasz()))
		hurt(d, true)
		p.add_msg(Lang.ref("msg.explosion", d), "#e08020")
		add_fx({"type": "boom", "x": p.x, "y": p.y, "dur": 400.0})
	elif m.sp == "summon" and randf() < 0.18:
		var pool: Array = Data.POOL.get(w.dungeon_level, ["goblin"])
		var sx := m.x + Data.rnd(-2, 2)
		var sy := m.y + Data.rnd(-2, 2)
		# az idézett szörny csak járható, szabad mezőre kerülhet (falba nem)
		if not w.blocked(sx, sy) and w.mon_at(sx, sy) == null and not (sx == p.x and sy == p.y):
			w.mons.append(w.erosit(Mon.make(Data.pick(pool), sx, sy, w.diff)))
			p.add_msg(Lang.ref("msg.summon", m.ref()), Data.P["vein"])
	elif m.sp == "teleport" and randf() < 0.22:
		var r: Rect2i = Data.pick(w.rooms)
		var c := Dungeon.center(r)
		if w.mon_at(c.x, c.y) == null and not (c.x == p.x and c.y == p.y):
			m.x = c.x
			m.y = c.y
			m.rx = c.x
			m.ry = c.y
			p.add_msg(Lang.ref("msg.teleport", m.ref()), "#9060d0")
	elif m.sp == "revive" and m.hp < m.max_hp * 0.3 and randf() < 0.15:
		var dead: Array = []
		for mm in w.mons:
			if not mm.alive and not mm.boss and w.mon_at(mm.x, mm.y) == null:
				dead.append(mm)
		if not dead.is_empty():
			var rev: Mon = Data.pick(dead)
			rev.alive = true
			rev.hp = int(floorf(rev.max_hp * 0.4))
			p.add_msg(Lang.ref("msg.revive", m.ref()), "#9060d0")


func mon_attack(m: Mon) -> void:
	var p := player
	var dmg := calc_dmg(m.atk, p.def)
	# lovag: 20% eséllyel pajzzsal felfogja az ütés felét (a Pajzsmester képesség növeli)
	if randf() < p.block_chance:
		dmg = int(ceilf(dmg / 2.0))
		p.add_msg(Lang.ref("msg.block"), "#80a8e0")
	hurt(dmg, m.boss)
	m.lunge = 1.0
	m.lunge_dx = signi(p.x - m.x)
	m.lunge_dy = signi(p.y - m.y)
	# Tükörlemez: a kapott ütés negyede visszaverődik a támadóra
	if p.has_relic("tukor") and m.alive:
		var vissza := maxi(1, int(ceilf(dmg * 0.25)))
		hit_mon(m, vissza, "#c0d8f0")
		if m.hp <= 0:
			kill_reward(m)
	p.add_msg(Lang.ref("msg.hit", m.ref(), dmg), Data.P["vein"])
	add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % dmg, "col": "#ff5040", "dur": 700.0})
	add_fx({"type": "bite", "x": p.x, "y": p.y, "dx": p.x - m.x, "dy": p.y - m.y, "dur": 220.0})
	play("growl")
	play("hit")
	mon_special(m)
	check_death()


func check_death() -> void:
	var p := player
	# Végső szikra: zónánként egyszer a halálos ütés 1 életerőn megállít, és elkábítja a szomszédokat
	if p.hp <= 0 and p.alive and p.has_relic("vegso") and not p.spark_used:
		p.spark_used = true
		p.hp = 1
		shake = maxf(shake, 9.0)
		add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 2.4, "col": "#ff6050", "dur": 650.0})
		for m in world.mons:
			if m.alive and absi(m.x - p.x) <= 1 and absi(m.y - p.y) <= 1:
				m.stun = maxi(m.stun, 2)
		p.add_msg(Lang.ref("msg.spark"), "#ff6050")
		play("levelup")
		return
	if p.hp <= 0 and p.alive:
		p.lives -= 1
		if p.lives > 0:
			p.hp = int(floorf(p.max_hp * 0.5))
			p.add_msg(Lang.ref("msg.fell", p.lives), Data.P["vein"])
			add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 2.5, "col": "#ff5040", "dur": 600.0})
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


## Egy legyőzött szörny jutalma: tapasztalat, arany és nyersanyag (a főellenség és a kincstár
## őre bőkezűbb; a Kincsvadász képesség 50%-kal több aranyat ad).
## A hús Bio-Hulladékot, a gép Rézötvözetet hagy maga után — ezek a Műtőterembe kerülnek.
func kill_reward(m: Mon) -> int:
	var p := player
	if not m.alive:
		return 0
	m.alive = false
	p.kills += 1
	p.gain_xp(m.xp, Data.DIFF[world.diff]["xpMult"])
	var g := Data.rnd(Data.GOLD_MIN, Data.GOLD_MAX + world.dungeon_level * 2)
	if m.boss:
		g = Data.rnd(Data.GOLD_BOSS[0], Data.GOLD_BOSS[1])
	elif m.guard:
		g *= 3
	g = Data.jround(g * (1.0 + 0.5 * p.perk("kincs")))
	p.gold += g
	var bio := 0
	var rez := 0
	if m.boss:
		bio = 8 + world.dungeon_level * 4
		rez = 8 + world.dungeon_level * 4
	elif m.mech:
		rez = Data.rnd(1, 2)
	else:
		bio = Data.rnd(1, 2)
	if m.elite or m.guard:
		rez += Data.rnd(2, 4)
	p.bio += Data.jround(bio * p.find_mult)
	p.rez += Data.jround(rez * p.find_mult)
	if p.kill_heal > 0 and p.alive and p.hp > 0 and p.hp < p.max_hp:
		p.hp = mini(p.max_hp, p.hp + p.kill_heal)
	# Vérpumpa: égő vagy vérző ellenség megölése gyógyít
	if p.has_relic("verpumpa") and (m.burn > 0 or m.bleed > 0) and p.alive and p.hp > 0 and p.hp < p.max_hp:
		p.hp = mini(p.max_hp, p.hp + 3)
		add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "+3", "col": "#50e070", "dur": 700.0, "dy": -0.35})
	# Óramű-szív: ölés után azonnal újra lehet félreugrani
	if p.has_relic("oramu"):
		p.dash_cd = 0
	# a Sebész szervet operál ki a legyőzöttből (az erősekből mindig)
	if p.cls == "Sebész" and p.organs < Data.ORGAN_MAX and (m.boss or m.mini or m.elite or randf() < Data.ORGAN_CHANCE):
		p.organs += 1
		p.add_msg(Lang.ref("msg.organ", p.organs, Data.ORGAN_MAX), "#a0f0d8")
	# a tetem: a figura összeroskad és elhalványul; a zsákmány felirata felszáll belőle
	add_fx({"type": "corpse", "key": m.key + ("#2" if m.boss and m.phase == 2 else ""), "x": m.x, "y": m.y,
		"facing": m.facing, "sd": m.seedv, "dur": 1500.0 if m.boss else 480.0, "boss": m.boss})
	add_fx({"type": "dmgnum", "x": m.x, "y": m.y, "txt": "+%d ◉" % g, "col": "#e8c060", "dur": 900.0, "delay": 180.0, "dy": 0.25})
	add_fx({"type": "puff", "x": m.x, "y": m.y, "col": "#c0a070" if m.mech else "#c04038", "dur": 520.0 if m.boss else 420.0, "big": m.boss})
	# Robbanó epe: aki egyszerre égett és mart volt, halálakor felrobban, és a szomszédait is meggyújtja
	if p.has_relic("robbano") and m.burn > 0 and m.corr > 0:
		var rob := Data.jround((10 + world.dungeon_level * 4) * Data.palya_hp(world.szakasz()))
		add_fx({"type": "boom", "x": m.x, "y": m.y, "dur": 450.0})
		add_fx({"type": "nova", "x": m.x, "y": m.y, "r": 1.8, "col": "#ffb040", "dur": 450.0})
		shake = maxf(shake, 6.0)
		play("cannon")
		for o in world.mons:
			if o.alive and absi(o.x - m.x) <= 1 and absi(o.y - m.y) <= 1:
				o.burn = Relics.BURN_TURNS
				hit_mon(o, rob, "#ffb040", 80.0)
				if o.hp <= 0:
					kill_reward(o)
	# a mini-boss ereklye-talapzatot hagy maga után
	if m.mini:
		_pedestal(m.x, m.y)
		p.bio += 5
		p.rez += 5
		shake = maxf(shake, 9.0)
		banner = {"k": "banner.mini_down", "s": "banner.mini_down.s", "col": "#80d0ff", "n": 0, "t0": now_ms.call()}
	# Tüdőspóra: halálakor méregfelhőt ereget — aki mellette áll, megmérgeződik
	if m.sp == "burst" and absi(m.x - p.x) <= 1 and absi(m.y - p.y) <= 1:
		p.poison = maxi(p.poison, 3)
		p.add_msg(Lang.ref("msg.spore_burst"), "#90c030")
		add_fx({"type": "nova", "x": m.x, "y": m.y, "r": 1.6, "col": "#b0e030", "dur": 450.0})
	if m.boss:
		_boss_fell(m)
	return g


## ereklye-talapzat a megadott mező közelébe
func _pedestal(x: int, y: int) -> void:
	var q := world.free_near(x, y)
	world.pedestals.append({"x": q.x, "y": q.y, "taken": false})
	add_fx({"type": "nova", "x": q.x, "y": q.y, "r": 1.6, "col": "#80d0ff", "dur": 700.0, "delay": 500.0})


func _boss_fell(m: Mon) -> void:
	shake = maxf(shake, 16.0)
	play("roar")
	var acc: String = Story.zone(world.dungeon_level)["acc"]
	# a halál-jelenet: robbanások sora a test körül, a végén nagy fénygyűrű és villanás
	for i in 7:
		var ax := m.x + Data.rnd(-1, 1)
		var ay := m.y + Data.rnd(-1, 1)
		add_fx({"type": "boom", "x": ax, "y": ay, "dur": 380.0, "delay": i * 170.0})
		add_fx({"type": "puff", "x": ax, "y": ay, "col": acc, "dur": 420.0, "delay": i * 170.0, "big": i % 2 == 0})
	add_fx({"type": "nova", "x": m.x, "y": m.y, "r": 5.0, "col": acc, "dur": 1000.0, "delay": 1200.0})
	add_fx({"type": "nova", "x": m.x, "y": m.y, "r": 3.0, "col": "#ffffff", "dur": 700.0, "delay": 1250.0})
	flash = {"col": "#ffffff", "t0": float(now_ms.call()) + 1200.0, "dur": 600.0}
	focus = {"x": m.x, "y": m.y, "t0": now_ms.call(), "dur": 2200.0}
	# a lejárat megnyílik: fény a lépcsőn
	var st := Dungeon.center(world.rooms[world.rooms.size() - 1])
	add_fx({"type": "nova", "x": st.x, "y": st.y, "r": 2.0, "col": acc, "dur": 900.0, "delay": 1700.0})
	if world.dungeon_level < Data.MAX_LEVEL:
		_pedestal(m.x, m.y)
	add_fx({"type": "nova", "x": m.x, "y": m.y, "r": 4.0, "col": acc, "dur": 900.0})
	world.hazards.clear()
	Meta.boss_down(m.key)
	pending_dialog = Story.talk(m.key, "win")
	banner = {"k": "banner.boss_down", "s": "banner.boss_down.s" if world.dungeon_level < Data.MAX_LEVEL else "banner.core_open",
		"col": Data.P["parchGold"], "n": 0, "t0": now_ms.call()}


func kill_check(m: Mon, dmg: int, hit_msg: String, hit_col: String) -> void:
	var p := player
	if m.hp <= 0:
		var g := kill_reward(m)
		p.add_msg(Lang.ref("msg.killed", m.ref(), m.xp, g), Data.P["parchGold"])
		if m.boss:
			p.add_msg(Lang.ref("msg.boss"), Data.P["legendary"])
	else:
		p.add_msg(Lang.ref(hit_msg, m.ref(), dmg), hit_col)
		play("growl")


func p_attack(m: Mon) -> int:
	var p := player
	# Láncfogazású Szike: a megkeményedett húst is átfűrészeli — a védelem csak félig számít
	var mdef := Game.mdef(m)
	if p.weapon and p.weapon.name == "chain_scalpel":
		mdef = int(floorf(mdef / 2.0))
	# közelharc: a lovag erős, az íjász és a mágus gyengébb közelről
	var mult := hit_mult()
	var dmg := maxi(1, Data.jround(calc_dmg(p.atk, mdef) * float(Data.MELEE_MULT.get(p.cls, 1.0)) * mult))
	hit_mon(m, dmg, "#ffd060", 0.0, mult > 1.0)
	on_hit(m, dmg, true)
	add_fx({"type": "slash", "x": m.x, "y": m.y, "dur": 250.0})
	play("sword")
	shake = maxf(shake, 2.0)
	p.lunge = 1.0
	p.lunge_dx = m.x - p.x
	p.lunge_dy = m.y - p.y
	apply_lifesteal(dmg)
	# Pajzsdöfés (lovag képesség): esély egy környi kábításra
	if m.hp > 0 and p.perk("dofes") > 0 and randf() < 0.25 * p.perk("dofes"):
		m.stun = 1
		p.add_msg(Lang.ref("msg.stun", m.ref()), "#80a8e0")
	kill_check(m, dmg, "msg.hit", "#e0a040")
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
		var big := false
		if mage:
			dmg = magic_dmg(p.mag, m)
			col = "#8cc4ff"
			var fl := 120.0 + d * 45.0
			add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 0.7, "col": "#8cc4ff", "dur": 240.0})
			add_fx({"type": "orb", "x0": p.x, "y0": p.y, "x1": m.x, "y1": m.y, "dur": fl})
			add_fx({"type": "mburst", "x": m.x, "y": m.y, "dur": 420.0, "delay": fl})
			play("magic")
		else:
			dmg = calc_dmg(p.atk, mdef(m))
			# a lövés visszarúg: a hős egy pillanatra hátrahőköl
			p.lunge = 0.7
			p.lunge_dx = -dx
			p.lunge_dy = -dy
			add_fx({"type": "puff", "x": m.x, "y": m.y, "col": "#fff0c0", "dur": 260.0, "delay": 180.0})
			if p.cls == "Íjász" and wep.subtype == "bow" and randf() < p.crit_chance:
				dmg = int(floorf(dmg * 2.2))
				big = true
				p.add_msg(Lang.ref("msg.crit"), Data.P["parchGold"])
			var is_cannon := wep.subtype == "cannon"
			add_fx({"type": "ball" if is_cannon else "arrow", "x0": p.x, "y0": p.y, "x1": m.x, "y1": m.y, "dur": 300.0 if is_cannon else 200.0})
			if is_cannon:
				play("cannon")
				add_fx({"type": "boom", "x": m.x, "y": m.y, "dur": 350.0})
				shake = maxf(shake, 3.0)
				# Gőzsugár-Karbély: minden lövés megperzseli a használó karját
				if wep.name == "steam_carbine" and p.hp > 1:
					p.hp -= 1
					add_fx({"type": "puff", "x": p.x, "y": p.y, "col": "#ffe0b0", "dur": 300.0})
			else:
				play("shoot")
		var szorzo := hit_mult()
		if szorzo > 1.0:
			dmg = Data.jround(dmg * szorzo)
			big = true
		hit_mon(m, dmg, col, (120.0 + d * 45.0) if mage else 0.0, big)
		on_hit(m, dmg)
		if dx != 0:
			p.facing = dx
		apply_lifesteal(dmg)
		kill_check(m, dmg, ("msg.orb_hit" if mage else "msg.shot_hit"), ("#8cc4ff" if mage else "#e0a040"))
		total += dmg
		# "Átütő gömb": a mágus gömbje eséllyel továbbrepül a célponton
		if mage and p.perk("atuto") > 0 and randf() < 0.2 * p.perk("atuto") and d < rng:
			p.add_msg(Lang.ref("msg.pierce"), "#a0d0ff")
			continue
		advance_turn()
		return total
	if total > 0:
		advance_turn()
	return total


# ══════════ AKTÍV KÉPESSÉGEK ══════════
## Félreugrás: néhány mező az utolsó irányba, kör nélkül — ezzel lehet kitérni az előre
## jelzett csapások elől. A Réz-Idegfonat megduplázza a távot.
func dash() -> bool:
	var p := player
	var w := world
	if not p.alive or p.stun > 0:
		return false
	if p.dash_cd > 0:
		p.add_msg(Lang.ref("msg.not_ready", p.dash_cd), Data.P["inkDark"])
		return false
	if p.rooted > 0:
		p.add_msg(Lang.ref("msg.rooted"), "#70d060")
		return false
	var nx := p.x
	var ny := p.y
	for i in p.dash_len:
		var tx := nx + p.dir_x
		var ty := ny + p.dir_y
		if w.blocked(tx, ty) or w.mon_at(tx, ty) != null or w.chest_at(tx, ty) != null:
			break
		nx = tx
		ny = ty
	if nx == p.x and ny == p.y:
		p.add_msg(Lang.ref("msg.dash_blocked"), Data.P["inkDark"])
		return false
	add_fx({"type": "trail", "x0": p.x, "y0": p.y, "x1": nx, "y1": ny, "col": p.col, "dur": 320.0})
	p.x = nx
	p.y = ny
	p.steps += 1
	p.dash_cd = p.dash_cd_max
	if p.has_relic("gozkopeny"):
		p.steam_charge = true   # a következő ütés duplán sebez
	w.update_fov()
	play("dash")
	_land(nx, ny)
	_meet_boss()
	return true


## A kaszt aktív képessége (Q). true, ha elsült (egy kört vesz igénybe).
func skill() -> bool:
	var p := player
	var w := world
	if not p.alive or p.stun > 0:
		return false
	if p.skill_cd > 0:
		p.add_msg(Lang.ref("msg.not_ready", p.skill_cd), Data.P["inkDark"])
		return false
	var mult := (1.0 + 0.3 * p.perk("tulhevites")) * hit_mult()
	var targets: Array[Mon] = []
	var col: String = Data.SKILL_COL[p.cls]
	match p.cls:
		"Sebész":
			# Beültetés: egy kioperált szervet magába varr — gyógyul és erősödik.
			# Szerv nélkül Metszés: az előtte álló ellenségen mély, vérző sebet ejt.
			if p.organs > 0:
				p.organs -= 1
				var gy := maxi(1, int(ceilf(p.max_hp * 0.35)))
				p.hp = mini(p.max_hp, p.hp + gy)
				p.base_atk += 1
				add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 1.4, "col": col, "dur": 520.0})
				add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "+%d" % gy, "col": "#50e070", "dur": 800.0, "big": true})
				play("chest")
				p.add_msg(Lang.ref("msg.implant", gy), col)
				p.skill_cd = p.skill_cd_max
				advance_turn()
				return true
			var cel := w.mon_at(p.x + p.dir_x, p.y + p.dir_y)
			if cel == null:
				for m in w.mons:
					if m.alive and absi(m.x - p.x) <= 1 and absi(m.y - p.y) <= 1:
						cel = m
						break
			if cel == null:
				p.add_msg(Lang.ref("msg.no_target"), Data.P["inkDark"])
				return false
			targets.append(cel)
			add_fx({"type": "slash", "x": cel.x, "y": cel.y, "dur": 300.0})
			play("sword")
			var ds := maxi(1, Data.jround(calc_dmg(p.atk, mdef(cel)) * 2.0 * mult))
			hit_mon(cel, ds, col, 0.0, true)
			cel.bleed = Data.BLEED_MAX
			on_hit(cel, ds, true)
			kill_check(cel, ds, "msg.hit", "#e0a040")
		"Lovag":
			# Forgószél: minden szomszédos ellenséget megvág, és egy körre elkábít
			for m in w.mons:
				if m.alive and absi(m.x - p.x) <= 1 and absi(m.y - p.y) <= 1:
					targets.append(m)
			if targets.is_empty():
				p.add_msg(Lang.ref("msg.no_target"), Data.P["inkDark"])
				return false
			add_fx({"type": "spin", "x": p.x, "y": p.y, "dur": 380.0})
			play("sword")
			for m in targets:
				var d := maxi(1, Data.jround(calc_dmg(p.atk, mdef(m)) * float(Data.MELEE_MULT["Lovag"]) * 1.5 * mult))
				hit_mon(m, d, col, 0.0, true)
				on_hit(m, d, true)
				m.stun = maxi(m.stun, 1)
				apply_lifesteal(d)
				kill_check(m, d, "msg.hit", "#e0a040")
		"Mágus":
			# Gőzrobbanás: varázssebzés mindenkinek két mezőn belül
			for m in w.mons:
				if m.alive and absi(m.x - p.x) <= 2 and absi(m.y - p.y) <= 2 and w.is_vis(m.x, m.y):
					targets.append(m)
			if targets.is_empty():
				p.add_msg(Lang.ref("msg.no_target"), Data.P["inkDark"])
				return false
			add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 2.6, "col": col, "dur": 480.0})
			play("magic")
			for m in targets:
				var d := maxi(1, Data.jround(magic_dmg(p.mag, m) * 1.5 * mult))
				hit_mon(m, d, col, 120.0, true)
				on_hit(m, d)
				apply_lifesteal(d)
				kill_check(m, d, "msg.orb_hit", "#8cc4ff")
		"Íjász":
			# Nyílzápor: a vonalban álló összes ellenségen átüt
			var rng := maxi(4, ranged_range() + 1)
			var ex := p.x
			var ey := p.y
			for i in range(1, rng + 1):
				var tx := p.x + p.dir_x * i
				var ty := p.y + p.dir_y * i
				if w.blocked(tx, ty):
					break
				ex = tx
				ey = ty
				var m := w.mon_at(tx, ty)
				if m != null:
					targets.append(m)
			if targets.is_empty():
				p.add_msg(Lang.ref("msg.no_target"), Data.P["inkDark"])
				return false
			for k in 3:
				add_fx({"type": "arrow", "x0": p.x, "y0": p.y, "x1": ex, "y1": ey, "dur": 220.0, "delay": k * 60.0})
			play("shoot")
			for m in targets:
				var d := maxi(1, Data.jround(calc_dmg(p.atk, mdef(m)) * 1.8 * mult))
				hit_mon(m, d, col, 80.0, true)
				on_hit(m, d)
				apply_lifesteal(d)
				kill_check(m, d, "msg.shot_hit", "#e0a040")
	shake = maxf(shake, 5.0)
	p.add_msg(Lang.ref("msg.skill", Lang.ref("ab." + str(Data.SKILL[p.cls])), targets.size()), col)
	p.skill_cd = p.skill_cd_max
	advance_turn()
	return true


## Gyors-ital (E): a táska leggyengébb gyógyitala, amely még nem megy kárba.
func quick_heal() -> bool:
	var p := player
	if not p.alive:
		return false
	var best: Item = null
	for it in p.inventory:
		if it.subtype == "heal" and (best == null or it.heal < best.heal):
			best = it
	if best == null:
		p.add_msg(Lang.ref("msg.no_potion"), Data.P["inkDark"])
		return false
	return use_item(best)


# ══════════ VESZÉLYZÓNÁK ══════════
## Egy előre jelzett csapás: a mező egy kör múlva "robban". A hősnek egy lépése (vagy egy
## félreugrása) van kitérni. A falakra nem kerül.
## `mind`: a szörnyeket is eléri (a pályaelemek csapásai ilyenek; a főellenségeké nem).
func warn(x: int, y: int, kind: String, dmg: int, mind := false) -> void:
	var w := world
	if w.blocked(x, y):
		return
	for h in w.hazards:
		if h["x"] == x and h["y"] == y and h["warn"]:
			return
	w.hazards.append({"x": x, "y": y, "kind": kind, "ttl": 1, "dmg": dmg, "warn": true, "mind": mind})


func acid_pool(x: int, y: int, ttl: int, dmg: int) -> void:
	var w := world
	if w.blocked(x, y) or w.tile(x, y) == Data.STAIR or w.hazard_at(x, y, "acid") != null:
		return
	w.hazards.append({"x": x, "y": y, "kind": "acid", "ttl": ttl, "dmg": dmg, "warn": false, "mind": false})


func _tick_hazards() -> void:
	var w := world
	var p := player
	if w.hazards.is_empty():
		return
	var maradt: Array = []
	var boomed := false
	for h in w.hazards:
		h["ttl"] = int(h["ttl"]) - 1
		if h["warn"]:
			if int(h["ttl"]) > 0:
				maradt.append(h)
				continue
			var kind := str(h["kind"])
			var mind: bool = h.get("mind", false)
			# a pályaelemek távoli, nem látott kitörése néma (különben folyton sziszegne a pálya)
			if not mind or w.is_vis(h["x"], h["y"]):
				boomed = true
			add_fx({"type": "burst", "x": h["x"], "y": h["y"], "col": Data.HAZ_COL.get(kind, "#ffffff"), "kind": kind, "dur": 420.0})
			if h["x"] == p.x and h["y"] == p.y and p.alive:
				var d := maxi(1, int(h["dmg"]) - int(floorf(p.def / 3.0)))
				hurt(d, true)
				add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % d, "col": "#ff5040", "dur": 800.0, "big": true})
				p.add_msg(Lang.ref("msg.haz." + kind, d), Data.P["vein"])
				if kind == "root":
					p.rooted = 2
			if mind:
				_gep_talalat(h["x"], h["y"], int(h["dmg"]), kind)
		else:
			var kind2 := str(h["kind"])
			if h["x"] == p.x and h["y"] == p.y and p.alive:
				var d2 := int(h["dmg"])
				hurt(d2)
				add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % d2, "col": "#b0e030", "dur": 700.0})
				p.add_msg(Lang.ref("msg.haz." + kind2, d2), str(Data.HAZ_COL.get(kind2, "#b0e030")))
				if kind2 == "spora":
					p.poison = maxi(p.poison, 2)   # a spórafelhő mérgez is
			if h.get("mind", false):
				_gep_talalat(h["x"], h["y"], int(h["dmg"]), kind2)
			if int(h["ttl"]) > 0:
				maradt.append(h)
	w.hazards = maradt
	if boomed:
		play("steam")
	check_death()


# ══════════ FŐELLENSÉGEK ══════════
## Az első találkozás: párbeszéd és név-felirat. (A hős látja meg, vagy a szörny őt.)
func _meet_boss() -> void:
	var b := world.boss()
	if b == null or b.met or not world.is_vis(b.x, b.y):
		return
	b.met = true
	b.awake = true
	b.cd = 2
	b.morph_ms = now_ms.call()
	focus = {"x": b.x, "y": b.y, "t0": now_ms.call(), "dur": 2600.0}   # a kamera ráúszik
	shake = maxf(shake, 8.0)
	add_fx({"type": "nova", "x": b.x, "y": b.y, "r": 3.0, "col": Story.zone(world.dungeon_level)["acc"], "dur": 800.0, "delay": 500.0})
	pending_dialog = Story.talk(b.key, "pre")
	banner = {"k": "mon." + b.key, "s": "boss." + b.key + ".s", "col": Story.zone(world.dungeon_level)["acc"], "n": 0, "t0": now_ms.call()}
	play("roar")


## A második fázis (fél életerő alatt): minden főellenség másképp vált.
func boss_phase2(m: Mon) -> void:
	var p := player
	m.phase = 2
	m.cd = 1
	m.morph_ms = now_ms.call()
	flash = {"col": "#ff4030", "t0": now_ms.call(), "dur": 500.0}
	focus = {"x": m.x, "y": m.y, "t0": now_ms.call(), "dur": 1800.0}
	for i in 3:
		add_fx({"type": "nova", "x": m.x, "y": m.y, "r": 2.0 + i * 1.4, "col": "#ff5040", "dur": 600.0, "delay": i * 160.0})
	shake = maxf(shake, 12.0)
	play("roar")
	play("fazis")
	add_fx({"type": "nova", "x": m.x, "y": m.y, "r": 3.0, "col": "#ff5040", "dur": 700.0})
	match m.sp:
		"worm":
			# leszakad a kazánlemez: sebezhetőbb, de vadabb, és savas vért fecskendez
			m.def = int(floorf(m.def / 4.0))
			m.atk = Data.jround(m.atk * 1.3)
		"karel":
			m.atk = Data.jround(m.atk * 1.15)
		"symbiote":
			m.def += 2
		"weaver":
			# Tükör-fázis: lemásolja a hős felszerelését, és az ő stílusában harcol
			m.atk = maxi(m.atk, Data.jround(maxi(p.atk, p.mag) * Data.boss_csapas("weaver", "tukor")) + 6)
			m.def = maxi(6, mini(m.def, p.def + 4))
			m.mres = maxi(2, mini(m.mres, int(p.def / 2.0)))
	p.add_msg(Lang.ref("msg.phase2." + m.sp, m.ref()), "#ff8060")
	var mid := Story.talk(m.key, "mid")
	if not mid.is_empty():
		pending_dialog = mid
	banner = {"k": "banner.phase2", "s": "boss." + m.key + ".p2", "col": "#ff6050", "n": 0, "t0": now_ms.call()}


func _dist(m: Mon) -> int:
	return maxi(absi(player.x - m.x), absi(player.y - m.y))


## Gőzsugár / pengesor: egyenes vonal a szörnytől a hős felé (a fő tengely mentén).
func _warn_line(m: Mon, hossz: int, kind: String, dmg: int) -> void:
	var p := player
	var dx := 0
	var dy := 0
	if absi(p.x - m.x) >= absi(p.y - m.y):
		dx = 1 if p.x > m.x else -1
	else:
		dy = 1 if p.y > m.y else -1
	for i in range(1, hossz + 1):
		var tx := m.x + dx * i
		var ty := m.y + dy * i
		if world.blocked(tx, ty):
			break
		warn(tx, ty, kind, dmg)
	# a hős sora/oszlopa is veszélyes, ha épp nem egy vonalban áll: a sugár "söpör"
	warn(p.x, p.y, kind, dmg)


## A hős mezője és néhány véletlen szomszédja.
func _warn_around(n: int, kind: String, dmg: int) -> void:
	var p := player
	warn(p.x, p.y, kind, dmg)
	var spots: Array = []
	for ax in range(-1, 2):
		for ay in range(-1, 2):
			if ax != 0 or ay != 0:
				spots.append(Vector2i(p.x + ax, p.y + ay))
	spots.shuffle()
	for i in mini(n, spots.size()):
		warn(spots[i].x, spots[i].y, kind, dmg)


## Egy főellenség köre. A különleges csapások lehűlésre mennek (m.cd), közben úgy lép és
## üt, mint bármelyik szörny.
func boss_turn(m: Mon) -> void:
	var p := player
	var w := world
	var dist := _dist(m)
	if m.cd > 0:
		m.cd -= 1
	# a csapások ereje főellenségenként a Data.BOSS_CSAPAS táblában áll
	match m.sp:
		"worm":
			if m.cd == 0 and dist <= 7 and dist > 1:
				_warn_line(m, 7, "steam", int(Data.boss_csapas("worm", "goz")))
				m.cd = 3 if m.phase == 1 else 2
				play("warn")
				p.add_msg(Lang.ref("msg.boss.steam", m.ref()), "#ffe0b0")
				return
			if m.phase == 2 and randf() < 0.4:
				for i in 3:
					acid_pool(p.x + Data.rnd(-2, 2), p.y + Data.rnd(-2, 2), 5, int(Data.boss_csapas("worm", "sav")))
			_mon_act(m)
			if m.phase == 2 and _dist(m) > 1:
				_mon_act(m)   # a páncél nélkül kétszer olyan gyorsan csapódik
		"karel":
			if m.cd == 0 and dist <= 6:
				_warn_around(2 if m.phase == 1 else 4, "blade", int(Data.boss_csapas("karel", "penge")))
				m.cd = 2
				play("warn")
				p.add_msg(Lang.ref("msg.boss.blade", m.ref()), "#e0e8f0")
			elif dist <= 3 and p.stun == 0 and randf() < 0.14:
				p.stun = 1
				add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 1.4, "col": "#c8f0e8", "dur": 500.0})
				p.add_msg(Lang.ref("msg.boss.gas"), "#c8f0e8")
			# 2. fázis: a transzfúziós gépekre csatlakozva szívja a hős életerejét
			if m.phase == 2 and dist <= 5 and w.turn % 2 == 0:
				var d := int(Data.boss_csapas("karel", "szivas"))
				hurt(d)
				m.hp = mini(m.max_hp, m.hp + d * 2)
				add_fx({"type": "drain", "x0": p.x, "y0": p.y, "x1": m.x, "y1": m.y, "dur": 450.0})
				add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % d, "col": "#d03030", "dur": 700.0})
				p.add_msg(Lang.ref("msg.boss.drain", m.ref(), d), Data.P["vein"])
				check_death()
			if dist <= 1:
				mon_attack(m)
			elif dist > 3:
				_mon_act(m)   # lebegve közelít, de nem megy bele a kardba
		"symbiote":
			# gyökerekkel a mennyezethez nőtt: nem mozdul
			if m.phase == 2 and m.hp < m.max_hp:
				m.hp = mini(m.max_hp, m.hp + int(Data.boss_csapas("symbiote", "gyogyul")))
			if m.cd == 0 and dist <= 9:
				_warn_around(3 if m.phase == 1 else 6, "root", int(Data.boss_csapas("symbiote", "gyoker")))
				m.cd = 3 if m.phase == 1 else 2
				play("warn")
				p.add_msg(Lang.ref("msg.boss.root", m.ref()), "#70d060")
			elif randf() < (0.12 if m.phase == 1 else 0.2):
				var spores := 0
				for mm in w.mons:
					if mm.alive and mm.key == "spore" and _dist(mm) <= 10:
						spores += 1
				var sx := m.x + Data.rnd(-2, 2)
				var sy := m.y + Data.rnd(-2, 2)
				if spores < 4 and not w.blocked(sx, sy) and w.mon_at(sx, sy) == null and not (sx == p.x and sy == p.y):
					var sm := w.erosit(Mon.make("spore", sx, sy, w.diff))
					sm.awake = true
					w.mons.append(sm)
					add_fx({"type": "puff", "x": sx, "y": sy, "col": "#d8e860", "dur": 400.0})
					p.add_msg(Lang.ref("msg.summon", m.ref()), Data.P["vein"])
			if dist <= 1:
				mon_attack(m)
		"weaver":
			if m.phase == 1:
				# a korábbi zónák urainak csapásait keveri: gőz, szikék, gyökerek
				if m.cd == 0 and dist <= 8:
					match int(w.turn / 2.0) % 3:
						0: _warn_line(m, 8, "steam", int(Data.boss_csapas("weaver", "goz")))
						1: _warn_around(4, "blade", int(Data.boss_csapas("weaver", "penge")))
						_: _warn_around(5, "root", int(Data.boss_csapas("weaver", "gyoker")))
					m.cd = 2
					play("warn")
					p.add_msg(Lang.ref("msg.boss.weave", m.ref()), "#ffd060")
					if dist <= 1:
						mon_attack(m)
					return
				_mon_act(m)
			else:
				# Tükör-fázis: távolsági hős ellen lő, közelharcos ellen ráront
				var ranged := p.cls != "Lovag"
				var aligned := (p.x == m.x or p.y == m.y) and dist <= 5 and dist > 1 and w.is_vis(m.x, m.y)
				if ranged and aligned:
					var d := calc_dmg(m.atk, p.def)
					add_fx({"type": "orb" if p.cls == "Mágus" else "arrow", "x0": m.x, "y0": m.y, "x1": p.x, "y1": p.y, "dur": 220.0})
					hurt(d, true)
					add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % d, "col": "#ff5040", "dur": 700.0, "delay": 200.0})
					p.add_msg(Lang.ref("msg.boss.mirror", m.ref(), d), Data.P["vein"])
					check_death()
				else:
					_mon_act(m)
					if _dist(m) > 1:
						_mon_act(m)
				if m.cd == 0 and dist <= 8:
					_warn_around(3, "blade", int(Data.boss_csapas("weaver", "penge")))
					m.cd = 3
					play("warn")
		_:
			_mon_act(m)


# ══════════ KÖRÖK ══════════
## Egy közönséges szörny lépése: a hős felé megy, és ha odaér, üt.
func _mon_act(m: Mon) -> bool:
	var p := player
	var w := world
	var dx := 0 if p.x == m.x else (1 if p.x > m.x else -1)
	var dy := 0 if p.y == m.y else (1 if p.y > m.y else -1)
	if dx != 0:
		m.facing = dx
	var nx := m.x + dx
	var ny := m.y + dy
	if nx == p.x and ny == p.y:
		mon_attack(m)
		return true
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
			return true
		if not w.blocked(lx, ly) and w.mon_at(lx, ly) == null:
			m.x = lx
			m.y = ly
			break
	return false


## Távolsági szörny lövése: gyengébb az ütésnél, de messziről jön. A Húsvirág köpete mérgez is.
func _mon_shot(m: Mon) -> void:
	var p := player
	var dmg := maxi(1, Data.jround(calc_dmg(m.atk, p.def) * 0.8))
	if p.x != m.x:
		m.facing = 1 if p.x > m.x else -1
	add_fx({"type": "orb" if m.sp == "ranged" else "ball", "x0": m.x, "y0": m.y, "x1": p.x, "y1": p.y, "dur": 240.0})
	hurt(dmg)
	add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % dmg, "col": "#ff5040", "dur": 700.0, "delay": 220.0})
	p.add_msg(Lang.ref("msg.shot_in", m.ref(), dmg), Data.P["vein"])
	if m.sp == "spit" and randf() < 0.45:
		p.poison = maxi(p.poison, 3)
		p.add_msg(Lang.ref("msg.poisoned"), "#90c030")
	play("shoot" if m.sp == "ranged" else "growl")
	check_death()


## Automata-ápoló: a közelben megsebzett társát foltozza be (a saját lépése helyett).
func _mend(m: Mon) -> bool:
	for o in world.mons:
		if o == m or not o.alive or o.boss or o.hp >= o.max_hp:
			continue
		if absi(o.x - m.x) <= 3 and absi(o.y - m.y) <= 3:
			var h := maxi(2, int(floorf(o.max_hp * 0.25)))
			o.hp = mini(o.max_hp, o.hp + h)
			add_fx({"type": "dmgnum", "x": o.x, "y": o.y, "txt": "+%d" % h, "col": "#50e070", "dur": 700.0})
			add_fx({"type": "drain", "x0": m.x, "y0": m.y, "x1": o.x, "y1": o.y, "dur": 350.0, "col": "#50e070"})
			return true
	return false


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
	if p.dash_cd > 0:
		p.dash_cd -= 1
	if p.skill_cd > 0:
		p.skill_cd -= 1
	if p.rooted > 0:
		p.rooted -= 1
	if not idle:
		if p.poison > 0:
			p.poison -= 1
			var d := Data.rnd(2, 5)
			p.hp = maxi(1, p.hp - d)
			p.add_msg(Lang.ref("msg.poison_tick", d) if p.poison > 0 else Lang.ref("msg.poison_end"), "#90c030")
		# regeneráció (nagyon ritka / legendás páncél és pajzs)
		var rg := p.regen
		if rg > 0 and p.alive and p.hp > 0 and p.hp < p.max_hp:
			p.hp = mini(p.max_hp, p.hp + rg)
		spot_hidden()
	_tick_status()
	_tick_hazards()
	_tick_vents()   # a hazárdok UTÁN: a rács jelzése így egy teljes körig látszik, mielőtt kitör
	_tick_gepek()   # ugyanezért: a zóna gépei is a kitörések után jeleznek
	_meet_boss()
	# a közeli, látható szörnyek helye a kör előtt: aki elmozdul, az hangot adhat
	var elotte := {}
	for m in w.mons:
		if m.alive and absi(m.x - p.x) <= Data.SZORNYHANG_TAV and absi(m.y - p.y) <= Data.SZORNYHANG_TAV:
			elotte[m] = Vector2i(m.x, m.y)
	var felfigyelt := 0
	for m in w.mons:
		if not m.alive or not p.alive:
			continue
		# az első alkalom, amikor a szörny meglátja a hőst: felkiáltójel és rövid hang
		if not m.eszlelt and w.is_vis(m.x, m.y):
			m.eszlelt = true
			if not m.boss:
				add_fx({"type": "dmgnum", "x": m.x, "y": m.y, "txt": "!", "col": "#ffd040", "dur": 750.0, "dy": -0.45, "big": true})
				if felfigyelt == 0:
					play("eszlel", _tav_hangero(m))
				felfigyelt += 1
		if m.stun > 0:
			m.stun -= 1
			continue
		if not w.is_exp(m.x, m.y) and not m.awake:
			continue
		if m.boss and m.sp != "" and (m.met or m.awake):
			boss_turn(m)
		elif m.mini and (w.is_vis(m.x, m.y) or m.awake):
			# mini-boss: a zóna csapását szórja a hős köré, közben üldöz
			m.awake = true
			if m.cd > 0:
				m.cd -= 1
			if m.cd == 0 and _dist(m) <= 6 and _dist(m) > 1:
				_warn_around(2, str(Data.VENT_KIND.get(w.dungeon_level, "steam")), 6 + w.dungeon_level * 2 + Data.palya_csapas(w.szakasz()))
				m.cd = 4
				play("warn")
			_mon_act(m)
		elif w.is_vis(m.x, m.y) or m.awake:
			if m.sp == "mend" and randf() < 0.35 and _mend(m):
				continue
			# távolsági szörnyek: a Szerelődrón egy vonalból lő, a Húsvirág helyből köp (és sosem lép)
			if m.sp == "ranged" or m.sp == "spit":
				var tav := _dist(m)
				var vonal := p.x == m.x or p.y == m.y or absi(p.x - m.x) == absi(p.y - m.y)
				if tav > 1 and w.is_vis(m.x, m.y) and ((m.sp == "ranged" and tav <= 4 and vonal) or (m.sp == "spit" and tav <= 3)):
					_mon_shot(m)
					continue
				if m.sp == "spit":
					if tav <= 1:
						mon_attack(m)
					continue
			var hit := _mon_act(m)
			# a fürge lények (Gőzpatkány, Lebegő szike) kettőt lépnek, de csak egyszer ütnek
			if m.sp == "swift" and not hit and m.alive and _dist(m) > 1:
				_mon_act(m)
		elif m.sp != "spit" and randf() < 0.5:
			# a nyugodt szörnyek is járkálnak: a pálya akkor is él, ha a hős áll
			var d: Vector2i = Data.pick(Dungeon.DIRS)
			if d.x != 0:
				m.facing = d.x
			var nx := m.x + d.x
			var ny := m.y + d.y
			if not w.blocked(nx, ny) and w.mon_at(nx, ny) == null and not (nx == p.x and ny == p.y):
				m.x = nx
				m.y = ny
	_szornyhangok(elotte)


## a távolsággal halkuló hangerő (szomszédos mezőn 1, a hallótáv szélén 0.2)
func _tav_hangero(m: Mon) -> float:
	return clampf(1.0 - float(_dist(m) - 1) / float(Data.SZORNYHANG_TAV) * 0.9, 0.2, 1.0)


## A most elmozdult, LÁTHATÓ szörnyek hangja: a legközelebbiek szólnak, fajtánként (gépi,
## húsos, lebegő, kúszó) más hanggal, távolsággal halkulva — körönként legfeljebb
## SZORNYHANG_MAX darab, és egy fajta csak egyszer, hogy sok szörny mellett se legyen hangzavar.
## `elotte`: szörny -> a kör előtti helye. Visszaadja, hány hang szólt.
func _szornyhangok(elotte: Dictionary) -> int:
	if not sfx.is_valid() or elotte.is_empty() or not player.alive:
		return 0
	var w := world
	var jeloltek: Array[Mon] = []
	for m: Mon in elotte:
		var h: Vector2i = elotte[m]
		if m.alive and (m.x != h.x or m.y != h.y) and w.is_vis(m.x, m.y) and _dist(m) <= Data.SZORNYHANG_TAV:
			jeloltek.append(m)
	jeloltek.sort_custom(func(a: Mon, b: Mon) -> bool: return _dist(a) < _dist(b))
	var szolt := {}
	for m in jeloltek:
		if szolt.size() >= Data.SZORNYHANG_MAX:
			break
		var fajta := str(Data.MON_HANG.get(m.key, "hus"))
		if szolt.has(fajta) or _hang_rng.randf() > Data.SZORNYHANG_ESELY:
			continue
		szolt[fajta] = true
		play(fajta, _tav_hangero(m) * 0.8)
	return szolt.size()


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
			p.add_msg(Lang.ref("msg.spot", Lang.ref("trap." + str(t["type"]))), "#e0c060")
	for s in w.secrets:
		if s["found"] or absi(s["x"] - p.x) > 1 or absi(s["y"] - p.y) > 1:
			continue
		if randf() < pc * 0.6:
			w.open_secret(s)
			play("chest")
			p.add_msg(Lang.ref("msg.secret_open"), Data.P["parchGold"])


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
			p.add_msg(Lang.ref("msg.search_trap", Lang.ref("trap." + str(t["type"]))), "#e0c060")
	for s in w.secrets:
		if not s["found"] and absi(s["x"] - p.x) <= 1 and absi(s["y"] - p.y) <= 1 and randf() < pc:
			w.open_secret(s)
			found += 1
			play("chest")
			p.add_msg(Lang.ref("msg.secret_found"), Data.P["parchGold"])
	if found == 0:
		p.add_msg(Lang.ref("msg.search_none"), Data.P["inkDark"])
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
			hurt(d)
			p.add_msg(Lang.ref("msg.spike", d), Data.P["vein"])
			add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "-%d" % d, "col": "#ff5040", "dur": 700.0})
			play("hit")
		"mereg":
			var d2 := maxi(2, Data.jround(p.max_hp * Data.TRAP_DMG_MIN * 0.6))
			hurt(d2)
			p.poison = maxi(p.poison, 5)
			p.add_msg(Lang.ref("msg.poison_trap", d2), "#90c030")
			add_fx({"type": "boom", "x": p.x, "y": p.y, "dur": 400.0})
			play("hit")
		"riaszto":
			var n := 0
			for m in world.mons:
				if m.alive and not m.awake and absi(m.x - p.x) <= Data.ALARM_R and absi(m.y - p.y) <= Data.ALARM_R:
					m.awake = true
					n += 1
			p.add_msg(Lang.ref("msg.alarm", n), "#e0a030")
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
	add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 1.8, "col": Data.SHRINES[s["kind"]]["col"], "dur": 600.0})
	match s["kind"]:
		"gyogyulas":
			p.hp = p.max_hp
			p.add_msg(Lang.ref("msg.shrine.gyogyulas", Lang.ref("shrine.gyogyulas")), "#50d080")
		"elet":
			p.lives += 1
			p.add_msg(Lang.ref("msg.shrine.elet", Lang.ref("shrine.elet")), "#e06080")
		"vedelem":
			p.base_def += 2
			p.add_msg(Lang.ref("msg.shrine.vedelem", Lang.ref("shrine.vedelem")), "#5080e0")
		"varazs":
			p.base_mag += 3
			p.add_msg(Lang.ref("msg.shrine.varazs", Lang.ref("shrine.varazs")), "#8cc4ff")
	return true


## Feljegyzés a padlón: a Napló egy lapja (az új lap egy kevés Bio-Hulladékot is ér).
func take_note() -> bool:
	var p := player
	var n: Variant = world.note_at(p.x, p.y)
	if n == null:
		return false
	n["taken"] = true
	pending_note = str(n["id"])
	play("note")
	if Meta.add_note(pending_note):
		p.bio += 3
		p.add_msg(Lang.ref("msg.note_new", Lang.ref("note." + pending_note)), Data.P["parchGold"])
	else:
		p.add_msg(Lang.ref("msg.note_old", Lang.ref("note." + pending_note)), Data.P["ink"])
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
		p.add_msg(Lang.ref("msg.poor", price), Data.P["vein"])
		return false
	p.gold -= price
	s["sold"] = true
	play("chest")
	if s["kind"] == "heal":
		p.hp = p.max_hp
		p.add_msg(Lang.ref("msg.bought_heal", price), "#40c860")
	else:
		var it: Item = s["item"]
		p.inventory.append(it)
		p.add_msg(Lang.ref("msg.bought_item", price, it.ref()), it.glow())
	return true


## Padlórácsok: szabályos ütemben kitör belőlük a zóna csapása (csak a hős közelében számolunk).
func _tick_vents() -> void:
	var w := world
	if w.vents.is_empty():
		return
	var p := player
	var kind := str(Data.VENT_KIND.get(w.dungeon_level, "steam"))
	for v in w.vents:
		if absi(v["x"] - p.x) > 9 or absi(v["y"] - p.y) > 9:
			continue
		if (w.turn + int(v["ph"])) % Data.VENT_PERIOD == Data.VENT_PERIOD - 2:
			warn(v["x"], v["y"], kind, 5 + w.dungeon_level * 2 + Data.palya_csapas(w.szakasz()))


# ══════════ A ZÓNÁK SAJÁT PÁLYAELEMEI (gépek) ÉS A REJTVÉNYSZOBA ══════════
## Egy pályaelem csapása egy szörnyet ér (a főellenséget nem). Nem ébreszti fel, de megölheti —
## a jutalma ilyenkor is a hősé, hiszen ő csalta oda.
func _gep_talalat(x: int, y: int, dmg: int, kind: String) -> void:
	var m := world.mon_at(x, y)
	if m == null or m.boss:
		return
	if kind == "spora" and m.key in Data.SPORA_IMMUNIS:
		return
	var d := maxi(1, dmg - int(floorf(mdef(m) / 3.0)))
	m.hp -= d
	var latszik := world.is_vis(x, y)
	if latszik:
		m.hit_ms = now_ms.call()
		add_fx({"type": "dmgnum", "x": x, "y": y, "txt": "-%d" % d, "col": str(Data.HAZ_COL.get(kind, "#ffffff")), "dur": 700.0})
	if m.hp <= 0:
		kill_reward(m)
		if latszik:
			player.add_msg(Lang.ref("msg.gep_olt", m.ref()), Data.P["parchGold"])


## A zóna gépeinek köre (csak a hős közelében számolunk; a zsilip, a szike és a korong állása
## a körszámból adódik, így a távoli gépek „maguktól” a helyükön lesznek, amikor odaérünk).
## Mind egy körrel előre jelez: a jelzést a szokásos veszélyzóna (warn) adja.
func _tick_gepek() -> void:
	var w := world
	if w.gepek.is_empty():
		return
	var p := player
	var em := clampi(w.emelet, 1, 4)
	for g in w.gepek:
		var gx: int = g["x"]
		var gy: int = g["y"]
		if absi(gx - p.x) > 12 or absi(gy - p.y) > 12:
			continue
		match str(g["tip"]):
			"zsilip":
				# az ütem utolsó két körében fúj: mindkettőt egy-egy körrel előbb jelzi
				var c := w.gep_fazis(g)
				var per: int = g["p"]
				if c == per - 3 or c == per - 2:
					for i in int(g["n"]):
						warn(gx + int(g["dx"]) * i, gy + int(g["dy"]) * i, "steam", Data.gep_dmg("zsilip", w.dungeon_level, em), true)
			"szike":
				# ahová a következő körben lép, az a mező most villog
				var q := w.szike_hely(g, w.turn + 1)
				warn(q.x, q.y, "blade", Data.gep_dmg("szike", w.dungeon_level, em), true)
			"gubo":
				_gubo_kor(g, em)
			"korong":
				var c2 := w.gep_fazis(g)
				var per2: int = g["p"]
				if c2 == per2 - 2:
					for d in World.GYURU:
						warn(gx + d.x, gy + d.y, "gear", Data.gep_dmg("korong", w.dungeon_level, em), true)
					if w.is_vis(gx, gy):
						play("warn")
				elif c2 == per2 - 1:
					_korong_fordul(g)


## Spóragubó: érett (0) → ha valaki mellé lép, megduzzad (1) → a következő körben kipukkad,
## és spórafelhőt hagy maga után → alszik (2), amíg újra be nem érik.
func _gubo_kor(g: Dictionary, em: int) -> void:
	var w := world
	var p := player
	var gx: int = g["x"]
	var gy: int = g["y"]
	match int(g["all"]):
		2:
			if w.turn >= int(g["t"]):
				g["all"] = 0
		1:
			g["all"] = 2
			g["t"] = w.turn + int(Data.GUBO_UJRA[em - 1])
			var dmg := Data.gep_dmg("gubo", w.dungeon_level, em)
			var mezok: Array[Vector2i] = []
			for ax in range(-1, 2):
				for ay in range(-1, 2):
					mezok.append(Vector2i(gx + ax, gy + ay))
			if int(g["n"]) >= 2:
				mezok.append_array([Vector2i(gx + 2, gy), Vector2i(gx - 2, gy), Vector2i(gx, gy + 2), Vector2i(gx, gy - 2)])
			for q in mezok:
				if w.blocked(q.x, q.y) or w.hazard_at(q.x, q.y, "spora") != null:
					continue
				w.hazards.append({"x": q.x, "y": q.y, "kind": "spora", "ttl": Data.FELHO_KOR, "dmg": dmg, "warn": false, "mind": true})
			if w.is_vis(gx, gy):
				add_fx({"type": "nova", "x": gx, "y": gy, "r": 1.8, "col": Data.HAZ_COL["spora"], "dur": 480.0})
				add_fx({"type": "puff", "x": gx, "y": gy, "col": Data.HAZ_COL["spora"], "dur": 520.0, "big": true})
				play("gubo")
		_:
			var kozel := p.alive and absi(p.x - gx) <= 1 and absi(p.y - gy) <= 1
			var hos := kozel
			if not kozel:
				for m in w.mons:
					if m.alive and absi(m.x - gx) <= 1 and absi(m.y - gy) <= 1 and not (m.key in Data.SPORA_IMMUNIS):
						kozel = true
						break
			if kozel:
				g["all"] = 1
				if w.is_vis(gx, gy):
					play("warn")
					if hos:
						p.add_msg(Lang.ref("msg.gubo"), Data.HAZ_COL["spora"])


## A forgó fogaskerék-padló negyedfordulata: aki a gyűrűjén áll (hős vagy szörny), két mezővel
## odébb kerül az óramutató járása szerint. (A fogak csípését a jelzett veszélyzóna adta.)
func _korong_fordul(g: Dictionary) -> void:
	var w := world
	var p := player
	var gx: int = g["x"]
	var gy: int = g["y"]
	var mozog: Array = []
	for i in 8:
		var honnan: Vector2i = World.GYURU[i]
		var hova: Vector2i = World.GYURU[(i + 2) % 8]
		if w.blocked(gx + hova.x, gy + hova.y):
			continue
		var m := w.mon_at(gx + honnan.x, gy + honnan.y)
		if m != null and not m.boss:
			mozog.append([m, gx + hova.x, gy + hova.y])
		if p.alive and p.x == gx + honnan.x and p.y == gy + honnan.y:
			mozog.append([null, gx + hova.x, gy + hova.y])
	var hos := false
	for e in mozog:
		if e[0] == null:
			p.x = e[1]
			p.y = e[2]
			hos = true
		else:
			var mm: Mon = e[0]
			mm.x = e[1]
			mm.y = e[2]
	if hos:
		w.update_fov()
		shake = maxf(shake, 5.0)
		p.add_msg(Lang.ref("msg.korong"), Data.HAZ_COL["gear"])
	if w.is_vis(gx, gy):
		play("gear")


## Rálépés a rejtvényszoba egy nyomólapjára (csak a hős nyomja le). A láda fölött izzó jelek
## sorrendjében kell haladni: a jó lap lenyomva marad; a rossz mindet visszaugrasztja, és a
## zóna csapása — előre jelezve — kitör a hős körül. Ha mind megvan, lehull a láda lánca.
func press_plate() -> bool:
	var w := world
	var p := player
	var lap: Variant = w.lap_at(p.x, p.y)
	if lap == null or lap["le"]:
		return false
	var lada: Variant = w.zart_lada()
	if lada == null:
		return false
	var kesz := w.lapok_le()
	var szin := str(Data.LAP_SZINEK[int(lap["jel"]) % Data.LAP_SZINEK.size()])
	if int(lap["sor"]) == kesz:
		lap["le"] = true
		add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 1.0, "col": szin, "dur": 420.0})
		if kesz + 1 >= w.lapok.size():
			lada["zart"] = false
			add_fx({"type": "nova", "x": lada["x"], "y": lada["y"], "r": 2.2, "col": Data.ROOM_KINDS["rejtveny"]["col"], "dur": 800.0})
			add_fx({"type": "puff", "x": lada["x"], "y": lada["y"], "col": Data.P["parchGold"], "dur": 520.0, "big": true})
			p.add_msg(Lang.ref("msg.rejtveny.kesz"), Data.P["parchGold"])
			play("levelup")
		else:
			p.add_msg(Lang.ref("msg.lap.jo", kesz + 1, w.lapok.size()), szin)
			play("plate")
		return true
	for l in w.lapok:
		l["le"] = false
	p.add_msg(Lang.ref("msg.lap.rossz"), Data.P["vein"])
	_warn_around(2, str(Data.VENT_KIND.get(w.dungeon_level, "steam")), 6 + w.dungeon_level * 2 + w.emelet + Data.palya_csapas(w.szakasz()))
	play("warn")
	return true


## Az ereklye-talapzat használata: a választott ereklye a hősé lesz.
func take_relic(id: String) -> bool:
	var ped: Variant = world.pedestal_at(player.x, player.y)
	if ped == null or not Relics.apply(player, id):
		return false
	ped["taken"] = true
	if player.relics.size() >= 3:
		Meta.award("ereklye3")
	play("levelup")
	add_fx({"type": "nova", "x": player.x, "y": player.y, "r": 2.0, "col": Relics.LIST[id]["col"], "dur": 700.0})
	return true


## Ha már minden ereklye megvan, a talapzat nyersanyagot ad.
func relic_fallback() -> void:
	var ped: Variant = world.pedestal_at(player.x, player.y)
	if ped == null:
		return
	ped["taken"] = true
	player.bio += 10
	player.rez += 10
	player.add_msg(Lang.ref("msg.relic_none"), "#80d0ff")


## Döntési esemény: a két válasz egyike (0 vagy 1). true, ha megtörtént.
func event_choice(e: Dictionary, i: int) -> bool:
	var p := player
	if e.get("used", true):
		return false
	e["used"] = true
	var dl := world.dungeon_level
	var kulcs := "msg.event.%s.%s" % [e["kind"], "a" if i == 0 else "b"]
	match str(e["kind"]):
		"fogoly":
			if i == 0:
				# kiszabadítod: hálából egy nagy gyógyitalt ad
				var it := Item.make(Item.find_base("greater_healing_potion"), "rare", dl)
				p.inventory.append(it)
				p.add_msg(Lang.ref(kulcs, it.ref()), "#40c860")
			else:
				# kifosztod: arany, de a kiáltása felriasztja a környéket
				var g := 20 + dl * 12
				p.gold += g
				var n := 0
				for m in world.mons:
					if m.alive and not m.awake and absi(m.x - p.x) <= Data.ALARM_R and absi(m.y - p.y) <= Data.ALARM_R:
						m.awake = true
						n += 1
				p.add_msg(Lang.ref(kulcs, g, n), "#e0a030")
				play("growl")
		"verautomata":
			if i == 0:
				# megeteted a véreddel: a maximális életerő negyedéért új képességet ad
				var ar := maxi(1, int(floorf(p.max_hp * 0.25)))
				p.hp = maxi(1, p.hp - ar)
				p.hurt_ms = now_ms.call()
				pending_perks += 1
				p.add_msg(Lang.ref(kulcs, ar), Data.P["vein"])
			else:
				var r := 6 + dl * 2
				p.rez += r
				p.add_msg(Lang.ref(kulcs, r), "#e0a060")
				play("hit")
		"mutoasztal":
			if i == 0:
				# felfekszel: többnyire megerősödsz, néha megfertőződsz
				if randf() < 0.65:
					p.max_hp += 12
					p.hp = p.max_hp
					p.add_msg(Lang.ref(kulcs, 12), "#40c860")
					play("levelup")
				else:
					p.poison = maxi(p.poison, 6)
					p.add_msg(Lang.ref("msg.event.mutoasztal.a2"), "#90c030")
					play("hit")
			else:
				var b := 8 + dl * 2
				p.bio += b
				p.add_msg(Lang.ref(kulcs, b), "#b0e060")
	add_fx({"type": "nova", "x": e["x"], "y": e["y"], "r": 1.4, "col": "#ffd870", "dur": 500.0})
	return true


## Megérkezés egy mezőre (lépés vagy félreugrás után): csapda, szentély, feljegyzés, kereskedő.
## true, ha csapda sült el.
func _land(nx: int, ny: int) -> bool:
	var trapped := trigger_trap()
	press_plate()
	trigger_shrine()
	take_note()
	var ped: Variant = world.pedestal_at(nx, ny)
	if ped != null:
		pending_relic = true
	var ev: Variant = world.event_at(nx, ny)
	if ev != null:
		pending_event = ev
	var sh: Variant = world.shop_at(nx, ny)
	if sh != null:
		pending_shop = sh
	return trapped


## Egy lépés / támadás a megadott irányba. true, ha történt valami.
func do_move(dx: int, dy: int) -> bool:
	var p := player
	var w := world
	if not p.alive:
		return false
	if dx != 0:
		p.facing = dx   # arcirány követi a mozgást
	p.dir_x = dx
	p.dir_y = dy
	# kábult (altatógáz): ez a köre kimarad
	if p.stun > 0:
		p.stun -= 1
		p.add_msg(Lang.ref("msg.stunned"), "#c8f0e8")
		advance_turn()
		return true
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
		if ch.get("zart", false):
			# a rejtvényszoba ládája: amíg a nyomólapok nincsenek sorban lenyomva, nem nyílik
			play("hit")
			p.add_msg(Lang.ref("msg.lada.zart", w.lapok_le(), w.lapok.size()), "#b890ff")
			return true
		play("chest")
		pending_chest = ch
		return true
	if not w.blocked(nx, ny):
		# gyökerek fogják: támadni tud, lépni nem — a rángatás egy körbe kerül
		if p.rooted > 0:
			p.add_msg(Lang.ref("msg.rooted"), "#70d060")
			advance_turn()
			return true
		p.x = nx
		p.y = ny
		p.steps += 1
		w.update_fov()
		play("step%d" % clampi(w.dungeon_level, 1, 4), Data.LEPES_HANGERO)   # zónánként más talajon koppan
		var trapped := _land(nx, ny)
		# "Gyors léptek" (íjász): minden 5. lépés ingyen — nem telik vele kör
		if p.perk("gyorslab") > 0 and p.steps % 5 == 0 and not trapped:
			_meet_boss()
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
	p.add_msg(Lang.ref("msg.equipped", item.ref()), c[item.slot])


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
				p.add_msg(Lang.ref("msg.full_hp"), "#c0c8d0")
				return false
			var h := maxi(0, mini(item.heal, p.max_hp - p.hp))
			p.hp += h
			p.add_msg(Lang.ref("msg.heal", h), "#40c860")
			add_fx({"type": "dmgnum", "x": p.x, "y": p.y, "txt": "+%d" % h, "col": "#50e070", "dur": 700.0})
			add_fx({"type": "nova", "x": p.x, "y": p.y, "r": 1.0, "col": "#50e070", "dur": 400.0})
			play("chest")
		"maxheal":
			# Életerő töltő: nagyobb max. életerő ÉS teljes gyógyulás
			p.max_hp += item.max_hp_up
			p.hp = p.max_hp
			p.add_msg(Lang.ref("msg.maxhp", item.max_hp_up), "#40c860")
		"fireball":
			var c := 0
			var bonus := p.mag if p.cls == "Mágus" else 0
			for m in w.mons:
				if not m.alive or not w.is_vis(m.x, m.y):
					continue
				# a szörnyek életereje pályánként szorzódik: a tekercs ereje vele tart
				var d := Data.jround((item.damage + Data.rnd(0, 15)) * Data.palya_hp(w.szakasz())) + bonus
				hit_mon(m, d, "#ff9040")
				add_fx({"type": "boom", "x": m.x, "y": m.y, "dur": 400.0})
				if m.hp <= 0:
					kill_reward(m)
					if m.boss:
						p.add_msg(Lang.ref("msg.boss"), Data.P["legendary"])
				c += 1
			p.add_msg(Lang.ref("msg.fireball", c), "#e06020")
			shake = maxf(shake, 8.0)
			play("cannon")
		"atk_up":
			if p.cls == "Mágus":
				var up := item.atk_up * 2
				p.base_mag += up
				p.add_msg(Lang.ref("msg.mag_up", up), "#8cc4ff")
			else:
				p.base_atk += item.atk_up
				p.add_msg(Lang.ref("msg.atk_up", item.atk_up), "#e05050")
		"def_up":
			var up := item.def_up + (Data.LOVAG_VED_TEKERCS if p.cls == "Lovag" else 0)
			p.base_def += up
			p.add_msg(Lang.ref("msg.def_up", up), "#5080e0")
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
	add_fx({"type": "nova", "x": chest["x"], "y": chest["y"], "r": 1.3, "col": it.glow(), "dur": 500.0})
	add_fx({"type": "puff", "x": chest["x"], "y": chest["y"], "col": Data.P["parchGold"], "dur": 480.0, "big": true})
	if it.slot == "weapon" and p.weapon == null: p.weapon = it
	elif it.slot == "armor" and p.armor == null: p.armor = it
	elif it.slot == "shield" and p.shield == null: p.shield = it
	else: p.inventory.append(it)
	p.add_msg(Lang.ref("msg.take", it.ref()), it.glow())
	return it
