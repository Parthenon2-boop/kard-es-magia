class_name Dungeon
extends RefCounted
## Pályagenerálás, látómező (FOV), a "sose lehessen bezáródni" biztosíték, szörnyek/ládák/díszek.
## A csempék egy PackedByteArray-ben vannak: index = x * MAP_H + y (mint az eredeti tiles[x][y]).

const W := Data.MAP_W
const H := Data.MAP_H
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func idx(x: int, y: int) -> int:
	return x * H + y


static func center(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + int(r.size.x / 2), r.position.y + int(r.size.y / 2))


static func _intersects(a: Rect2i, o: Rect2i, p: int) -> bool:
	return a.position.x - p < o.position.x + o.size.x and a.position.x + a.size.x + p > o.position.x \
		and a.position.y - p < o.position.y + o.size.y and a.position.y + a.size.y + p > o.position.y


## Szobák + L alakú folyosók; a lépcső az utolsó szoba közepén van.
static func generate_map(level: int) -> Dictionary:
	var tiles := PackedByteArray()
	tiles.resize(W * H)
	tiles.fill(Data.WALL)
	var rooms: Array[Rect2i] = []
	var target := 50 + level * 5
	for a in 3000:
		if rooms.size() >= target:
			break
		var w := Data.rnd(4, 11)
		var h := Data.rnd(3, 8)
		var x := Data.rnd(1, W - w - 2)
		var y := Data.rnd(1, H - h - 2)
		var room := Rect2i(x, y, w, h)
		var grown := room.grow(1)   # 1 mező térköz a szobák között
		var bad := false
		for r in rooms:
			if grown.intersects(r):
				bad = true
				break
		if bad:
			continue
		for rx in range(room.position.x, room.position.x + room.size.x):
			for ry in range(room.position.y, room.position.y + room.size.y):
				tiles[idx(rx, ry)] = Data.FLOOR
		if rooms.size() > 0:
			var c := center(room)
			var pc := center(rooms[rooms.size() - 1])
			if randf() < 0.5:
				for tx in range(mini(c.x, pc.x), maxi(c.x, pc.x) + 1): tiles[idx(tx, pc.y)] = Data.FLOOR
				for ty in range(mini(c.y, pc.y), maxi(c.y, pc.y) + 1): tiles[idx(c.x, ty)] = Data.FLOOR
			else:
				for ty in range(mini(c.y, pc.y), maxi(c.y, pc.y) + 1): tiles[idx(c.x, ty)] = Data.FLOOR
				for tx in range(mini(c.x, pc.x), maxi(c.x, pc.x) + 1): tiles[idx(tx, c.y)] = Data.FLOOR
		rooms.append(room)
	var s := center(rooms[rooms.size() - 1])
	tiles[idx(s.x, s.y)] = Data.STAIR
	return {"tiles": tiles, "rooms": rooms}


## Sugárvetéses látómező (2 fokonként, FOV_R mező). Az eredmény egy 0/1 tömb.
static func compute_fov(tiles: PackedByteArray, px: int, py: int) -> PackedByteArray:
	var vis := PackedByteArray()
	vis.resize(W * H)
	vis[idx(px, py)] = 1
	for a in range(0, 360, 2):
		var rad := a * PI / 180.0
		var ca := cos(rad)
		var sa := sin(rad)
		var dx := 0.0
		var dy := 0.0
		for i in Data.FOV_R:
			dx += ca
			dy += sa
			var tx := int(floorf(px + dx + 0.5))
			var ty := int(floorf(py + dy + 0.5))
			if tx < 0 or tx >= W or ty < 0 or ty >= H:
				break
			vis[idx(tx, ty)] = 1
			# a fal és a (még meg nem talált) titkos ajtó is elzárja a kilátást
			var tv := tiles[idx(tx, ty)]
			if tv == Data.WALL or tv == Data.SECRET:
				break
	return vis


# ══════════ BIZTOSÍTÉK: SOSE LEHESSEN BEZÁRÓDNI ══════════
# A kezdőpontból (4 irányban lépve) minden padlónak, a lépcsőnek és minden ládának elérhetőnek kell lennie.
# Ahol nem az, oda folyosót vájunk; a ládák soha nem zárhatnak el utat (azokat máshová tesszük).
static func reach_map(tiles: PackedByteArray, sx: int, sy: int, block: Dictionary) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(W * H)
	# a ládák (blokkolók) előre bejelölve "fal"-ként egy másolaton
	var walk := tiles.duplicate()
	for b in block:
		walk[b] = Data.WALL
	var q := PackedInt32Array()
	var s0 := idx(sx, sy)
	q.append(s0)
	seen[s0] = 1
	var n := W * H
	while not q.is_empty():
		var i: int = q[q.size() - 1]
		q.remove_at(q.size() - 1)
		var y := i % H
		# jobbra / balra (x ± 1), le / fel (y ± 1)
		var j := i + H
		if j < n and not seen[j] and walk[j] != Data.WALL:
			seen[j] = 1
			q.append(j)
		j = i - H
		if j >= 0 and not seen[j] and walk[j] != Data.WALL:
			seen[j] = 1
			q.append(j)
		if y + 1 < H:
			j = i + 1
			if not seen[j] and walk[j] != Data.WALL:
				seen[j] = 1
				q.append(j)
		if y > 0:
			j = i - 1
			if not seen[j] and walk[j] != Data.WALL:
				seen[j] = 1
				q.append(j)
	return seen

static func _count(seen: PackedByteArray) -> int:
	return seen.count(1)


static func carve_to(tiles: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		if tiles[idx(x, y0)] == Data.WALL: tiles[idx(x, y0)] = Data.FLOOR
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		if tiles[idx(x1, y)] == Data.WALL: tiles[idx(x1, y)] = Data.FLOOR


static func has_open_side(c: Dictionary, seen: PackedByteArray) -> bool:
	for d in DIRS:
		var x: int = c["x"] + d.x
		var y: int = c["y"] + d.y
		if x >= 0 and y >= 0 and x < W and y < H and seen[idx(x, y)]:
			return true
	return false


static func _block_of(chests: Array) -> Dictionary:
	var b := {}
	for o in chests:
		if not o["opened"]:
			b[idx(o["x"], o["y"])] = true
	return b


static func _fine(tiles: PackedByteArray, sx: int, sy: int, chests: Array, block: Dictionary, total: int) -> bool:
	var seen := reach_map(tiles, sx, sy, block)
	if _count(seen) + block.size() < total:
		return false
	for o in chests:
		if o["opened"] or not block.has(idx(o["x"], o["y"])):
			continue
		if not has_open_side(o, seen):
			return false
	return true


static func ensure_open(tiles: PackedByteArray, rooms: Array[Rect2i], chests: Array) -> void:
	var s := center(rooms[0])
	# 1. minden padló (és a lépcső) összefüggő legyen: ami leszakadt, azt folyosóval bekötjük
	for guard in 200:
		var seen := reach_map(tiles, s.x, s.y, {})
		var lost := Vector2i(-1, -1)
		for i in W * H:
			if tiles[i] != Data.WALL and not seen[i]:
				lost = Vector2i(int(i / H), i % H)
				break
		if lost.x < 0:
			break
		carve_to(tiles, lost.x, lost.y, s.x, s.y)
	# 2. a ládák ne zárjanak el semmit: ha egy láda nélkül több minden érhető el, mint vele, áttesszük
	var total := _count(reach_map(tiles, s.x, s.y, {}))
	var cfg_ok := -1   # az aktuális ládaelrendezés jó-e (-1: még nem tudjuk) — csak változáskor számoljuk újra
	for c in chests:
		if c["opened"]:
			continue
		var block := _block_of(chests)
		var on_stair_or_start: bool = tiles[idx(c["x"], c["y"])] == Data.STAIR or (c["x"] == s.x and c["y"] == s.y)
		if not on_stair_or_start:
			if cfg_ok == -1:
				cfg_ok = 1 if _fine(tiles, s.x, s.y, chests, block, total) else 0
			if cfg_ok == 1:
				continue
		# áthelyezés egy olyan szobabeli helyre, ahol nem zár el semmit
		var moved := false
		for tries in 80:
			if moved:
				break
			var r: Rect2i = rooms[Data.rnd(1, rooms.size() - 1)]
			var nx := Data.rnd(r.position.x + 1, r.position.x + r.size.x - 2)
			var ny := Data.rnd(r.position.y + 1, r.position.y + r.size.y - 2)
			if tiles[idx(nx, ny)] != Data.FLOOR or (nx == s.x and ny == s.y):
				continue
			var taken := false
			for o in chests:
				if o != c and not o["opened"] and o["x"] == nx and o["y"] == ny:
					taken = true
					break
			if taken:
				continue
			var b2 := block.duplicate()
			b2.erase(idx(c["x"], c["y"]))
			b2[idx(nx, ny)] = true
			var ox: int = c["x"]
			var oy: int = c["y"]
			c["x"] = nx
			c["y"] = ny
			if _fine(tiles, s.x, s.y, chests, b2, total):
				moved = true
			else:
				c["x"] = ox
				c["y"] = oy
		if moved:
			cfg_ok = 1   # az új helyen az egész elrendezés ellenőrizve jó
		else:
			c["opened"] = true   # végső esetben a láda eltűnik, de az út szabad marad
			cfg_ok = -1


## Ellenőrzés (tesztekhez): minden padló, a lépcső és minden láda elérhető-e.
## A titkos ajtó átjárhatónak számít: kutatással (K) mindig kinyitható, így sosem zár el semmit.
static func verify_open(tiles: PackedByteArray, rooms: Array[Rect2i], chests: Array) -> String:
	var s := center(rooms[0])
	var all := reach_map(tiles, s.x, s.y, {})
	for i in W * H:
		if tiles[i] != Data.WALL and not all[i]:
			return "elérhetetlen padló %d,%d" % [int(i / H), i % H]
	var block := _block_of(chests)
	var seen := reach_map(tiles, s.x, s.y, block)
	if _count(seen) + block.size() < _count(all):
		return "egy láda elvág egy részt"
	for c in chests:
		if c["opened"]:
			continue
		var ci := idx(c["x"], c["y"])
		if tiles[ci] == Data.STAIR:
			return "láda a lépcsőn"
		if c["x"] == s.x and c["y"] == s.y:
			return "láda a kezdőponton"
		if not has_open_side(c, seen):
			return "láda nem érhető el %d,%d" % [c["x"], c["y"]]
	return ""


# ══════════ KÜLÖNLEGES TERMEK ══════════
## Néhány szoba kap egy szerepet (kincstár, szentély, kereskedő, csapdaterem). Ez CSAK a szoba
## tartalmát változtatja meg — egyetlen csempe sem lesz fal tőle, így a bejárhatóság sértetlen.
## A kezdőszoba (0.) és a lépcsős/boss szoba (utolsó) sosem kap szerepet.
static func mark_rooms(rooms: Array[Rect2i]) -> Array[String]:
	var kinds: Array[String] = []
	kinds.resize(rooms.size())
	kinds.fill("")
	var cand: Array[int] = []
	for i in range(1, rooms.size() - 1):
		var r := rooms[i]
		if r.size.x >= 5 and r.size.y >= 4:
			cand.append(i)
	cand.shuffle()
	var k := 0
	for kind in Data.ROOM_KIND_ORDER:
		if k >= cand.size():
			break
		kinds[cand[k]] = kind
		k += 1
	return kinds


static func _inner(r: Rect2i) -> Vector2i:
	return Vector2i(Data.rnd(r.position.x + 1, r.position.x + r.size.x - 2), Data.rnd(r.position.y + 1, r.position.y + r.size.y - 2))


static func spawn_mons(rooms: Array[Rect2i], level: int, diff: String, kinds: Array[String] = []) -> Array[Mon]:
	var pool: Array = Data.POOL.get(level, ["goblin"])
	var mons: Array[Mon] = []
	for i in range(1, rooms.size() - 1):
		var r := rooms[i]
		var kind: String = kinds[i] if i < kinds.size() else ""
		if kind == "kereskedo" or kind == "szentely":
			continue   # a kereskedő és a szentély terme békés
		var cnt := Data.rnd(1, 2 + int(level / 2))
		for j in cnt:
			var q := _inner(r)
			mons.append(Mon.make(Data.pick(pool), q.x, q.y, diff))
		if level >= 2 and randf() < 0.28:
			var q2 := _inner(r)
			mons.append(Mon.make(Data.pick(["vampire", "spider", "golem", "witch", "assassin"]), q2.x, q2.y, diff))
		if kind == "kincstar":
			var g := center(r)
			mons.append(Mon.make_guard(Data.pick(Data.GUARD_POOL.get(level, ["orc"])), g.x, g.y, diff))
	var b := center(rooms[rooms.size() - 1])
	mons.append(Mon.make(Data.BOSS_LVL[level], b.x, b.y, diff))
	return mons


static func spawn_chests(rooms: Array[Rect2i], lvl: int, kinds: Array[String] = []) -> Array:
	var chests: Array = []
	for i in range(1, rooms.size()):
		var r := rooms[i]
		var kind: String = kinds[i] if i < kinds.size() else ""
		var n := 0
		var bonus := 0
		if kind == "kincstar":
			n = 2
			bonus = 1        # a kincstárban értékesebb a zsákmány
		elif kind == "csapda":
			n = 1            # a csapdateremben egy láda garantált
		elif kind == "kereskedo" or kind == "szentely":
			n = 0
		elif randf() < 0.42:
			n = 1
		for j in n:
			var q := _inner(r)
			chests.append({"x": q.x, "y": q.y, "opened": false, "items": [Item.random(lvl + bonus), Item.random(lvl + bonus)]})
	return chests


# ══════════ SZENTÉLY ÉS KERESKEDŐ ══════════
## Mindkettő járható mezőn áll (rá lehet lépni), tehát egyiktől sem záródhat el semmi.
static func spawn_shrines(tiles: PackedByteArray, rooms: Array[Rect2i], kinds: Array[String], used: Dictionary) -> Array:
	var out: Array = []
	for i in kinds.size():
		if kinds[i] != "szentely":
			continue
		var c := _free_spot(tiles, rooms[i], used)
		if c.x < 0:
			continue
		used[idx(c.x, c.y)] = true
		out.append({"x": c.x, "y": c.y, "kind": Data.pick(Data.SHRINE_ORDER), "used": false})
	return out


static func spawn_shops(tiles: PackedByteArray, rooms: Array[Rect2i], kinds: Array[String], lvl: int, used: Dictionary) -> Array:
	var out: Array = []
	for i in kinds.size():
		if kinds[i] != "kereskedo":
			continue
		var c := _free_spot(tiles, rooms[i], used)
		if c.x < 0:
			continue
		used[idx(c.x, c.y)] = true
		out.append({"x": c.x, "y": c.y, "stock": make_stock(lvl)})
	return out


## A kereskedő kínálata: egy bájital, egy véletlen tárgy és egy teljes gyógyítás (10–60 arany).
static func make_stock(lvl: int) -> Array:
	var stock: Array = []
	var pot := Item.make(Item.find_base("greater_healing_potion" if lvl >= 3 else "healing_potion"), Item.roll_rarity(lvl), lvl)
	stock.append({"kind": "item", "item": pot, "price": clampi(12 + lvl * 3, 10, 60), "sold": false})
	var goods := Item.random(lvl + 1)
	stock.append({"kind": "item", "item": goods, "price": clampi(int(Data.SHOP_PRICE[goods.rarity]) + lvl * 2, 10, 60), "sold": false})
	stock.append({"kind": "heal", "item": null, "price": clampi(18 + lvl * 5, 10, 60), "sold": false})
	return stock


static func _free_spot(tiles: PackedByteArray, r: Rect2i, used: Dictionary) -> Vector2i:
	for tries in 60:
		var q := _inner(r)
		var k := idx(q.x, q.y)
		if tiles[k] == Data.FLOOR and not used.has(k):
			return q
	return Vector2i(-1, -1)


# ══════════ CSAPDÁK ══════════
## Csapda csak szoba belsejébe kerül (folyosóra soha), így sosem áll az EGYETLEN út közepén:
## a szobán belül mindig ki lehet kerülni. A kezdőszoba csapdamentes.
static func spawn_traps(tiles: PackedByteArray, rooms: Array[Rect2i], kinds: Array[String], level: int, used: Dictionary) -> Array:
	var traps: Array = []
	for i in range(1, rooms.size()):
		var r := rooms[i]
		var kind: String = kinds[i] if i < kinds.size() else ""
		var n := 0
		if kind == "csapda":
			n = Data.rnd(4, 7)
		elif kind == "szentely" or kind == "kereskedo":
			n = 0
		elif randf() < 0.34:
			n = Data.rnd(1, 1 + int(level / 2))
		for j in n:
			var q := _free_spot(tiles, r, used)
			if q.x < 0:
				continue
			used[idx(q.x, q.y)] = true
			traps.append({"x": q.x, "y": q.y, "type": Data.pick(Data.TRAP_ORDER), "found": false, "sprung": false})
	return traps


# ══════════ TITKOS AJTÓK ══════════
## Kétféle: (1) átjáró — két, már összekötött rész közötti falat nyit meg rövidítésnek;
## (2) kamra — egy zsákutca-mezőt nyit, benne egy ládával.
## Mindkettő SECRET csempe: a bejárhatóság-ellenőrzés átjárhatónak veszi (kutatással kinyitható),
## a hős viszont csak a megtalálás után tud átmenni rajta.
static func carve_secrets(tiles: PackedByteArray, rooms: Array[Rect2i], lvl: int, chests: Array) -> Array:
	var secrets: Array = []
	var s := center(rooms[0])
	# (1) rövidítések: olyan fal, aminek két szemközti oldalán padló van
	var shortcuts: Array[int] = []
	for x in range(2, W - 2):
		for y in range(2, H - 2):
			var k := idx(x, y)
			if tiles[k] != Data.WALL:
				continue
			var lr := tiles[k - H] == Data.FLOOR and tiles[k + H] == Data.FLOOR and tiles[k - 1] != Data.FLOOR and tiles[k + 1] != Data.FLOOR
			var ud := tiles[k - 1] == Data.FLOOR and tiles[k + 1] == Data.FLOOR and tiles[k - H] != Data.FLOOR and tiles[k + H] != Data.FLOOR
			if lr or ud:
				shortcuts.append(k)
	shortcuts.shuffle()
	for i in mini(Data.rnd(1, 3), shortcuts.size()):
		var k: int = shortcuts[i]
		tiles[k] = Data.SECRET
		secrets.append({"x": int(k / H), "y": k % H, "kind": "atjaro", "found": false})
	# (2) kamrák: ajtó egy padló mellett, mögötte tömör fal -> abból lesz a kincseskamra
	# Az a mező, ahonnan egy kamra nyílik, nem lehet láda alatt és nem lehet másik kamra sem:
	# különben a rajta álló láda elvágná a kamrát (a "láda sosem zár el utat" szabály).
	var noflow := {}
	for ch in chests:
		if not ch["opened"]:
			noflow[idx(ch["x"], ch["y"])] = true
	var made := 0
	var want := Data.rnd(1, 2)
	for tries in 400:
		if made >= want:
			break
		var x := Data.rnd(3, W - 4)
		var y := Data.rnd(3, H - 4)
		var d: Vector2i = pick_dir()
		var dk := idx(x, y)
		if tiles[dk] != Data.WALL:
			continue
		var fk := idx(x - d.x, y - d.y)          # az ajtó előtti mező: szabad padló kell legyen
		if tiles[fk] != Data.FLOOR or noflow.has(fk):
			continue
		var nx := x + d.x
		var ny := y + d.y
		# a kamra és a körülötte lévő minden mező (az ajtót kivéve) tömör fal
		var solid := true
		for ax in range(nx - 1, nx + 2):
			for ay in range(ny - 1, ny + 2):
				if ax == x and ay == y:
					continue
				if tiles[idx(ax, ay)] != Data.WALL:
					solid = false
		if not solid:
			continue
		if nx == s.x and ny == s.y:
			continue
		tiles[dk] = Data.SECRET
		tiles[idx(nx, ny)] = Data.FLOOR
		secrets.append({"x": x, "y": y, "kind": "kamra", "found": false})
		chests.append({"x": nx, "y": ny, "opened": false, "items": [Item.random(lvl + 1), Item.random(lvl + 1)]})
		noflow[idx(nx, ny)] = true
		noflow[dk] = true
		made += 1
	return secrets


static func pick_dir() -> Vector2i:
	return DIRS[randi() % DIRS.size()]


# ══════════ DEKORÁCIÓK (amfora, pókháló, repedés...) ══════════
static func spawn_decor(tiles: PackedByteArray, rooms: Array[Rect2i]) -> Array:
	var decor: Array = []
	var used := {}
	var place := func(x: int, y: int, type: String) -> void:
		var k := idx(x, y)
		if used.has(k):
			return
		used[k] = true
		decor.append({"x": x, "y": y, "type": type, "seed": randf() * 100.0})
	for r in rooms:
		var rx := r.position.x
		var ry := r.position.y
		var rw := r.size.x
		var rh := r.size.y
		# Pókháló a sarkokban (padlócsempe, két fal mellett)
		for c in [Vector2i(rx, ry), Vector2i(rx + rw - 1, ry), Vector2i(rx, ry + rh - 1), Vector2i(rx + rw - 1, ry + rh - 1)]:
			if tiles[idx(c.x, c.y)] == Data.FLOOR and randf() < 0.35:
				place.call(c.x, c.y, "web")
		# Amfora / hordó a fal mellett
		if randf() < 0.4:
			var side: Vector2i = Data.pick([Vector2i(rx, Data.rnd(ry + 1, ry + rh - 2)), Vector2i(rx + rw - 1, Data.rnd(ry + 1, ry + rh - 2)),
				Vector2i(Data.rnd(rx + 1, rx + rw - 2), ry), Vector2i(Data.rnd(rx + 1, rx + rw - 2), ry + rh - 1)])
			if tiles[idx(side.x, side.y)] == Data.FLOOR:
				place.call(side.x, side.y, Data.pick(["amphora", "barrel"]))
		# Padló-szórvány: csont, koponya, törmelék, moha, tócsa
		var n := Data.rnd(0, 3)
		for i in n:
			var dx := Data.rnd(rx + 1, rx + rw - 2)
			var dy := Data.rnd(ry + 1, ry + rh - 2)
			if tiles[idx(dx, dy)] == Data.FLOOR:
				place.call(dx, dy, Data.pick(["bones", "skull", "rubble", "moss", "puddle"]))
	# Repedések a látható falakon (padló melletti falcsempék)
	for x in range(1, W - 1):
		for y in range(1, H - 1):
			if tiles[idx(x, y)] != Data.WALL:
				continue
			var near := tiles[idx(x + 1, y)] == Data.FLOOR or tiles[idx(x - 1, y)] == Data.FLOOR \
				or tiles[idx(x, y + 1)] == Data.FLOOR or tiles[idx(x, y - 1)] == Data.FLOOR
			if near and randf() < 0.06:
				place.call(x, y, "crack")
	return decor


static func seed_torches(rooms: Array[Rect2i]) -> Array:
	var t: Array = []
	for r in rooms:
		if randf() < 0.55: t.append({"x": r.position.x + 1, "y": r.position.y + 1, "ph": randf() * 7.0})
		if randf() < 0.35: t.append({"x": r.position.x + r.size.x - 2, "y": r.position.y + r.size.y - 2, "ph": randf() * 7.0})
	return t
