class_name World
extends RefCounted
## Egy mélység (szint) teljes állapota.

var tiles := PackedByteArray()
var rooms: Array[Rect2i] = []
var mons: Array[Mon] = []
var chests: Array = []       # {x, y, opened, items:[Item, Item]}
var decor: Array = []
var torches: Array = []
var vis := PackedByteArray()       # most látható mezők
var explored := PackedByteArray()  # bejárt mezők (szintenként külön)
var fade := PackedFloat32Array()   # mezőnkénti, lágyan változó fényerő (0..1)
var dungeon_level := 1
var diff := "normal"
var turn := 0
var player: Player


static func create(p: Player, dl: int, df: String) -> World:
	var w := World.new()
	var g := Dungeon.generate_map(dl)
	w.tiles = g["tiles"]
	w.rooms = g["rooms"]
	w.mons = Dungeon.spawn_mons(w.rooms, dl, df)
	w.chests = Dungeon.spawn_chests(w.rooms, dl)
	Dungeon.ensure_open(w.tiles, w.rooms, w.chests)
	w.decor = Dungeon.spawn_decor(w.tiles, w.rooms)
	w.torches = Dungeon.seed_torches(w.rooms)
	w.dungeon_level = dl
	w.diff = df
	w.player = p
	w.explored.resize(Data.MAP_W * Data.MAP_H)
	w.fade.resize(Data.MAP_W * Data.MAP_H)
	var s := Dungeon.center(w.rooms[0])
	p.x = s.x
	p.y = s.y
	p.rx = s.x
	p.ry = s.y
	w.update_fov()
	return w


func update_fov() -> void:
	vis = Dungeon.compute_fov(tiles, player.x, player.y)
	for i in vis.size():
		if vis[i]:
			explored[i] = 1


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


func blocked(x: int, y: int) -> bool:
	return x < 0 or x >= Data.MAP_W or y < 0 or y >= Data.MAP_H or tiles[x * Data.MAP_H + y] == Data.WALL
