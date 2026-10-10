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
var notes: Array = []        # {x, y, id, taken} — megtalálható feljegyzések (a Napló lapjai)
var hazards: Array = []      # {x, y, kind, ttl, dmg, warn} — előre jelzett csapások és savtócsák
var vents: Array = []        # {x, y, ph} — padlórácsok: időnként kitör belőlük a zóna csapása
var events: Array = []       # {x, y, kind, used} — döntési események
var pedestals: Array = []    # {x, y, taken} — ereklye-talapzatok (főellenség / mini-boss után)
var gepek: Array = []        # {tip, x, y, dx, dy, n, ph, p, t, all} — a zóna saját pályaelemei (lásd Data.GEP_ZONA)
var lapok: Array = []        # {x, y, jel, sor, le} — a rejtvényszoba nyomólapjai
var decor: Array = []
var torches: Array = []
var vis := PackedByteArray()       # most látható mezők
var explored := PackedByteArray()  # bejárt mezők (szintenként külön)
var fade := PackedFloat32Array()   # mezőnkénti, lágyan változó fényerő (0..1)
var dungeon_level := 1
var emelet := 1             # a zónán belüli emelet (1..Data.emeletek(zóna)); a zóna ura az utolsón van
var diff := "normal"
var turn := 0
var player: Player
var fov_version := 0        # minden látótér-frissítésnél nő: a csempe-réteg ebből tudja, hogy változott
var explored_seq := 0       # nő, ha ÚJ mező derül ki (az automata térkép ebből tudja, hogy frissíteni kell)
var new_explored := PackedInt32Array()   # a térkép még be nem rajzolt új mezői


## em: a zónán belüli emelet; 0 = a zóna utolsó (főellenséges) emelete
static func create(p: Player, dl: int, df: String, em: int = 0) -> World:
	var w := World.new()
	var utolso := Data.emeletek(dl)
	em = utolso if em <= 0 else clampi(em, 1, utolso)
	var g := Dungeon.generate_map(dl)
	w.tiles = g["tiles"]
	w.rooms = g["rooms"]
	w.room_kind = Dungeon.mark_rooms(w.rooms)
	w.dungeon_level = dl
	w.emelet = em
	w.diff = df
	w.mons = Dungeon.spawn_mons(w.rooms, dl, df, w.room_kind, em >= utolso)
	# a szörnyek a pálya sorszáma szerint erősödnek (a zóna ura nem: az övé a MONS táblában áll)
	for mo in w.mons:
		w.erosit(mo)
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
	w.notes = Dungeon.spawn_notes(w.tiles, w.rooms, w.room_kind, dl, used)
	w.events = Dungeon.spawn_events(w.tiles, w.rooms, w.room_kind, used)
	w.vents = Dungeon.spawn_vents(w.tiles, w.rooms, w.room_kind, used)
	w.lapok = Dungeon.spawn_rejtveny(w.tiles, w.rooms, w.room_kind, dl, em, w.chests, used)
	w.gepek = Dungeon.spawn_gepek(w.tiles, w.rooms, w.room_kind, dl, em, used)
	w.decor = Dungeon.spawn_decor(w.tiles, w.rooms, dl)
	w.torches = Dungeon.seed_torches(w.rooms)
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
		var k: int = Data.ROOM_KIND_ALL.find(room_kind[i])
		if k < 0:
			continue
		var r := rooms[i]
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				kind_map[x * Data.MAP_H + y] = k + 1


func update_fov() -> void:
	vis = Dungeon.compute_fov(tiles, player.x, player.y)
	fov_version += 1
	# a látótér legfeljebb FOV_R mezőre ér: elég a hős körüli négyzetet átnézni (ugyanabban a
	# sorrendben, mint régen az egész pályát), nem mind a 4800 mezőt minden lépésnél
	var r := Data.FOV_R + 1
	var y0 := maxi(0, player.y - r)
	var y1 := mini(Data.MAP_H - 1, player.y + r)
	for x in range(maxi(0, player.x - r), mini(Data.MAP_W - 1, player.x + r) + 1):
		var alap := x * Data.MAP_H
		for y in range(y0, y1 + 1):
			var i := alap + y
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


func event_at(x: int, y: int) -> Variant:
	for e in events:
		if not e["used"] and e["x"] == x and e["y"] == y:
			return e
	return null


func pedestal_at(x: int, y: int) -> Variant:
	for e in pedestals:
		if not e["taken"] and e["x"] == x and e["y"] == y:
			return e
	return null


## a legközelebbi szabad, járható mező (a talapzatnak) — maga a mező, ha szabad
func free_near(x: int, y: int) -> Vector2i:
	for r in 4:
		for ax in range(-r, r + 1):
			for ay in range(-r, r + 1):
				var tx := x + ax
				var ty := y + ay
				if blocked(tx, ty) or tile(tx, ty) != Data.FLOOR:
					continue
				if chest_at(tx, ty) != null or pedestal_at(tx, ty) != null or shop_at(tx, ty) != null:
					continue
				return Vector2i(tx, ty)
	return Vector2i(x, y)


func note_at(x: int, y: int) -> Variant:
	for n in notes:
		if not n["taken"] and n["x"] == x and n["y"] == y:
			return n
	return null


func hazard_at(x: int, y: int, kind := "") -> Variant:
	for h in hazards:
		if h["x"] == x and h["y"] == y and (kind == "" or h["kind"] == kind):
			return h
	return null


# ══════════ A PÁLYA NEHÉZSÉGE ══════════
## A pálya sorszáma a kaland elejétől (1..15).
func szakasz() -> int:
	return Data.palya_sorszam(dungeon_level, emelet)


## Egy szörny (közönséges, őr, Fertőzött, mini-boss, megidézett) erősítése a pálya sorszáma
## szerint: az életereje szorzódik, a támadásához hozzáadódik (lásd Data.PALYA_HP / PALYA_ATK).
## A zóna urát nem érinti. Egy szörnyre csak egyszer szabad meghívni.
func erosit(mo: Mon) -> Mon:
	if mo.boss:
		return mo
	var s := szakasz()
	mo.max_hp = maxi(1, int(round(mo.max_hp * Data.palya_hp(s))))
	mo.hp = mo.max_hp
	var b := Data.palya_atk(s) * (1.0 + (float(Data.DIFF[diff]["monAtk"]) - 1.0) * Data.NEHEZSEG_PALYA)
	if mo.mini:
		b *= Data.MINI_PALYA_ATK
	mo.atk += int(round(b))
	return mo


# ══════════ REJTVÉNYSZOBA ÉS GÉPEK ══════════
func lap_at(x: int, y: int) -> Variant:
	for l in lapok:
		if l["x"] == x and l["y"] == y:
			return l
	return null


## a rejtvényszoba még leláncolt ládája (null, ha nincs, vagy már megoldották)
func zart_lada() -> Variant:
	for c in chests:
		if c.get("zart", false) and not c["opened"]:
			return c
	return null


## hány nyomólap van már (helyes sorrendben) lenyomva
func lapok_le() -> int:
	var n := 0
	for l in lapok:
		if l["le"]:
			n += 1
	return n


## A sínen ingázó szike helye a megadott körben (oda-vissza jár a sín `n` mezőjén).
func szike_hely(g: Dictionary, kor: int) -> Vector2i:
	var n := maxi(2, int(g["n"]))
	var k := posmod(kor + int(g["ph"]), 2 * (n - 1))
	if k >= n:
		k = 2 * (n - 1) - k
	return Vector2i(int(g["x"]) + int(g["dx"]) * k, int(g["y"]) + int(g["dy"]) * k)


## Egy ütemre járó gép (zsilip, korong) fázisa: 0 .. p-1.
func gep_fazis(g: Dictionary, kor: int = -1) -> int:
	return posmod((turn if kor < 0 else kor) + int(g["ph"]), maxi(1, int(g["p"])))


## A forgó korong gyűrűje az óramutató járása szerint (a bal felső saroktól).
const GYURU: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]


## Mezők, amelyekre most nem tanácsos lépni, mert a gép a közeljövőben lesújt rájuk.
## index -> true, ha kivárható (ütemre járó gép: pár kör múlva szabad az út), false, ha nem.
## A már jelzett csapások a `hazards` listában vannak; ez az, amit egy figyelmes játékos a gép
## állásából (nyomásmérő, a gubó duzzadása, a korong izzása) előre lát. A robotjátékos használja.
func veszely_mezok() -> Dictionary:
	var out := {}
	# a rejtvényszobában csak a soron következő lapra érdemes lépni
	if not lapok.is_empty() and zart_lada() != null:
		var kell := lapok_le()
		for l in lapok:
			if not l["le"] and int(l["sor"]) != kell:
				out[int(l["x"]) * Data.MAP_H + int(l["y"])] = false
	for g in gepek:
		var gx: int = g["x"]
		var gy: int = g["y"]
		match str(g["tip"]):
			"zsilip":
				# akkor biztonságos belépni, ha a gőz kifújásáig át lehet érni rajta
				var c := gep_fazis(g)
				var p: int = g["p"]
				if not (c == p - 1 or c + int(g["n"]) < p - 2):
					for i in int(g["n"]):
						out[(gx + int(g["dx"]) * i) * Data.MAP_H + gy + int(g["dy"]) * i] = true
			"gubo":
				if int(g["all"]) != 2:
					for ax in range(-1, 2):
						for ay in range(-1, 2):
							out[(gx + ax) * Data.MAP_H + gy + ay] = false
			"korong":
				if gep_fazis(g) >= int(g["p"]) - 3:
					for d in GYURU:
						out[(gx + d.x) * Data.MAP_H + gy + d.y] = true
	return out


## Amit a robotjátékos a rejtvényszobában keres: a soron következő nyomólap (ha már látta).
func robot_celok() -> Array:
	var out: Array = []
	if zart_lada() == null:
		return out
	var kell := lapok_le()
	for l in lapok:
		if not l["le"] and int(l["sor"]) == kell and is_exp(l["x"], l["y"]):
			out.append(int(l["x"]) * Data.MAP_H + int(l["y"]))
	return out


## a főellenség (ha él) — a felső életcsíkhoz
func boss() -> Mon:
	for m in mons:
		if m.boss and m.alive:
			return m
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
