class_name Relics
extends RefCounted
## Ereklyék: ritka, kalandonként néhány darab (a főellenségek és a mini-bossok talapzatán, két
## lap közül választva). Nem halmozódnak — egymást ERŐSÍTIK: a Gyújtókamra gyújt, a Savmirigy
## mar, a Robbanó epe pedig felrobbantja azt, aki egyszerre ég és mart; a Tesla-tekercs villáma
## Rézbőrrel a martakon duplán sebez. Így minden kaland más felépítést ad.
## A hatások a game.gd-ben vannak (on_hit, kill_reward, mon_attack, check_death, dash).

const LIST := {
	"gyujto": {"ic": "🔥", "col": "#ff8a30"},      # a találataid meggyújtják az ellenséget
	"savmirigy": {"ic": "☣", "col": "#b0e030"},   # a találataid marnak (-2 védelem rétegenként)
	"tesla": {"ic": "⚡", "col": "#8cd0ff"},        # minden negyedik találat villámot láncol
	"robbano": {"ic": "✸", "col": "#ffb040"},     # az égő ÉS mart ellenség halálakor felrobban
	"rezbor": {"ic": "⌁", "col": "#e0a060"},      # a villám a martakon duplán sebez és kábít
	"verpumpa": {"ic": "♥", "col": "#e06070"},    # égő vagy vérző ellenség megölése gyógyít
	"tukor": {"ic": "◈", "col": "#c0d8f0"},       # a kapott ütés negyede visszaverődik
	"oramu": {"ic": "⚙", "col": "#ffd060"},       # a képesség gyorsabban tölt; ölés után újra ugorhatsz
	"gozkopeny": {"ic": "»", "col": "#f0f0e0"},   # félreugrás után a következő ütés duplán sebez
	"vegso": {"ic": "✦", "col": "#ff6050"},       # zónánként egyszer túléled a halálos ütést
}
const ORDER := ["gyujto", "savmirigy", "tesla", "robbano", "rezbor", "verpumpa", "tukor", "oramu", "gozkopeny", "vegso"]
## melyik ereklye melyikkel működik együtt (a választólapon ez látszik: "Együtt erős: ...")
const SYNERGY := {"gyujto": ["robbano", "verpumpa"], "savmirigy": ["robbano", "rezbor"], "tesla": ["rezbor"],
	"robbano": ["gyujto", "savmirigy"], "rezbor": ["tesla", "savmirigy"], "verpumpa": ["gyujto"],
	"oramu": ["gozkopeny"], "gozkopeny": ["oramu"]}
const CORR_MAX := 3
const BURN_TURNS := 3


## Az ereklye adatai; "n" (név) és "d" (leírás) a mostani nyelven (relic.<id>, relic.<id>.d).
static func info(id: String) -> Dictionary:
	if not LIST.has(id):
		return {"n": id, "d": "", "ic": "•", "col": "#c8a870"}
	var d: Dictionary = (LIST[id] as Dictionary).duplicate()
	d["n"] = Lang.T("relic." + id)
	d["d"] = Lang.T("relic." + id + ".d")
	return d


## Választható ereklyék: amije még nincs. Előre kerül, ami a meglévőkkel együttműködik.
static func offer(p: Player, n := 2) -> Array:
	var pool: Array = []
	for id in ORDER:
		if not (id in p.relics):
			pool.append(id)
	pool.shuffle()
	var jo: Array = []
	for id in pool:
		for r in p.relics:
			if id in (SYNERGY.get(r, []) as Array):
				jo.append(id)
				break
	# az egyik lap (ha van ilyen) mindig illik a meglévőkhöz — a másik véletlen
	var out: Array = []
	if not jo.is_empty():
		out.append(jo[0])
	for id in pool:
		if out.size() >= n:
			break
		if not (id in out):
			out.append(id)
	return out


static func apply(p: Player, id: String) -> bool:
	if not LIST.has(id) or id in p.relics:
		return false
	p.relics.append(id)
	p.relic_seq += 1
	p.add_msg(Lang.ref("msg.relic", LIST[id]["ic"], Lang.ref("relic." + id)), LIST[id]["col"])
	return true


## a meglévő ereklyék közül melyekkel működik együtt ez az új
static func synergy_with(p: Player, id: String) -> Array:
	var out: Array = []
	for r in p.relics:
		if id in (SYNERGY.get(r, []) as Array) or r in (SYNERGY.get(id, []) as Array):
			if not (r in out):
				out.append(r)
	return out
