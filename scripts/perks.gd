class_name Perks
extends RefCounted
## Szintlépéskor választható képességek. Minden szintlépéskor három lap közül lehet választani:
## a kasztnak megfelelő és a közös képességekből. A képességek halmozódnak (a "max" a felső határ),
## és a táska képernyőn mind fel vannak sorolva.

const LIST := {
	# ── közös ──
	"eletero": {"cls": "", "max": 5, "ic": "♥", "col": "#d04030"},
	"szivossag": {"cls": "", "max": 4, "ic": "🛡", "col": "#5080e0"},
	"vamp": {"cls": "", "max": 3, "ic": "♥", "col": "#d03030"},
	"regen": {"cls": "", "max": 3, "ic": "✚", "col": "#40c860"},
	"kincs": {"cls": "", "max": 2, "ic": "◉", "col": "#d4a84b"},
	# ── Lovag ──
	"blokk": {"cls": "Lovag", "max": 4, "ic": "⛨", "col": "#80a8e0"},
	"vertezet": {"cls": "Lovag", "max": 3, "ic": "🛡", "col": "#5080e0"},
	"dofes": {"cls": "Lovag", "max": 2, "ic": "⚔", "col": "#e0a040"},
	# ── Íjász ──
	"sasszem": {"cls": "Íjász", "max": 3, "ic": "🏹", "col": "#70d860"},
	"hosszuij": {"cls": "Íjász", "max": 2, "ic": "↔", "col": "#70d860"},
	"gyorslab": {"cls": "Íjász", "max": 1, "ic": "»", "col": "#a0e090"},
	# ── Mágus ──
	"fokusz": {"cls": "Mágus", "max": 4, "ic": "✦", "col": "#8cc4ff"},
	"messzi": {"cls": "Mágus", "max": 2, "ic": "↔", "col": "#6aa8ff"},
	"atuto": {"cls": "Mágus", "max": 2, "ic": "✳", "col": "#a0d0ff"},
}
const ORDER := ["eletero", "szivossag", "vamp", "regen", "kincs",
	"blokk", "vertezet", "dofes", "sasszem", "hosszuij", "gyorslab", "fokusz", "messzi", "atuto"]


## A képesség adatai; "n" (név) és "d" (leírás) a mostani nyelven (perk.<id>, perk.<id>.d).
static func info(id: String) -> Dictionary:
	if not LIST.has(id):
		return {"n": id, "d": "", "cls": "", "max": 1, "ic": "•", "col": "#c8a870"}
	var d: Dictionary = (LIST[id] as Dictionary).duplicate()
	d["n"] = Lang.T("perk." + id)
	d["d"] = Lang.T("perk." + id + ".d")
	return d


## A hős számára még választható képességek (kaszt szerint szűrve, a határt elérteket kihagyva).
static func pool_for(p: Player) -> Array:
	var out: Array = []
	for id in ORDER:
		var d: Dictionary = LIST[id]
		if d["cls"] != "" and d["cls"] != p.cls:
			continue
		if int(p.perks.get(id, 0)) >= int(d["max"]):
			continue
		out.append(id)
	return out


## Három véletlen lap (kevesebb, ha már majdnem minden ki van maxolva).
static func offer(p: Player, n := 3) -> Array:
	var pool := pool_for(p)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


## A választott képesség hozzáadása. A rögtön ható részek (életerő, védelem, varázserő) itt
## épülnek be az alapértékekbe, a többit a hős származtatott értékei (lásd player.gd) olvassák.
static func apply(p: Player, id: String) -> bool:
	if not LIST.has(id):
		return false
	if int(p.perks.get(id, 0)) >= int(LIST[id]["max"]):
		return false
	p.perks[id] = int(p.perks.get(id, 0)) + 1
	match id:
		"eletero":
			p.max_hp += 10
			p.hp = mini(p.max_hp, p.hp + 10)
		"szivossag":
			p.base_def += 2
		"vertezet":
			p.base_def += 3
		"fokusz":
			p.base_mag += 2
	p.perk_seq += 1
	p.add_msg(Lang.ref("msg.perk", LIST[id]["ic"], Lang.ref("perk." + id)), Data.P["parchGold"])
	return true


## "Vas szervezet ×2" alakú felsorolás a táska képernyőre.
static func labels(p: Player) -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		var n := int(p.perks.get(id, 0))
		if n <= 0:
			continue
		out.append("%s %s%s" % [LIST[id]["ic"], Lang.T("perk." + id), (" ×%d" % n) if n > 1 else ""])
	return out
