class_name Perks
extends RefCounted
## Szintlépéskor választható képességek. Minden szintlépéskor három lap közül lehet választani:
## a kasztnak megfelelő és a közös képességekből. A képességek halmozódnak (a "max" a felső határ),
## és a táska képernyőn mind fel vannak sorolva.

const LIST := {
	# ── közös ──
	"eletero": {"n": "Vas szervezet", "d": "+10 maximum életerő, és rögtön gyógyít is ennyit.", "cls": "", "max": 5, "ic": "♥", "col": "#d04030"},
	"szivossag": {"n": "Szívósság", "d": "+2 védelem örökre.", "cls": "", "max": 4, "ic": "🛡", "col": "#5080e0"},
	"vamp": {"n": "Vérszívás", "d": "+5% életlopás minden sebzésed után.", "cls": "", "max": 3, "ic": "♥", "col": "#d03030"},
	"regen": {"n": "Gyors gyógyulás", "d": "Körönként +1 életerő.", "cls": "", "max": 3, "ic": "✚", "col": "#40c860"},
	"kincs": {"n": "Kincsvadász", "d": "+50% arany a legyőzött szörnyekből.", "cls": "", "max": 2, "ic": "◉", "col": "#d4a84b"},
	# ── Lovag ──
	"blokk": {"n": "Pajzsmester", "d": "+5% esély, hogy pajzzsal felfogd az ütés felét.", "cls": "Lovag", "max": 4, "ic": "⛨", "col": "#80a8e0"},
	"vertezet": {"n": "Vértezet", "d": "+3 védelem örökre.", "cls": "Lovag", "max": 3, "ic": "🛡", "col": "#5080e0"},
	"dofes": {"n": "Pajzsdöfés", "d": "25% eséllyel egy körre elkábítod a szörnyet.", "cls": "Lovag", "max": 2, "ic": "⚔", "col": "#e0a040"},
	# ── Íjász ──
	"sasszem": {"n": "Sasszem", "d": "+8% kritikus esély az íjjal.", "cls": "Íjász", "max": 3, "ic": "🏹", "col": "#70d860"},
	"hosszuij": {"n": "Hosszú íj", "d": "+1 lőtáv.", "cls": "Íjász", "max": 2, "ic": "↔", "col": "#70d860"},
	"gyorslab": {"n": "Gyors léptek", "d": "Minden 5. lépésed ingyen van: nem telik vele kör.", "cls": "Íjász", "max": 1, "ic": "»", "col": "#a0e090"},
	# ── Mágus ──
	"fokusz": {"n": "Mágikus fókusz", "d": "+2 varázserő örökre.", "cls": "Mágus", "max": 4, "ic": "✦", "col": "#8cc4ff"},
	"messzi": {"n": "Messzi gömb", "d": "A varázsgömb 1 mezővel tovább repül.", "cls": "Mágus", "max": 2, "ic": "↔", "col": "#6aa8ff"},
	"atuto": {"n": "Átütő gömb", "d": "20% eséllyel a gömb átüt a célponton, és tovább repül.", "cls": "Mágus", "max": 2, "ic": "✳", "col": "#a0d0ff"},
}
const ORDER := ["eletero", "szivossag", "vamp", "regen", "kincs",
	"blokk", "vertezet", "dofes", "sasszem", "hosszuij", "gyorslab", "fokusz", "messzi", "atuto"]


static func info(id: String) -> Dictionary:
	return LIST.get(id, {"n": id, "d": "", "cls": "", "max": 1, "ic": "•", "col": "#c8a870"})


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
	p.add_msg("⬆ %s %s!" % [LIST[id]["ic"], LIST[id]["n"]], Data.P["parchGold"])
	return true


## "Vas szervezet ×2" alakú felsorolás a táska képernyőre.
static func labels(p: Player) -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		var n := int(p.perks.get(id, 0))
		if n <= 0:
			continue
		out.append("%s %s%s" % [LIST[id]["ic"], LIST[id]["n"], (" ×%d" % n) if n > 1 else ""])
	return out
