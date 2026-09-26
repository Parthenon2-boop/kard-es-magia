class_name SaveGame
extends RefCounted
## Mentés és betöltés: a teljes futó kaland egyetlen JSON fájlban (`user://mentes.json`).
##
## Mentődik: a pálya (csempék, bejárt mezők, fényerő, díszek, fáklyák, ládák, csapdák,
## titkos ajtók, szentélyek, kereskedők, szörnyek), a hős (kaszt, értékek, táska, felszerelés
## a pajzshellyel együtt, képességek, életek, méreg, arany), a mélység, a nehézség és a körszám.
##
## A fájl VERZIÓ mezőt tartalmaz: régebbi vagy sérült mentés esetén a betöltés null-t ad vissza,
## és a főmenüben nem jelenik meg a "Folytatás".

const PATH := "user://mentes.json"
const VERSION := 1

static var _exists := false
static var _checked := false


# ══════════ VAN-E MENTÉS? ══════════
## Gyors, gyorsítótárazott válasz (a főmenü minden képkockán kérdezi).
static func has_save() -> bool:
	if not _checked:
		refresh()
	return _exists


static func refresh() -> void:
	_checked = true
	_exists = false
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = _read()
	_exists = d != null


static func erase() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	_exists = false
	_checked = true


static func _read() -> Variant:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(txt) != OK:
		return null
	var d: Variant = j.data
	if not (d is Dictionary):
		return null
	if int((d as Dictionary).get("v", 0)) != VERSION:
		return null
	return d


# ══════════ TÁRGY ══════════
static func item_to(it: Item) -> Variant:
	if it == null:
		return null
	return {"name": it.name, "slot": it.slot, "subtype": it.subtype, "glyph": it.glyph,
		"rarity": it.rarity, "dmg": it.dmg, "def": it.def, "heal": it.heal, "max_hp_up": it.max_hp_up,
		"atk_up": it.atk_up, "def_up": it.def_up, "damage": it.damage, "reach": it.reach,
		"lifesteal": it.lifesteal, "regen": it.regen}


static func item_from(v: Variant) -> Item:
	if not (v is Dictionary):
		return null
	var d: Dictionary = v
	var it := Item.new()
	# a régi mentésekben a tárgy magyar neve áll: ebből lesz a belső azonosító (a "label" mezőt,
	# a régi megjelenített nevet, már nem olvassuk — a nevet a nyelvi fájl adja)
	it.name = str(d.get("name", ""))
	it.name = str(Data.LEGACY_ITEM_IDS.get(it.name, it.name))
	it.slot = str(d.get("slot", "use"))
	it.subtype = str(d.get("subtype", ""))
	it.glyph = str(d.get("glyph", "?"))
	it.rarity = str(d.get("rarity", "common"))
	if not Data.RARITY.has(it.rarity):
		it.rarity = "common"
	it.dmg = int(d.get("dmg", 0))
	it.def = int(d.get("def", 0))
	it.heal = int(d.get("heal", 0))
	it.max_hp_up = int(d.get("max_hp_up", 0))
	it.atk_up = int(d.get("atk_up", 0))
	it.def_up = int(d.get("def_up", 0))
	it.damage = int(d.get("damage", 0))
	it.reach = int(d.get("reach", 0))
	it.lifesteal = float(d.get("lifesteal", 0.0))
	it.regen = int(d.get("regen", 0))
	return it


static func _items_to(arr: Array) -> Array:
	var out: Array = []
	for it in arr:
		out.append(item_to(it))
	return out


# ══════════ MENTÉS ══════════
static func save_run(g: Game) -> bool:
	if g == null or g.world == null or g.player == null or not g.player.alive:
		return false
	var p := g.player
	var w := g.world
	var rooms: Array = []
	for r in w.rooms:
		rooms.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var kinds: Array = []
	for k in w.room_kind:
		kinds.append(k)
	var mons: Array = []
	for m in w.mons:
		mons.append({"key": m.key, "x": m.x, "y": m.y, "seedv": m.seedv, "facing": m.facing,
			"max_hp": m.max_hp, "hp": m.hp, "atk": m.atk, "def": m.def, "mres": m.mres, "xp": m.xp,
			"sp": m.sp, "boss": m.boss, "alive": m.alive, "guard": m.guard, "awake": m.awake, "stun": m.stun})
	var chests: Array = []
	for c in w.chests:
		chests.append({"x": c["x"], "y": c["y"], "opened": c["opened"], "items": _items_to(c["items"])})
	var shops: Array = []
	for s in w.shops:
		var stock: Array = []
		for e in s["stock"]:
			stock.append({"kind": e["kind"], "item": item_to(e["item"]), "price": e["price"], "sold": e["sold"]})
		shops.append({"x": s["x"], "y": s["y"], "stock": stock})
	var data := {
		"v": VERSION,
		"idő": Time.get_datetime_string_from_system(),
		"jatek": {"melyseg": w.dungeon_level, "nehezseg": w.diff, "kor": w.turn, "pending_perks": g.pending_perks},
		"hos": {"cls": p.cls, "x": p.x, "y": p.y, "col": p.col, "facing": p.facing,
			"max_hp": p.max_hp, "hp": p.hp, "base_atk": p.base_atk, "base_mag": p.base_mag, "base_def": p.base_def,
			"lives": p.lives, "xp": p.xp, "plvl": p.plvl, "xp_next": p.xp_next, "poison": p.poison,
			"gold": p.gold, "steps": p.steps, "perks": p.perks.duplicate(),
			"weapon": item_to(p.weapon), "armor": item_to(p.armor), "shield": item_to(p.shield),
			"inventory": _items_to(p.inventory), "msgs": p.msgs.duplicate(true)},
		"palya": {
			"tiles": Marshalls.raw_to_base64(w.tiles),
			"explored": Marshalls.raw_to_base64(w.explored),
			"fade": Marshalls.raw_to_base64(w.fade.to_byte_array()),
			"rooms": rooms, "room_kind": kinds,
			"mons": mons, "chests": chests, "shops": shops,
			"traps": w.traps.duplicate(true), "secrets": w.secrets.duplicate(true),
			"shrines": w.shrines.duplicate(true), "decor": w.decor.duplicate(true), "torches": w.torches.duplicate(true),
		},
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	_exists = true
	_checked = true
	return true


# ══════════ BETÖLTÉS ══════════
## null, ha nincs mentés, vagy sérült / régi a fájl.
static func load_run() -> Game:
	var raw: Variant = _read()
	if raw == null:
		return null
	var d: Dictionary = raw
	if not (d.get("hos") is Dictionary) or not (d.get("palya") is Dictionary) or not (d.get("jatek") is Dictionary):
		return null
	var hs: Dictionary = d["hos"]
	var mp: Dictionary = d["palya"]
	var jt: Dictionary = d["jatek"]
	var cls := str(hs.get("cls", "Lovag"))
	if not Data.CLASSES.has(cls):
		return null
	var n := Data.MAP_W * Data.MAP_H
	var tiles := Marshalls.base64_to_raw(str(mp.get("tiles", "")))
	var explored := Marshalls.base64_to_raw(str(mp.get("explored", "")))
	if tiles.size() != n or explored.size() != n:
		return null
	var rooms_raw: Variant = mp.get("rooms", [])
	if not (rooms_raw is Array) or (rooms_raw as Array).is_empty():
		return null

	var g := Game.new()
	var p := Player.create(cls)
	g.player = p
	p.on_level_up = g._level_up
	p.x = int(hs.get("x", 0))
	p.y = int(hs.get("y", 0))
	p.rx = p.x
	p.ry = p.y
	p.col = str(hs.get("col", p.col))
	p.facing = int(hs.get("facing", 1))
	p.max_hp = maxi(1, int(hs.get("max_hp", p.max_hp)))
	p.hp = clampi(int(hs.get("hp", p.max_hp)), 1, p.max_hp)
	p.base_atk = int(hs.get("base_atk", p.base_atk))
	p.base_mag = int(hs.get("base_mag", p.base_mag))
	p.base_def = int(hs.get("base_def", p.base_def))
	p.lives = int(hs.get("lives", 3))
	p.xp = int(hs.get("xp", 0))
	p.plvl = maxi(1, int(hs.get("plvl", 1)))
	p.xp_next = maxi(1, int(hs.get("xp_next", 60)))
	p.poison = int(hs.get("poison", 0))
	p.gold = int(hs.get("gold", 0))
	p.steps = int(hs.get("steps", 0))
	p.perks = {}
	if hs.get("perks") is Dictionary:
		for k in (hs["perks"] as Dictionary):
			if Perks.LIST.has(k):
				p.perks[str(k)] = int((hs["perks"] as Dictionary)[k])
	p.weapon = item_from(hs.get("weapon"))
	p.armor = item_from(hs.get("armor"))
	p.shield = item_from(hs.get("shield"))
	p.inventory.clear()
	if hs.get("inventory") is Array:
		for v in (hs["inventory"] as Array):
			var it := item_from(v)
			if it != null:
				p.inventory.append(it)
	p.msgs.clear()
	if hs.get("msgs") is Array:
		for v in (hs["msgs"] as Array):
			# csak a fordítási hivatkozások maradnak meg; a régi mentések kész (magyar) szövegei nem
			# fordíthatók, ezért kimaradnak — a napló a "Folytatod a kalandot..." sorral indul újra
			if v is Dictionary and Lang.ervenyes_ref((v as Dictionary).get("t")):
				p.msgs.append({"t": (v as Dictionary)["t"], "c": str((v as Dictionary).get("c", Data.P["ink"]))})
	p.msg_seq = p.msgs.size()

	var w := World.new()
	w.player = p
	w.tiles = tiles
	w.explored = explored
	var fade_b := Marshalls.base64_to_raw(str(mp.get("fade", "")))
	w.fade = fade_b.to_float32_array() if fade_b.size() == n * 4 else PackedFloat32Array()
	if w.fade.size() != n:
		w.fade.resize(n)
	w.rooms.clear()
	for r in (rooms_raw as Array):
		if r is Array and (r as Array).size() == 4:
			w.rooms.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	if w.rooms.is_empty():
		return null
	w.room_kind.clear()
	if mp.get("room_kind") is Array:
		for k in (mp["room_kind"] as Array):
			w.room_kind.append(str(k))
	while w.room_kind.size() < w.rooms.size():
		w.room_kind.append("")
	w.mons.clear()
	if mp.get("mons") is Array:
		for v in (mp["mons"] as Array):
			if not (v is Dictionary):
				continue
			var md: Dictionary = v
			if not Data.MONS.has(str(md.get("key", ""))):
				continue
			var m := Mon.new()
			m.key = str(md["key"])
			m.x = int(md.get("x", 0))
			m.y = int(md.get("y", 0))
			m.rx = m.x
			m.ry = m.y
			m.seedv = float(md.get("seedv", 0.0))
			m.facing = int(md.get("facing", 1))
			m.max_hp = maxi(1, int(md.get("max_hp", 1)))
			m.hp = int(md.get("hp", m.max_hp))
			m.atk = int(md.get("atk", 1))
			m.def = int(md.get("def", 0))
			m.mres = int(md.get("mres", 0))
			m.xp = int(md.get("xp", 0))
			m.sp = str(md.get("sp", ""))
			m.boss = bool(md.get("boss", false))
			m.alive = bool(md.get("alive", true))
			m.guard = bool(md.get("guard", false))
			m.awake = bool(md.get("awake", false))
			m.stun = int(md.get("stun", 0))
			w.mons.append(m)
	w.chests = []
	if mp.get("chests") is Array:
		for v in (mp["chests"] as Array):
			if not (v is Dictionary):
				continue
			var cd: Dictionary = v
			var items: Array = []
			if cd.get("items") is Array:
				for iv in (cd["items"] as Array):
					var ii := item_from(iv)
					if ii != null:
						items.append(ii)
			while items.size() < 2:
				items.append(Item.make(Item.find_base("healing_potion"), "common", 1))
			w.chests.append({"x": int(cd.get("x", 0)), "y": int(cd.get("y", 0)), "opened": bool(cd.get("opened", false)), "items": items})
	w.shops = []
	if mp.get("shops") is Array:
		for v in (mp["shops"] as Array):
			if not (v is Dictionary):
				continue
			var sd: Dictionary = v
			var stock: Array = []
			if sd.get("stock") is Array:
				for ev in (sd["stock"] as Array):
					if not (ev is Dictionary):
						continue
					var ed: Dictionary = ev
					stock.append({"kind": str(ed.get("kind", "item")), "item": item_from(ed.get("item")),
						"price": int(ed.get("price", 20)), "sold": bool(ed.get("sold", false))})
			w.shops.append({"x": int(sd.get("x", 0)), "y": int(sd.get("y", 0)), "stock": stock})
	w.traps = _dict_list(mp.get("traps"), {"x": 0, "y": 0, "type": "tuske", "found": false, "sprung": false})
	w.secrets = _dict_list(mp.get("secrets"), {"x": 0, "y": 0, "kind": "atjaro", "found": false})
	w.shrines = _dict_list(mp.get("shrines"), {"x": 0, "y": 0, "kind": "gyogyulas", "used": false})
	w.decor = _dict_list(mp.get("decor"), {"x": 0, "y": 0, "type": "bones", "seed": 0.0})
	w.torches = _dict_list(mp.get("torches"), {"x": 0, "y": 0, "ph": 0.0})
	w.dungeon_level = clampi(int(jt.get("melyseg", 1)), 1, Data.MAX_LEVEL)
	w.diff = str(jt.get("nehezseg", "normal"))
	if not Data.DIFF.has(w.diff):
		w.diff = "normal"
	w.turn = int(jt.get("kor", 0))
	w.build_kind_map()
	w.update_fov()
	g.world = w
	g.pending_perks = maxi(0, int(jt.get("pending_perks", 0)))
	return g


## A mentésből visszaolvasott szótárlista: minden elem a minta kulcsait kapja, a megfelelő típussal.
static func _dict_list(v: Variant, proto: Dictionary) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for e in (v as Array):
		if not (e is Dictionary):
			continue
		var src: Dictionary = e
		var row := {}
		for k in proto:
			var def: Variant = proto[k]
			var got: Variant = src.get(k, def)
			if def is bool:
				row[k] = bool(got)
			elif def is int:
				row[k] = int(got)
			elif def is float:
				row[k] = float(got)
			else:
				row[k] = str(got)
		out.append(row)
	return out
