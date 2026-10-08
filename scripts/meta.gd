class_name Meta
extends RefCounted
## A Kónusz-Lombik: ami a halál után is megmarad. Vane emlékei a Műtőterem tartályában
## várnak, a gyűjtött Bio-Hulladékból és Rézötvözetből pedig új szervek és végtagok
## varrhatók az új testre. Minden egy fájlban van: `user://gorgona.json`.
##
## A játékszabályok (Game, Player) csak OLVASSÁK: új kaland indításakor `apply_to` építi be
## a megvett fejlesztéseket a hősbe. Tesztben és képernyőkép-módban a `persist` hamis,
## így semmi nem íródik a játékos valódi fájljába.

## A mentések mappájában van ("_" kezdettel: nem kaland), így a felhő-mentés ezt is a fiókhoz köti:
## a megvett fejlesztések és a Napló másik gépen is megvannak.
const PATH := "user://mentesek/_gorgona.json"
const FAJL := "_gorgona.json"
## értesítés a felhő-mentésnek (fájlnév)
static var on_write: Callable = Callable()

## Nora, a Csontkovács (Rézötvözetért): fegyverek és mechanikus végtagok.
## A Megnyúzott Próféta (Bio-Hulladékért): bio-mutációk.
## cost: az első szint ára; minden további szint ennyivel drágább.
const UPGRADES := {
	"rezhenger": {"npc": "nora", "max": 5, "cost": 12, "ic": "♥", "col": "#e08a3a"},
	"mellvert": {"npc": "nora", "max": 4, "cost": 16, "ic": "🛡", "col": "#80a8e0"},
	"elezes": {"npc": "nora", "max": 5, "cost": 14, "ic": "⚔", "col": "#ffd060"},
	"lombik": {"npc": "nora", "max": 2, "cost": 40, "ic": "♥", "col": "#e06080"},
	"szivpumpa": {"npc": "profeta", "max": 3, "cost": 14, "ic": "✚", "col": "#50d080"},
	"mirigy": {"npc": "profeta", "max": 3, "cost": 18, "ic": "»", "col": "#a0e090"},
	"uvegszem": {"npc": "profeta", "max": 3, "cost": 12, "ic": "👁", "col": "#8cc4ff"},
	"gyomor": {"npc": "profeta", "max": 2, "cost": 20, "ic": "✚", "col": "#40c860"},
}
const ORDER := ["rezhenger", "mellvert", "elezes", "lombik", "szivpumpa", "mirigy", "uvegszem", "gyomor"]

static var persist := true
static var d := {}
static var seq := 0          # nő minden változásnál (a felület ebből tudja, hogy újra kell rajzolni)
static var _loaded := false


static func _alap() -> Dictionary:
	return {"bio": 0, "rez": 0, "up": {}, "notes": [], "runs": 0, "wins": 0, "deaths": 0,
		"deepest": 0, "last_death": 0, "kills": 0, "intro": false, "bosses": []}


static func data() -> Dictionary:
	if not _loaded:
		load_meta()
	return d


static func reset() -> void:
	d = _alap()
	_loaded = true
	seq += 1


static func load_meta() -> void:
	d = _alap()
	_loaded = true
	if persist and FileAccess.file_exists("user://gorgona.json") and not FileAccess.file_exists(PATH):
		DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
		DirAccess.rename_absolute("user://gorgona.json", PATH)   # a korábbi helyéről átköltözik
	if not persist or not FileAccess.file_exists(PATH):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(PATH)) != OK or not (j.data is Dictionary):
		return
	var src: Dictionary = j.data
	for k in ["bio", "rez", "runs", "wins", "deaths", "deepest", "last_death", "kills"]:
		d[k] = maxi(0, int(src.get(k, 0)))
	d["intro"] = bool(src.get("intro", false))
	if src.get("up") is Dictionary:
		for k in (src["up"] as Dictionary):
			if UPGRADES.has(k):
				d["up"][str(k)] = clampi(int(src["up"][k]), 0, int(UPGRADES[k]["max"]))
	if src.get("notes") is Array:
		for n in (src["notes"] as Array):
			if str(n) in Story.NOTE_ORDER and not (str(n) in d["notes"]):
				d["notes"].append(str(n))
	if src.get("bosses") is Array:
		for b in (src["bosses"] as Array):
			if Story.BOSS_TALK.has(str(b)) and not (str(b) in d["bosses"]):
				d["bosses"].append(str(b))


static func save_meta() -> void:
	seq += 1
	if not persist:
		return
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data()))
	f.close()
	if on_write.is_valid():
		on_write.call(FAJL)


# ══════════ FEJLESZTÉSEK ══════════
static func level(id: String) -> int:
	return int((data()["up"] as Dictionary).get(id, 0))


static func cost(id: String) -> int:
	return int(UPGRADES[id]["cost"]) * (level(id) + 1)


static func currency(id: String) -> String:
	return "rez" if UPGRADES[id]["npc"] == "nora" else "bio"


static func can_buy(id: String) -> bool:
	if not UPGRADES.has(id) or level(id) >= int(UPGRADES[id]["max"]):
		return false
	return int(data()[currency(id)]) >= cost(id)


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var dd := data()
	dd[currency(id)] = int(dd[currency(id)]) - cost(id)
	dd["up"][id] = level(id) + 1
	save_meta()
	return true


## A megvett fejlesztések beépítése egy frissen ébredő testbe.
static func apply_to(p: Player) -> void:
	p.max_hp += 8 * level("rezhenger")
	p.hp = p.max_hp
	p.base_def += level("mellvert")
	p.base_atk += level("elezes")
	if p.base_mag > 0:
		p.base_mag += level("elezes")
	p.lives += level("lombik")
	p.kill_heal = 2 * level("szivpumpa")
	p.cd_cut = level("mirigy")
	p.find_mult = 1.0 + 0.2 * level("uvegszem")
	for i in level("gyomor"):
		p.inventory.append(Item.make(Item.find_base("healing_potion"), "common", 1))


# ══════════ A KALAND VÉGE ══════════
## Egy kaland lezárása: a gyűjtött nyersanyag a tartályba kerül. `zona`: meddig jutott.
static func bank_run(p: Player, zona: int, won: bool) -> void:
	var dd := data()
	dd["bio"] = int(dd["bio"]) + p.bio
	dd["rez"] = int(dd["rez"]) + p.rez
	dd["kills"] = int(dd["kills"]) + p.kills
	dd["runs"] = int(dd["runs"]) + 1
	dd["deepest"] = maxi(int(dd["deepest"]), zona)
	if won:
		dd["wins"] = int(dd["wins"]) + 1
		dd["last_death"] = 0
	else:
		dd["deaths"] = int(dd["deaths"]) + 1
		dd["last_death"] = zona
	p.bio = 0
	p.rez = 0
	save_meta()


static func reach(zona: int) -> void:
	var dd := data()
	if zona > int(dd["deepest"]):
		dd["deepest"] = zona
		save_meta()


static func add_note(id: String) -> bool:
	var dd := data()
	if id in dd["notes"] or not (id in Story.NOTE_ORDER):
		return false
	dd["notes"].append(id)
	save_meta()
	return true


static func has_note(id: String) -> bool:
	return id in data()["notes"]


static func boss_down(key: String) -> void:
	var dd := data()
	if not (key in dd["bosses"]):
		dd["bosses"].append(key)
		save_meta()


static func intro_seen() -> bool:
	return bool(data()["intro"])


static func mark_intro() -> void:
	data()["intro"] = true
	save_meta()
