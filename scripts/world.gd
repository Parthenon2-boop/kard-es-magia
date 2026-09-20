class_name World
extends RefCounted
## Egy mélység (szint) teljes állapota.

var tiles := PackedByteArray()
var rooms: Array[Rect2i] = []
var room_kind: Array[String] = []  # szobánként "" vagy kincstar / szentely / kereskedo / csapda
var kind_map := PackedByteArray()  # mezőnként a különleges terem sorszáma + 1 (a térképhez)
var mons: Array[Mon] = []
var chests: Array = []       # {x, y, opened, items:[Item, Item]}
var traps: Array = []        # {x, y, type, found, sprung}
var secrets: Array = []      # {x, y, kind: atjaro|kamra, found}
var shrines: Array = []      # {x, y, kind, used}
var shops: Array = []        # {x, y, stock:[{kind, item, price, sold}]}
var decor: Array = []
var torches: Array = []
var vis := PackedByteArray()       # most látható mezők
var explored := PackedByteArray()  # bejárt mezők (szintenként külön)
var fade := PackedFloat32Array()   # mezőnkénti, lágyan változó fényerő (0..1)
var dungeon_level := 1
var diff := "normal"
var turn := 0
var player: Player
var fov_version := 0        # minden látótér-frissítésnél nő: a csempe-réteg ebből tudja, hogy változott
var explored_seq := 0       # nő, ha ÚJ mező derül ki (az automata térkép ebből tudja, hogy frissíteni kell)
var new_explored := PackedInt32Array()   # a térkép még be nem rajzolt új mezői


static func create(p: Player, dl: int, df: String) -> World:
	var w := World.new()
	var g := Dungeon.generate_map(dl)
	w.tiles = g["tiles"]
	w.rooms = g["rooms"]
	w.room_kind = Dungeon.mark_rooms(w.rooms)
	w.mons = Dungeon.spawn_mons(w.rooms, dl, df, w.room_kind)
	w.chests = Dungeon.spawn_chests(w.rooms, dl, w.room_kind)
	Dungeon.ensure_open(w.tiles, w.rooms, w.chests)
	# a titkos ajtók CSAK nyitnak (falat bontanak), ezért a bejárhatóság-biztosíték után jöhetnek
	w.secrets = Dungeon.carve_secrets(w.tiles, w.rooms, dl, w.chests)
	var used := {}
	var st := Dungeon.center(w.rooms[0])
	used[Dungeon.idx(st.x, st.y)] = true
	for c in w.chests:
		used[Dungeon.idx(c["x"], c["y"])] = true
	w.shrines = Dungeon.spawn_shrines(w.tiles, w.rooms, w.room_kind, used)
	w.shops = Dungeon.spawn_shops(w.tiles, w.rooms, w.room_kind, dl, used)
	w.traps = Dungeon.spawn_traps(w.tiles, w.rooms, w.room_kind, dl, used)
	w.decor = Dungeon.spawn_decor(w.tiles, w.rooms)
	w.torches = Dungeon.seed_torches(w.rooms)
	w.dungeon_level = dl
	w.diff = df
	w.player = p
	w.explored.resize(Data.MAP_W * Data.MAP_H)
	w.fade.resize(Data.MAP_W * Data.MAP_H)
	w.build_kind_map()
	p.x = st.x
	p.y = st.y
	p.rx = st.x
	p.ry = st.y
	w.update_fov()
	return w


## mezőnkénti terem-jelölés a kis térképhez (0 = hétköznapi)
func build_kind_map() -> void:
	kind_map = PackedByteArray()
	kind_map.resize(Data.MAP_W * Data.MAP_H)
	for i in room_kind.size():
		var k: int = Data.ROOM_KIND_ORDER.find(room_kind[i])
		if k < 0:
			continue
		var r := rooms[i]
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				kind_map[x * Data.MAP_H + y] = k + 1


func update_fov() -> void:
	vis = Dungeon.compute_fov(tiles, player.x, player.y)
	fov_version += 1
	for i in vis.size():
		if vis[i] and not explored[i]:
			explored[i] = 1
			explored_seq += 1
			new_explored.append(i)


func tile(x: int, y: int) -> int:
	return tiles[x * Data.MAP_H + y]


func is_vis(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= Data.MAP_W or y >= Data.MAP_H:
		return false
	return vis[x * Data.MAP_H + y] == 1


func is_exp(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= Data.MAP_W or y >= Data.MAP_H:
		return false
	return explored[x * Data.MAP_H + y] == 1


func mon_at(x: int, y: int) -> Mon:
	for m in mons:
		if m.alive and m.x == x and m.y == y:
			return m
	return null


func chest_at(x: int, y: int) -> Variant:
	for c in chests:
		if not c["opened"] and c["x"] == x and c["y"] == y:
			return c
	return null


func trap_at(x: int, y: int) -> Variant:
	for t in traps:
		if t["x"] == x and t["y"] == y:
			return t
	return null


func secret_at(x: int, y: int) -> Variant:
	for s in secrets:
		if s["x"] == x and s["y"] == y:
			return s
	return null


func shrine_at(x: int, y: int) -> Variant:
	for s in shrines:
		if s["x"] == x and s["y"] == y:
			return s
	return null


func shop_at(x: int, y: int) -> Variant:
	for s in shops:
		if s["x"] == x and s["y"] == y:
			return s
	return null


## a fal és a még titkos ajtó egyaránt elzárja az utat (a megtalált ajtóból padló lesz)
func blocked(x: int, y: int) -> bool:
	if x < 0 or x >= Data.MAP_W or y < 0 or y >= Data.MAP_H:
		return true
	var t := tiles[x * Data.MAP_H + y]
	return t == Data.WALL or t == Data.SECRET


## Egy titkos ajtó kinyitása: padló lesz belőle, és a látótér azonnal frissül.
func open_secret(s: Dictionary) -> void:
	s["found"] = true
	tiles[s["x"] * Data.MAP_H + s["y"]] = Data.FLOOR
	update_fov()
