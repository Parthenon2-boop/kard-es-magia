class_name Lang
extends RefCounted
## Nyelvek: magyar, angol, német. Minden játékosnak látható szöveg a `res://lang/<kód>.json`
## fájlokban van, kulcs → szöveg alakban; a kódban csak a kulcs szerepel: `Lang.T("menu.quit")`.
##
## Helyőrzők: `{0}`, `{1}`... (String.format), így a fordítás szabadon átrendezheti a szórendet.
## Élő váltás: a `seq` minden nyelvcserénél nő (a rajzrétegek aláírása ebből tudja, hogy
## újra kell rajzolni). A választott nyelv a beállításfájlba kerül (lásd main.gd).
##
## Az üzenetnaplóba és a fiók-üzenetekbe NEM kész szöveg kerül, hanem hivatkozás
## (`Lang.ref(kulcs, paraméterek...)`), amely a kirajzoláskor fordítódik le — így a már kiírt
## üzenetek is azonnal nyelvet váltanak, és a mentésbe sem kerül lefordított szöveg.

const NYELVEK := ["hu", "en", "de"]
const MAPPA := "res://lang/%s.json"
## a kasztok belső azonosítója (a mentésben és a táblákban ez áll) → fordítási kulcs
const CLS_KULCS := {"Lovag": "knight", "Mágus": "mage", "Íjász": "archer"}

static var current := ""
static var seq := 0
static var _tablak := {}


## Az alapértelmezett nyelv: a rendszeré, ha magyar/angol/német, különben angol.
static func alap() -> String:
	var l := OS.get_locale_language().to_lower()
	return l if l in NYELVEK else "en"


static func nyelv() -> String:
	if current == "":
		set_lang(alap())
	return current


static func set_lang(code: String) -> void:
	var c := code.to_lower()
	if not (c in NYELVEK):
		c = alap()
	if c != current:
		current = c
		seq += 1
	_tabla(c)


## A következő nyelv (hu → en → de → hu) — a főmenü "L" billentyűjéhez.
static func kovetkezo() -> String:
	var i := NYELVEK.find(nyelv())
	return NYELVEK[(i + 1) % NYELVEK.size()]


static func _tabla(code: String) -> Dictionary:
	if _tablak.has(code):
		return _tablak[code]
	var d := {}
	var ut := MAPPA % code
	if FileAccess.file_exists(ut):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(ut)) == OK and j.data is Dictionary:
			d = j.data
		else:
			push_error("Hibás nyelvi fájl: " + ut)
	_tablak[code] = d
	return d


## egy nyelv teljes táblája (a tesztnek)
static func tabla(code: String) -> Dictionary:
	return _tabla(code)


static func has(key: String) -> bool:
	return _tabla(nyelv()).has(key)


## Fordítás: `Lang.T("hud.hp", 12, 40)`. Hiányzó kulcsnál maga a kulcs látszik (a teszt ezt keresi).
static func T(key: String, ...args: Array) -> String:
	return Ta(key, args)


## Ugyanaz, csak a paraméterek tömbben érkeznek.
static func Ta(key: String, args: Array = []) -> String:
	var s: Variant = _tabla(nyelv()).get(key)
	if s == null:
		return key
	var txt := str(s)
	if args.is_empty():
		return txt
	var vals: Array = []
	for a in args:
		vals.append(_ertek(a))
	return txt.format(vals)


static func _ertek(a: Variant) -> String:
	if a is Dictionary:
		return txt(a)
	if a is float and is_equal_approx(a, roundf(a)):
		return str(int(roundf(a)))   # a mentésből visszaolvasott egész számok float-ként jönnek
	return str(a)


## Később (kirajzoláskor) fordítandó szöveg: {"k": kulcs, "a": [paraméterek]}.
## A paraméter maga is lehet hivatkozás (pl. egy szörny vagy tárgy neve).
static func ref(key: String, ...args: Array) -> Dictionary:
	return {"k": key, "a": args}


## Hivatkozás vagy kész szöveg → a mostani nyelvű szöveg.
static func txt(v: Variant) -> String:
	if v is Dictionary:
		var d: Dictionary = v
		var a: Variant = d.get("a", [])
		return Ta(str(d.get("k", "")), a if a is Array else [])
	return str(v)


## Érvényes-e egy (pl. mentésből visszaolvasott) hivatkozás.
static func ervenyes_ref(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	if not (d.get("k") is String) or not (d.get("a", []) is Array):
		return false
	for a in (d.get("a", []) as Array):
		if a is Dictionary and not ervenyes_ref(a):
			return false
	return true


# ══════════ JÁTÉKELEMEK NEVE ══════════
## a kaszt neve (a belső azonosító Lovag / Mágus / Íjász)
static func cls(c: String) -> String:
	return T("cls." + str(CLS_KULCS.get(c, "knight")))


static func cls_desc(c: String) -> String:
	return T("cls." + str(CLS_KULCS.get(c, "knight")) + ".d")


## tárgy neve ritkaság-jellel ("✦ Holdfénypenge") — hivatkozásként
static func item_ref(id: String, rarity: String) -> Dictionary:
	return ref("rar.pre." + rarity, ref("item." + id))
